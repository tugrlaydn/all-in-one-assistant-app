import SwiftUI

/// Type tokens (§6 identity 3): SF Pro, one four-step scale, tabular numerals for dates and minutes.
/// Sizes follow the system text styles so Dynamic Type-style scaling and accessibility settings apply.
public enum Typography {
    public static let display = Font.system(.largeTitle, design: .default).weight(.semibold)
    public static let title = Font.system(.title3, design: .default).weight(.semibold)
    public static let body = Font.system(.body, design: .default)
    public static let meta = Font.system(.caption, design: .default)

    /// Day numbers, dates, minutes: digits line up across columns.
    public static let displayNumeral = display.monospacedDigit()
    public static let metaNumeral = meta.monospacedDigit()
}
