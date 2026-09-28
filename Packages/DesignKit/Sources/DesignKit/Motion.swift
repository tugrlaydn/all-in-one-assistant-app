import SwiftUI

/// Motion tokens (§6 identity 4): two springs and nothing else animates. Reduce Motion → crossfade.
///
/// Responses are the plan's targets (quick ≈ 0.25 s, settle ≈ 0.45 s). Damping values are P0
/// placeholders; the ratified numbers come from the Motion Lab (A14) and live only here.
public enum Motion {
    public enum Kind: Sendable {
        /// Chip appearance, small state changes.
        case quick
        /// Column focus, panel show/hide.
        case settle
    }

    public static let quickResponse: Double = 0.25
    public static let quickDamping: Double = 0.9
    public static let settleResponse: Double = 0.45
    public static let settleDamping: Double = 0.85
    public static let crossfadeDuration: Double = 0.2

    /// The animation for `kind`, honouring Reduce Motion.
    public static func animation(_ kind: Kind, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .easeInOut(duration: crossfadeDuration)
        }
        switch kind {
        case .quick:
            return .spring(response: quickResponse, dampingFraction: quickDamping)
        case .settle:
            return .spring(response: settleResponse, dampingFraction: settleDamping)
        }
    }
}
