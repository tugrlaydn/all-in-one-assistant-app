import Foundation

/// Geometry of the Horizon: how the window width is shared between day columns (§6, the Horizon motif).
///
/// The focused day takes a fixed share of the width; the other days share the rest and narrow with
/// their distance from focus, so the ribbon reads as an accordion. The default numbers are P0
/// placeholders — the real ones come from the ratified Figma frame and the Motion Lab in P2.
public enum HorizonLayout {
    public static let defaultFocusShare: CGFloat = 0.42
    public static let defaultFalloff: CGFloat = 0.25

    /// Widths of `count` columns that exactly fill `totalWidth`.
    ///
    /// - Parameters:
    ///   - focused: index of the wide column; clamped into range.
    ///   - focusShare: fraction of `totalWidth` the focused column takes (0...1).
    ///   - falloff: how quickly unfocused columns narrow per step of distance; 0 keeps them equal.
    public static func columnWidths(
        totalWidth: CGFloat,
        count: Int,
        focused: Int,
        focusShare: CGFloat = defaultFocusShare,
        falloff: CGFloat = defaultFalloff
    ) -> [CGFloat] {
        guard count > 0 else { return [] }
        let total = max(0, totalWidth)
        guard count > 1 else { return [total] }

        let focus = min(max(focused, 0), count - 1)
        let focusWidth = total * min(max(focusShare, 0), 1)
        let weights = (0 ..< count).map { index -> CGFloat in
            let distance = CGFloat(abs(index - focus))
            return distance == 0 ? 0 : 1 / (1 + max(falloff, 0) * (distance - 1))
        }
        let weightSum = weights.reduce(0, +)
        let rest = total - focusWidth
        return weights.enumerated().map { index, weight in
            index == focus ? focusWidth : rest * weight / weightSum
        }
    }
}
