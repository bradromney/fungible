import Foundation

// Unit handling. The capture/measurement core works in SI (meters, m², m³); this
// converts for display/reporting. US construction & landscaping quote in feet,
// square feet / acres, and cubic yards — so imperial is a first-class output,
// not an afterthought (serves the AEC/site markets per ADR-0007).
public enum UnitSystem: String, Codable, Sendable, CaseIterable {
    case metric
    case imperial
}

public enum Units {
    public static let feetPerMeter = 3.280_839_895_013_123
    public static let sqFeetPerSqMeter = 10.763_910_416_709_722
    public static let cubicYardsPerCubicMeter = 1.307_950_619_314_392
    public static let acresPerSqMeter = 0.000_247_105_381_467

    public static func feet(_ meters: Double) -> Double { meters * feetPerMeter }
    public static func squareFeet(_ sqMeters: Double) -> Double { sqMeters * sqFeetPerSqMeter }
    public static func cubicYards(_ cubicMeters: Double) -> Double { cubicMeters * cubicYardsPerCubicMeter }
    public static func acres(_ sqMeters: Double) -> Double { sqMeters * acresPerSqMeter }
}
