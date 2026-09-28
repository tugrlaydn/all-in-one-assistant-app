import Foundation
import Testing
@testable import VaultKit

@Suite("Day and ISOWeek")
struct DayTests {
    @Test func parsesAndPrints() throws {
        let day = try #require(Day("2026-09-30"))
        #expect(day.description == "2026-09-30")
        #expect(Day("2026-02-29") == nil)
        #expect(Day("2028-02-29") != nil)
        #expect(Day("2026-13-01") == nil)
        #expect(Day("2026-9-30") == nil)
        #expect(Day(" 2026-09-30") == nil)
    }

    @Test func arithmeticAcrossMonthsYearsAndLeapDays() throws {
        let day = try #require(Day("2026-12-31"))
        #expect(day.adding(days: 1).description == "2027-01-01")
        #expect(try #require(Day("2028-02-28")).adding(days: 1).description == "2028-02-29")
        #expect(try #require(Day("1970-01-01")).daysSince1970 == 0)
        #expect(Day(daysSince1970: 20_724).description == "2026-09-28")
        var rng = SplitMix64(seed: 3)
        for _ in 0 ..< 500 {
            let days = rng.int(-200_000 ... 2_000_000)
            #expect(Day(daysSince1970: days).daysSince1970 == days)
        }
    }

    @Test func weekdaysAreISO() throws {
        #expect(try #require(Day("2026-09-28")).weekday == 1) // Monday
        #expect(try #require(Day("2026-10-04")).weekday == 7) // Sunday
        #expect(try #require(Day("1970-01-01")).weekday == 4) // Thursday
    }

    @Test(arguments: [
        ("2026-09-28", "2026-W40"), ("2026-10-04", "2026-W40"), ("2026-01-01", "2026-W01"),
        ("2025-12-29", "2026-W01"), ("2027-01-03", "2026-W53"), ("2021-01-03", "2020-W53"),
        ("2024-12-30", "2025-W01"),
    ])
    func isoWeeks(_ day: String, _ week: String) throws {
        #expect(try #require(Day(day)).week.description == week)
    }

    @Test func weekDaysRunMondayToSunday() throws {
        let week = try #require(ISOWeek("2026-W40"))
        #expect(week.days.map(\.description) == [
            "2026-09-28", "2026-09-29", "2026-09-30", "2026-10-01", "2026-10-02", "2026-10-03", "2026-10-04",
        ])
        #expect(week.adding(weeks: 13).description == "2026-W53")
        #expect(week.adding(weeks: 14).description == "2027-W01")
        #expect(ISOWeek("2025-W53") == nil) // 2025 has 52 weeks
    }

    @Test func dayOfADateDependsOnTheTimeZone() throws {
        let instant = Date(timeIntervalSince1970: 1_790_713_800) // 2026-09-29T20:30:00Z
        #expect(Day(instant, in: try #require(TimeZone(identifier: "Europe/Istanbul"))).description == "2026-09-29")
        #expect(Day(instant, in: try #require(TimeZone(identifier: "Asia/Tokyo"))).description == "2026-09-30")
    }
}

@Suite("Timestamp")
struct TimestampTests {
    @Test(arguments: [
        "2026-09-28T09:12:00+03:00", "2026-09-28T09:12:00-05:30", "2026-09-28T00:00:00+00:00",
    ])
    func roundTrips(_ text: String) throws {
        #expect(try #require(Timestamp(text)).description == text)
    }

    @Test func acceptsVariants() throws {
        let reference = try #require(Timestamp("2026-09-28T06:12:00+00:00"))
        for text in ["2026-09-28T09:12:00+03:00", "2026-09-28T06:12:00Z", "2026-09-28T06:12Z",
                     "2026-09-28 09:12:00+0300", "2026-09-28T09:12:00.123+03", "2026-09-28T06:12:00.9Z"]
        {
            #expect(Timestamp(text)?.date == reference.date, "\(text)")
        }
        for text in ["2026-09-28T09:12:00", "2026-09-28", "2026-09-28T25:00:00Z", "2026-09-28T09:12:00+3"] {
            #expect(Timestamp(text) == nil, "\(text)")
        }
    }

    @Test func dayUsesTheWrittenOffset() throws {
        // 23:30 in Istanbul is still the 29th, even though it is the 29th 20:30 UTC.
        #expect(try #require(Timestamp("2026-09-29T23:30:00+03:00")).day.description == "2026-09-29")
        #expect(try #require(Timestamp("2026-09-29T01:30:00+03:00")).day.description == "2026-09-29")
    }

    @Test func nowInAZoneWritesThatZonesOffset() throws {
        let instant = Date(timeIntervalSince1970: 1_790_713_800.75)
        let stamp = Timestamp(instant, in: try #require(TimeZone(identifier: "Europe/Istanbul")))
        #expect(stamp.description == "2026-09-29T23:30:00+03:00")
        #expect(Timestamp(stamp.description) == stamp)
    }

    @Test func timesOfDay() {
        #expect(TimeOfDay("07:30")?.description == "07:30")
        #expect(TimeOfDay("7:30")?.description == "07:30")
        #expect(TimeOfDay("24:00") == nil)
        #expect(TimeOfDay("12:5") == nil)
    }
}

@Suite("Links, tags, estimates")
struct MarkdownTextTests {
    @Test func wikiLinks() {
        let links = WikiLink.all(in: """
        See [[Send invoice]] and [[Client note#Terms|the terms]], not ![[scan.png]].
        `[[in code]]` stays code.
        ```
        [[fenced]]
        ```
        [[ Spaced ]] [[]] [[unclosed
        """)
        #expect(links.map(\.target) == ["Send invoice", "Client note", "Spaced"])
        #expect(links[1].heading == "Terms")
        #expect(links[1].alias == "the terms")
        #expect(links[1].description == "[[Client note#Terms|the terms]]")
        #expect(WikiLink(parsing: "[[Q4 invoicing]]")?.key == "q4 invoicing")
        #expect(WikiLink(parsing: "Q4 invoicing") == nil)
        #expect(WikiLink(parsing: "[[a]] [[b]]") == nil)
    }

    @Test func inlineTags() {
        let tags = MarkdownText.inlineTags(in: """
        # Heading is not a tag
        Tags: #work, #rf/antenna (#nested) and #2026 is a number; #v2 is fine.
        email@example#com is not a tag. `#code` neither.
        ```
        #fenced
        ```
        """)
        #expect(tags == ["work", "rf/antenna", "nested", "v2"])
    }

    @Test(arguments: [("45m", 45), ("2h", 120), ("1h30m", 90), ("1h 30m", 90), ("90", 90), ("2H", 120)])
    func estimates(_ text: String, _ minutes: Int) {
        #expect(Estimate(text)?.minutes == minutes)
    }

    @Test func estimateFormatting() {
        #expect(Estimate(minutes: 45)?.description == "45m")
        #expect(Estimate(minutes: 120)?.description == "2h")
        #expect(Estimate(minutes: 90)?.description == "1h30m")
        #expect(Estimate("0m") == nil)
        #expect(Estimate("45x") == nil)
        #expect(Estimate("h") == nil)
    }
}
