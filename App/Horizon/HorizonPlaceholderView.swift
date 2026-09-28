import DesignKit
import SwiftUI

/// P0 placeholder for the Horizon: seven static day columns around today, the middle one wide.
/// No data, no interaction — it proves the tokens and the layout math end to end.
struct HorizonPlaceholderView: View {
    static let dayCount = 7

    let days: [Date]
    let focused: Int

    init(today: Date = Date(), calendar: Calendar = .current) {
        let start = calendar.startOfDay(for: today)
        let half = Self.dayCount / 2
        days = (-half ... half).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
        focused = half
    }

    var body: some View {
        GeometryReader { geometry in
            let separators = Spacing.hairline * CGFloat(days.count - 1)
            let widths = HorizonLayout.columnWidths(
                totalWidth: geometry.size.width - separators,
                count: days.count,
                focused: focused
            )
            HStack(spacing: Spacing.hairline) {
                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    DayColumnPlaceholder(date: day, isFocused: index == focused)
                        .frame(width: widths[index])
                }
            }
        }
        .background(Palette.separator)
    }
}

private struct DayColumnPlaceholder: View {
    let date: Date
    let isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(date, format: .dateTime.weekday(isFocused ? .wide : .abbreviated))
                .font(Typography.meta)
                .foregroundStyle(Palette.secondaryText)
            Text(date, format: .dateTime.day())
                .font(isFocused ? Typography.displayNumeral : Typography.title.monospacedDigit())
                .foregroundStyle(isFocused ? Palette.accent : Palette.primaryText)
            Spacer(minLength: 0)
        }
        .lineLimit(1)
        .padding(isFocused ? Spacing.l : Spacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(isFocused ? Palette.focusedColumn : Palette.column)
    }
}
