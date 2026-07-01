import Foundation
import simd
import FungibleDomain
import FungibleCapture
import FungibleGuidance
import FungibleRegistration
import FungibleStorage

/// Drives the no-ceiling capture loop (ADR-0005): feeds depth frames into the
/// bounded voxel accumulator, runs live guidance, and grows ONE project across
/// passes. The AR session stays alive between passes, so every pass shares the
/// first pass's world frame — that shared frame is the pose prior ICP then
/// polishes (session-alive strategy). Each finished pass is appended to the
/// project, registered against the previous pass, and auto-saved.
///
/// Cross-session merging (return visits) needs relocalization (ARWorldMap) or a
/// global coarse aligner — the M3 follow-up; this covers unlimited passes
/// within one visit.
@MainActor
final class CaptureViewModel: ObservableObject {
    @Published private(set) var pointCount = 0
    @Published private(set) var prompts: [Prompt] = []
    @Published private(set) var isCapturing = false
    @Published private(set) var statusMessage: String?
    /// The project growing across this capture session's passes.
    @Published private(set) var project: ScanSet?

    let session = ARDepthCaptureSession()

    private let store: any ScanStore
    private let guidance = RuleBasedGuidanceEngine()
    private let filter = ConfidenceFilter(minConfidence: .medium, maxRangeMeters: 5.0)
    // ~5M-voxel cap at 2 cm: bounded memory for a large single pass.
    private var accumulator = VoxelAccumulator(voxelSize: 0.02, capacity: 5_000_000)

    private var lastTranslation: SIMD3<Float>?
    private var lastTimestamp: TimeInterval?
    /// Downsampled copy of the previous pass, kept to register the next one
    /// without re-reading blobs.
    private var previousPass: (id: ScanID, samples: PointSample)?
    private var hasStartedSession = false

    /// Below this inlier fraction, ICP's answer is less trustworthy than the
    /// shared-session ARKit prior — keep the prior instead of a bad "fix".
    private static let minAcceptedFitness = 0.25

    init(store: any ScanStore) {
        self.store = store
    }

    func start() {
        accumulator.removeAll()
        pointCount = 0
        statusMessage = nil
        session.onFrame = { [weak self] frame in
            // ARSession delivers delegate callbacks on the main thread; hop onto
            // the main actor (iOS 16-compatible, no assumeIsolated).
            Task { @MainActor [weak self] in self?.handle(frame) }
        }
        // First pass establishes the world frame; later passes resume it.
        session.start(resetting: !hasStartedSession)
        hasStartedSession = true
        isCapturing = true
    }

    func stop() {
        session.pause()
        isCapturing = false
    }

    private func handle(_ frame: DepthFrameData) {
        guard isCapturing else { return }   // ignore frames while saving/handoff
        DepthUnprojector.accumulate(frame: frame, filter: filter, into: &accumulator)
        pointCount = accumulator.count

        let speed = estimateSpeed(frame)
        let signals = CaptureSignalsBuilder.build(frame: frame, deviceSpeed: speed)
        prompts = guidance.evaluate(signals: signals, coverage: 0, roi: nil)
    }

    private func estimateSpeed(_ frame: DepthFrameData) -> Double {
        let t = frame.rawCameraTransform.columns.3
        let translation = SIMD3<Float>(t.x, t.y, t.z)
        defer { lastTranslation = translation; lastTimestamp = frame.timestamp }
        guard let prev = lastTranslation, let prevT = lastTimestamp else { return 0 }
        let dt = frame.timestamp - prevT
        guard dt > 0 else { return 0 }
        return Double(simd_distance(translation, prev)) / dt
    }

