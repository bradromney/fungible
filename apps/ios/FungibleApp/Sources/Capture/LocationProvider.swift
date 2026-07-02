import Foundation
import CoreLocation
import FungibleDomain

/// Thin CoreLocation wrapper that yields a single best-available GPS fix to tag
/// a scan pass (ADR-0011). Location is opt-in and best-effort: if the user
/// declines or no fix arrives in time, capture proceeds ungeoreferenced — a
/// scan is never blocked on GPS. Uses `.gravityAndHeading` upstream in ARKit so
/// the world frame is north-aligned; here we just grab lat/lon/alt + accuracy.
@MainActor
final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pending: [CheckedContinuation<GeoFix?, Never>] = []
    private var timeoutTask: Task<Void, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    }

    /// Ask for permission early (e.g. when the capture flow opens) so the first
    /// pass can be tagged without a stall.
    func requestAuthorization() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// The current best fix, or nil if unavailable within `timeout`. Never throws
    /// and never blocks capture — the caller tags the scan if a fix comes back.
    func currentFix(timeout: TimeInterval = 2.0) async -> GeoFix? {
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else { return nil }

        // A recent cached fix is good enough for ±3–5 m tagging.
        if let loc = manager.location, loc.horizontalAccuracy >= 0,
           Date().timeIntervalSince(loc.timestamp) < 15 {
            return Self.fix(from: loc, heading: manager.heading?.trueHeading)
        }

        return await withCheckedContinuation { (cont: CheckedContinuation<GeoFix?, Never>) in
            pending.append(cont)
            manager.requestLocation()
            timeoutTask?.cancel()
            timeoutTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                await self?.resolve(nil)
            }
        }
    }

    private func resolve(_ fix: GeoFix?) {
        timeoutTask?.cancel(); timeoutTask = nil
        let waiters = pending; pending.removeAll()
        for w in waiters { w.resume(returning: fix) }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        let heading = manager.heading?.trueHeading
        Task { @MainActor in self.resolve(Self.fix(from: loc, heading: heading)) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.resolve(nil) }
    }

    private static func fix(from loc: CLLocation, heading: Double?) -> GeoFix {
        GeoFix(
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            altitude: loc.altitude,
            horizontalAccuracy: loc.horizontalAccuracy,
            verticalAccuracy: loc.verticalAccuracy,
            heading: (heading ?? 0) >= 0 ? heading : nil,
            timestamp: loc.timestamp
        )
    }
}
