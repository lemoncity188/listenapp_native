import Foundation
struct ABSegment: Codable, Equatable {
    var APos: Double
    var BPos: Double
    var valid: Bool { APos.isFinite && BPos.isFinite && APos >= 0 && BPos > APos }
}
func boundedSeek(_ value: Double, duration: Double) -> Double {
    guard value.isFinite else { return 0 }
    return max(0, duration.isFinite && duration > 0 ? min(value, duration) : value)
}
