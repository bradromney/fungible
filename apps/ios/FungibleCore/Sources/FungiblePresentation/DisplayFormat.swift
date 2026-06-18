import Foundation
import FungibleDomain

// Pure display formatting for the UI layer. Lives in the core (not the SwiftUI
// app) so it builds and is unit-tested on Linux CI — the screens stay thin
// bindings over verified logic. No Foundation NumberFormatter/locale dependence
// on the hot paths: grouping and rounding are done by hand so output is
// deterministic across platforms (Linux CI vs. device).
//
// US construction & landscaping quote imperial (feet/inches, sq ft / acres,
// cubic yards); metric is shown as a quiet echo (ADR-0007). The capture/measure
// core works in SI — these convert only at the display edge.
public enum DisplayFormat {

    // MARK: - Numeric primitives (deterministic, locale-free)

    /// Group an integer with thousands separators: 1234567 -> "1,234,567".
    public static func grouped(_ n: Int) -> String {
        let negative = n < 0
        var digits = String(abs(n))
        var out = ""
        while digits.count > 3 {
            let tail = String(digits.suffix(3))
            out = "," + tail + out
            digits = String(digits.dropLast(3))
        }
        out = digits + out
        return negative ? "-" + out : out
    }

    /// One-decimal value with a trailing ".0" trimmed: 1.20 -> "1.2", 5.0 -> "5".
    public static func trimOne(_ x: Double) -> String {
        let s = String(format: "%.1f", x)
        return s.hasSuffix(".0") ? String(s.dropLast(2)) : s
    }

    // MARK: - Counts

    /// Abbreviated point count: 923 -> "923", 12_300 -> "12.3K", 1_200_000 -> "1.2M".
    public static func pointCount(_ n: Int) -> String {
        switch n {
        case ..<1_000:
            return grouped(n)
        case ..<1_000_000:
            return trimOne(Double(n) / 1_000) + "K"
        default:
            return trimOne(Double(n) / 1_000_000) + "M"
        }
    }

    /// "pts"-suffixed point count for capsules: "1.2M pts".
    public static func pointCountLabel(_ n: Int) -> String { pointCount(n) + " pts" }

    /// Pass count, never a cap (ADR-0005): "1 pass", "12 passes".
    public static func passCount(_ n: Int) -> String {
        "\(n) pass" + (n == 1 ? "" : "es")
    }

    // MARK: - Linear distance (meters in)

    /// Feet-and-inches, the framing/layout idiom: 3.76 m -> "12' 4\"".
    public static func feetInches(_ meters: Double) -> String {
        let totalInches = (meters * Units.feetPerMeter * 12).rounded()
        var feet = Int(totalInches) / 12
        var inches = Int(totalInches) % 12
        if inches == 12 { feet += 1; inches = 0 }
        return "\(feet)' \(inches)\""
    }

    /// Decimal feet, the survey idiom: 3.76 m -> "12.3 ft".
    public static func feetDecimal(_ meters: Double) -> String {
        trimOne(meters * Units.feetPerMeter) + " ft"
    }

    /// Quiet metric echo for a linear value: 3.76 m -> "3.76 m".
    public static func metersEcho(_ meters: Double) -> String {
        String(format: "%.2f m", meters)
    }

    // MARK: - Area (square meters in)

    /// Imperial area, promoting to acres past ~½ acre: small -> "1,240 sq ft",
    /// large -> "2.4 acres".
    public static func areaImperial(_ sqMeters: Double) -> String {
        let sqFt = Units.squareFeet(sqMeters)
        if Units.acres(sqMeters) >= 0.5 {
            return trimOne(Units.acres(sqMeters)) + " acres"
        }
        return grouped(Int(sqFt.rounded())) + " sq ft"
    }

    public static func areaMetricEcho(_ sqMeters: Double) -> String {
        grouped(Int(sqMeters.rounded())) + " m²"
    }

    // MARK: - Volume (cubic meters in)

    /// Earthwork volume in cubic yards: 7.0 m³ -> "9.2 cu yd".
    public static func volumeCubicYards(_ cubicMeters: Double) -> String {
        trimOne(Units.cubicYards(cubicMeters)) + " cu yd"
    }

    public static func volumeMetricEcho(_ cubicMeters: Double) -> String {
        trimOne(cubicMeters) + " m³"
    }

    /// Plain-language gloss for a volume: "≈ 9 truck loads" (default 12 cu yd
    /// per standard dump truck). Returns nil below half a load.
    public static func truckLoads(_ cubicMeters: Double, perLoad cubicYards: Double = 12) -> String? {
        let loads = Units.cubicYards(cubicMeters) / cubicYards
        guard loads >= 0.5 else { return nil }
        let rounded = Int(loads.rounded())
        return "≈ \(rounded) truck load" + (rounded == 1 ? "" : "s")
    }

    // MARK: - Quality

    /// Coverage as a whole percent: 0.84 -> "84% coverage".
    public static func coverage(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded()))% coverage"
    }

    /// Drift in centimeters, or nil when not yet registered: 0.012 -> "1.2 cm drift".
    public static func drift(_ meters: Double?) -> String? {
        guard let meters else { return nil }
        return trimOne(meters * 100) + " cm drift"
    }

    // MARK: - Byte sizes

    /// Humanized file size from a byte count: 980 -> "980 B", 248_000_000 ->
    /// "237 MB". Binary units (KB = 1024). Used for export filename + size.
    public static func fileSize(_ bytes: Int) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(max(0, bytes))
        var unit = 0
        while value >= 1024 && unit < units.count - 1 {
            value /= 1024
            unit += 1
        }
        // Whole numbers for bytes; one decimal (trimmed) for KB and up.
        if unit == 0 { return "\(Int(value)) B" }
        return trimOne(value) + " " + units[unit]
    }

    // MARK: - Timestamps

    /// Precise capture stamp — date + time, not relative ("2h ago" hides
    /// ordering once many passes stack up). Deterministic via injected
    /// locale/timeZone; defaults to the user's. e.g. "Jun 18, 2026 · 2:14 PM".
    public static func preciseTimestamp(
        _ date: Date,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let f = DateFormatter()
        f.locale = locale
        f.timeZone = timeZone
        f.dateFormat = "MMM d, yyyy '·' h:mm a"
        return f.string(from: date)
    }
}