    /// Finalize the current pass into the growing project: write the blob,
    /// append the scan, register it against the previous pass, auto-save.
    /// Returns false if there was nothing to save. The AR session stays alive
    /// so the next pass lands in the same world frame.
    @discardableResult
    func finishPass() async -> Bool {
        isCapturing = false
        let points = accumulator.points()
        guard !points.isEmpty else {
            statusMessage = "Nothing captured yet."
            isCapturing = true   // keep the pass going; nothing was saved
            return false
        }
        do {
            let scanID = ScanID()
            let ref = try await store.writeBlob(points: points, for: scanID)
            let quality = QualityReport(highConfidenceFraction: highConfidenceFraction(points))
            var set = project ?? Self.newProject(for: points)
            set.append(Scan(id: scanID, deviceModel: deviceModel(), pointCloud: ref,
                            pose: .identity, quality: quality,
                            status: previousPass == nil ? .registered : .pendingRegister))
            project = set
            try await store.save(set)

            let samples = Self.downsample(points, to: 2_000)
            if let previous = previousPass {
                set = await Self.register(scanID, samples: samples, against: previous, in: set)
                project = set
                try await store.save(set)
            }
            previousPass = (scanID, samples)
            statusMessage = "Saved pass \(set.scanCount) · \(points.count) points."
            return true
        } catch {
            statusMessage = "Save failed: \(error)"
            return false
        }
    }

    /// Apply the name chosen at handoff (first pass names the project).
    func renameProject(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var set = project, !trimmed.isEmpty else { return }
        set.name = trimmed
        project = set
        let snapshot = set
        Task { try? await store.save(snapshot) }
    }

    // MARK: - Registration (session-alive prior + ICP polish)

    /// Register the new pass against the previous one off the main actor. Both
    /// passes' points are already in the shared session frame, so the prior is
    /// identity and ICP corrects residual drift. If ICP fails or its fit is
    /// worse than trusting the prior, keep the prior — a pass is never lost or
    /// made worse by registration.
    private static func register(
        _ scanID: ScanID,
        samples: PointSample,
        against previous: (id: ScanID, samples: PointSample),
        in set: ScanSet
    ) async -> ScanSet {
        let working = set
        let minFitness = minAcceptedFitness
        let registered: ScanSet? = await Task.detached(priority: .userInitiated) {
            var s = working
            let registrar = IncrementalRegistrar(
                coarse: PassthroughCoarseAligner(),
                fine: ICPFineAligner(maxCorrespondenceDistance: 0.5),
                optimizer: ChainPoseGraphOptimizer()
            )
            guard let result = try? await registrar.register(
                newScan: scanID, samples: samples, against: previous, in: &s
            ), let r = result, r.fitness >= minFitness else { return nil }
            if let i = s.scans.firstIndex(where: { $0.id == scanID }) {
                s.scans[i].quality.driftEstimateMeters = r.inlierRMSE
            }
            return s
        }.value

        var out = registered ?? working
        if let i = out.scans.firstIndex(where: { $0.id == scanID }) {
            out.scans[i].status = .registered
        }
        return out
    }

    /// First pass creates the project, auto-typed from its geometry (ADR-0007).
    private static func newProject(for points: [CapturedPoint]) -> ScanSet {
        let bounds = BoundingBox.containing(points.map(\.position))
        let type = bounds.map { ProjectType.detect(bounds: $0) } ?? .site
        return ScanSet(name: "Untitled Site", type: type)
    }

    /// Uniform stride-sample down to ~`target` points for the aligners; the
    /// dense bytes stay on disk (PointSample contract).
    private static func downsample(_ points: [CapturedPoint], to target: Int) -> PointSample {
        guard points.count > target, target > 0 else {
            return PointSample(points: points.map(\.position))
        }
        let step = points.count / target
        var out: [Vector3] = []
        out.reserveCapacity(target + 1)
        var i = 0
        while i < points.count {
            out.append(points[i].position)
            i += step
        }
        return PointSample(points: out)
    }

    private func highConfidenceFraction(_ points: [CapturedPoint]) -> Double {
        guard !points.isEmpty else { return 0 }
        let high = points.reduce(0) { $0 + ($1.confidence == .high ? 1 : 0) }
        return Double(high) / Double(points.count)
    }

    private func deviceModel() -> String {
        var info = utsname(); uname(&info)
        let mirror = Mirror(reflecting: info.machine)
        return mirror.children.reduce(into: "") { acc, e in
            if let v = e.value as? Int8, v != 0 { acc.append(Character(UnicodeScalar(UInt8(v)))) }
        }
    }
}
