import Foundation

/// An instant with the UTC offset it was written in: `2026-09-28T09:12:00+03:00` (FORMAT §4.1).
///
/// The offset is kept so a note created at 23:30 in Istanbul stays on that day in the Horizon,
/// even when the vault is opened later in another time zone.
public struct Timestamp: Hashable, Comparable, Sendable {
    public let date: Date
    /// Seconds east of UTC.
    public let utcOffset: Int

    public init(date: Date, utcOffset: Int) {
        // Whole seconds only: the format has no fractions, and a written value must read back equal.
        self.date = Date(timeIntervalSince1970: date.timeIntervalSince1970.rounded(.down))
        self.utcOffset = utcOffset
    }

    /// `date` in `timeZone`, e.g. `Timestamp.now()`.
    public init(_ date: Date = Date(), in timeZone: TimeZone = .current) {
        self.init(date: date, utcOffset: timeZone.secondsFromGMT(for: date))
    }

    public static func now(in timeZone: TimeZone = .current) -> Timestamp {
        Timestamp(Date(), in: timeZone)
    }

    /// `YYYY-MM-DDTHH:MM[:SS[.fff]](Z|±HH:MM|±HHMM|±HH)`. A space instead of `T` is accepted.
    public init?(_ string: some StringProtocol) {
        let bytes = Array(string.utf8)
        guard bytes.count >= 16, let day = Day(String(decoding: bytes[0 ..< 10], as: UTF8.self)),
              bytes[10] == UInt8(ascii: "T") || bytes[10] == UInt8(ascii: " "),
              let hour = Day.number(bytes[11 ..< 13]), bytes[13] == UInt8(ascii: ":"),
              let minute = Day.number(bytes[14 ..< 16]), hour < 24, minute < 60
        else { return nil }
        var index = 16
        var second = 0
        if index < bytes.count, bytes[index] == UInt8(ascii: ":") {
            guard index + 3 <= bytes.count, let value = Day.number(bytes[index + 1 ..< index + 3]), value < 61
            else { return nil }
            second = value
            index += 3
            if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
                index += 1
                while index < bytes.count, (0x30 ... 0x39).contains(bytes[index]) { index += 1 }
            }
        }
        guard index < bytes.count else { return nil } // an offset is required
        var offset = 0
        switch bytes[index] {
        case UInt8(ascii: "Z"):
            guard index + 1 == bytes.count else { return nil }
        case UInt8(ascii: "+"), UInt8(ascii: "-"):
            let sign = bytes[index] == UInt8(ascii: "-") ? -1 : 1
            let rest = Array(bytes[(index + 1)...]).filter { $0 != UInt8(ascii: ":") }
            guard rest.count == 2 || rest.count == 4, let hours = Day.number(rest[0 ..< 2][...]),
                  let minutes = rest.count == 4 ? Day.number(rest[2 ..< 4][...]) : 0, hours < 24, minutes < 60
            else { return nil }
            offset = sign * (hours * 3600 + minutes * 60)
        default:
            return nil
        }
        let local = day.daysSince1970 * 86400 + hour * 3600 + minute * 60 + second
        self.init(date: Date(timeIntervalSince1970: TimeInterval(local - offset)), utcOffset: offset)
    }

    /// The calendar day in the timestamp's own offset.
    public var day: Day {
        Day(daysSince1970: Int((Double(localSeconds) / 86400).rounded(.down)))
    }

    private var localSeconds: Int {
        Int(date.timeIntervalSince1970) + utcOffset
    }

    public static func < (lhs: Timestamp, rhs: Timestamp) -> Bool {
        lhs.date < rhs.date
    }
}

extension Timestamp: CustomStringConvertible {
    public var description: String {
        let seconds = localSeconds - day.daysSince1970 * 86400
        let sign = utcOffset < 0 ? "-" : "+"
        let offset = abs(utcOffset)
        return day.description
            + String(format: "T%02d:%02d:%02d", seconds / 3600, seconds % 3600 / 60, seconds % 60)
            + sign + String(format: "%02d:%02d", offset / 3600, offset % 3600 / 60)
    }
}

/// A time of day, `"12:30"` — used for nudge times (FORMAT §4.4).
public struct TimeOfDay: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0 ..< 24).contains(hour), (0 ..< 60).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    public init?(_ string: some StringProtocol) {
        let parts = string.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2, (1 ... 2).contains(parts[0].count), parts[1].count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1])
        else { return nil }
        self.init(hour: hour, minute: minute)
    }

    public var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}
