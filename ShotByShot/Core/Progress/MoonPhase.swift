import Foundation

/// The real phase of the moon, computed from the date alone: no network, no data.
nonisolated struct MoonPhase: Equatable, Sendable {
    /// Position in the synodic month: 0 is a new moon, 0.5 is a full moon.
    let fraction: Double

    static let synodicMonth: TimeInterval = 29.530588853 * 86_400
    /// New moon of January 6, 2000, 18:14 UTC.
    static let referenceNewMoon = Date(timeIntervalSince1970: 947_182_440)

    init(date: Date) {
        let elapsed = date.timeIntervalSince(Self.referenceNewMoon)
        let position = elapsed.truncatingRemainder(dividingBy: Self.synodicMonth) / Self.synodicMonth
        fraction = position < 0 ? position + 1 : position
    }

    /// Lit share of the disc, from 0 to 1.
    var illumination: Double {
        (1 - cos(2 * .pi * fraction)) / 2
    }

    /// While waxing, the lit part is on the right (as seen from the northern hemisphere).
    var isWaxing: Bool {
        fraction < 0.5
    }
}
