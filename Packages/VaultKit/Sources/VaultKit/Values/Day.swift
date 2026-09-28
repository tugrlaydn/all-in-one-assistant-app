import Foundation

/// A calendar day, `YYYY-MM-DD` (FORMAT §4.1). No time and no time zone: a task scheduled for
/// 2026-09-30 stays on that day wherever the Mac is. Arithmetic is proleptic Gregorian, done on
/// "days since 1970-01-01" so it never depends on a `Calendar` or `TimeZone`.
public struct Day: Hashable, Comparable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int

    public init?(year: Int, month: Int, day: Int) {
        guard (1 ... 9999).contains(year), (1 ... 12).contains(month),
              (1 ... Self.daysInMonth(year: year, month: month)).contains(day)
        else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// `2026-09-30`. Exactly ten characters; nothing before or after.
    public init?(_ string: some StringProtocol) {
        let bytes = Array(string.utf8)
        guard bytes.count == 10, bytes[4] == UInt8(ascii: "-"), bytes[7] == UInt8(ascii: "-"),
              let year = Self.number(bytes[0 ..< 4]), let month = Self.number(bytes[5 ..< 7]),
              let day = Self.number(bytes[8 ..< 10])
        else { return nil }
        self.init(year: year, month: month, day: day)
    }

    /// The day `date` falls on in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone = .current) {
        let local = date.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: date))
        self.init(daysSince1970: Int((local / 86400).rounded(.down)))
    }

    /// 0001-01-01 and 9999-12-31: the range every `Day` stays inside.
    static let minDays = -719_162
    static let maxDays = 2_932_896

    /// Clamped to years 1–9999, so no arithmetic on typed input can overflow or leave the format.
    public init(daysSince1970 days: Int) {
        let days = min(max(days, Self.minDays), Self.maxDays)
        // Howard Hinnant's civil_from_days.
        let z = days + 719_468
        let era = (z >= 0 ? z : z - 146_096) / 146_097
        let doe = z - era * 146_097
        let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
        let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
        let mp = (5 * doy + 2) / 153
        let d = doy - (153 * mp + 2) / 5 + 1
        let m = mp < 10 ? mp + 3 : mp - 9
        year = yoe + era * 400 + (m <= 2 ? 1 : 0)
        month = m
        day = d
    }

    public var daysSince1970: Int {
        // Howard Hinnant's days_from_civil.
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let mp = month > 2 ? month - 3 : month + 9
        let doy = (153 * mp + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        return era * 146_097 + doe - 719_468
    }

    public func adding(days: Int) -> Day {
        let (sum, overflow) = daysSince1970.addingReportingOverflow(days)
        return Day(daysSince1970: overflow ? (days < 0 ? Self.minDays : Self.maxDays) : sum)
    }

    public func days(until other: Day) -> Int {
        other.daysSince1970 - daysSince1970
    }

    /// ISO weekday: 1 = Monday … 7 = Sunday (D7: weeks start on Monday).
    public var weekday: Int {
        let value = (daysSince1970 + 3) % 7 // 1970-01-01 was a Thursday
        return (value < 0 ? value + 7 : value) + 1
    }

    public var week: ISOWeek {
        ISOWeek(containing: self)
    }

    public static func < (lhs: Day, rhs: Day) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    static func isLeap(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: isLeap(year) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }

    static func number(_ bytes: ArraySlice<UInt8>) -> Int? {
        var value = 0
        for byte in bytes {
            guard (0x30 ... 0x39).contains(byte) else { return nil }
            value = value * 10 + Int(byte - 0x30)
        }
        return value
    }
}

extension Day: CustomStringConvertible, LosslessStringConvertible {
    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

extension Day: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let day = Day(string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a day: \(string)")
        }
        self = day
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// An ISO 8601 week, `2026-W40`: Monday to Sunday, numbered by the year its Thursday falls in.
public struct ISOWeek: Hashable, Comparable, Sendable {
    public let year: Int
    public let week: Int

    public init?(year: Int, week: Int) {
        guard (1 ... 9999).contains(year), (1 ... Self.weeks(in: year)).contains(week) else { return nil }
        self.year = year
        self.week = week
    }

    public init?(_ string: some StringProtocol) {
        let bytes = Array(string.utf8)
        guard bytes.count == 8, bytes[4] == UInt8(ascii: "-"), bytes[5] == UInt8(ascii: "W"),
              let year = Day.number(bytes[0 ..< 4]), let week = Day.number(bytes[6 ..< 8])
        else { return nil }
        self.init(year: year, week: week)
    }

    public init(containing day: Day) {
        let thursday = day.adding(days: 4 - day.weekday)
        let january1 = Day(year: thursday.year, month: 1, day: 1)!
        year = thursday.year
        week = january1.days(until: thursday) / 7 + 1
    }

    public var monday: Day {
        let january4 = Day(year: year, month: 1, day: 4)!
        let firstMonday = january4.adding(days: 1 - january4.weekday)
        return firstMonday.adding(days: (week - 1) * 7)
    }

    /// Monday through Sunday.
    public var days: [Day] {
        (0 ..< 7).map { monday.adding(days: $0) }
    }

    public func adding(weeks: Int) -> ISOWeek {
        let (days, overflow) = weeks.multipliedReportingOverflow(by: 7)
        return ISOWeek(containing: monday.adding(days: overflow ? (weeks < 0 ? Int.min : Int.max) : days))
    }

    /// 52 or 53.
    static func weeks(in year: Int) -> Int {
        ISOWeek(containing: Day(year: year, month: 12, day: 28)!).week
    }

    public static func < (lhs: ISOWeek, rhs: ISOWeek) -> Bool {
        (lhs.year, lhs.week) < (rhs.year, rhs.week)
    }
}

extension ISOWeek: CustomStringConvertible, LosslessStringConvertible {
    public var description: String {
        String(format: "%04d-W%02d", year, week)
    }
}
