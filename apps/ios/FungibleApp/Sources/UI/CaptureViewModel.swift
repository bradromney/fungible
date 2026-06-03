import Foundation
import simd
import FungibleDomain
import FungibleCapture
import FungibleGuidance
import FungibleStorage

/// Drives the M1 capture loop: feeds depth frames into the bounded voxel
/// accumulator, runs live guidance, and on finish auto-saves the scan via the
/// local-first store (ADR-0005 — no manual save step). Multi-scan incremental
/// registration is M3; this view model captures one scan into a new set.
@MainActor
final class CaptureViewModel: ObservableObject {
    @Published private(set) var pointCount = 0
    @Published private(set) var prompts: [Prompt] = []
    @Published private(set) var isCapturing = false
    @Published private(set) var statusMessage: String?

    let session = ARDepthCaptureSession()

    private let store: any ScanStore
    private let guidance = RuleBasedGuidanceEngine()
    private let filter = ConfidenceFilter(minConfidence: .medium, maxRangeMeters: 5.0)
    // ~5M-voxel cap at 2 cm: bounded memory for a large single scan.
    private var accumulator = VoxelAccumulator(voxelSize: 0.02, capacity: 5_000_000)

    private var lastTranslation: SIMD3<Float>?
    private var lastTimestamp: TimeInterval?

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
        session.start()
        isCapturing = true
    }

    func stop() {
        session.pause()
        isCapturing = false
    }

    private func handle(_ frame: DepthFrameData) {
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

    /// Auto-save the current scan as a new set. Returns when persisted.
    func finishScan(named name: String = "Untitled Site") async {
        stop()
        let points = accumulator.points()
        guard !points.isEmpty else {
            statusMessage = "Nothing captured yet."
            return
        }
        do {
            let scanID = ScanID()
            let ref = try await store.writeBlob(points: points, for: scanID)
            let quality = QualityReport(highConfidenceFraction: highConfidenceFraction(points))
            let scan = Scan(id: scanID, deviceModel: deviceModel(), pointCloud: ref,
                            pose: .identity, quality: quality, status: .registered)
            var set = ScanSet(name: name)
            set.append(scan)
            try await store.save(set)
            statusMessage = "Saved \(points.count) points."
        } catch {
            statusMessage = "Save failed: \(error)"
        }
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
