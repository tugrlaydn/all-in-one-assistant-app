import Foundation
import Testing
@testable import VaultKit

/// One row of the grammar table. Unset fields must come out empty.
struct QuickInputCase: CustomTestStringConvertible, Sendable {
    let input: String
    var kind: QuickInput.Kind = .task
    var title = ""
    var scheduled: String?
    var due: String?
    var tags: [String] = []
    var priority: Int?
    var estimate: Int?
    var parent: String?
    var links: [String] = []
    var minutes: Int?
    var note = ""
    var command: String?

    var testDescription: String { "\"\(input)\"" }
}

@Suite("QuickInputParser — grammar §5")
struct QuickInputParserTests {
    /// Wednesday.
    static let today = Day("2026-09-30")!

    static let cases: [QuickInputCase] = [
        // The grammar's own examples
        .init(input: "t Send invoice @fri !1 #work ~45m", title: "Send invoice", scheduled: "2026-10-02", tags: ["work"], priority: 1, estimate: 45),
        .init(input: "n Antenna idea: try a helical element", kind: .note, title: "Antenna idea: try a helical element"),
        .init(input: "h swim 45 evening", kind: .habitLog, title: "swim", minutes: 45, note: "evening"),
        .init(input: "/today", kind: .command, command: "today"),
        .init(input: "/week", kind: .command, command: "week"),
        .init(input: "/open Send invoice", kind: .command, title: "Send invoice", command: "open"),
        .init(input: "/plan physical swim", kind: .command, title: "physical swim", command: "plan"),
        // Prefixes
        .init(input: "Send invoice", title: "Send invoice"),
        .init(input: "t", title: ""),
        .init(input: "", title: ""),
        .init(input: "n", kind: .note),
        .init(input: "tea time", title: "tea time"),
        .init(input: "T cells", title: "T cells"),
        .init(input: "  t   spaced   out  ", title: "spaced out"),
        .init(input: "t a\nb", title: "a b"),
        // Dates
        .init(input: "t Pay rent @today", title: "Pay rent", scheduled: "2026-09-30"),
        .init(input: "t Pay rent @tom", title: "Pay rent", scheduled: "2026-10-01"),
        .init(input: "t Pay rent @wed", title: "Pay rent", scheduled: "2026-09-30"),
        .init(input: "t Pay rent @tue", title: "Pay rent", scheduled: "2026-10-06"),
        .init(input: "t Pay rent @sun", title: "Pay rent", scheduled: "2026-10-04"),
        .init(input: "t Ship @FRI", title: "Ship", scheduled: "2026-10-02"),
        .init(input: "t Pay rent @2026-10-03", title: "Pay rent", scheduled: "2026-10-03"),
        .init(input: "t Pay rent @+3d", title: "Pay rent", scheduled: "2026-10-03"),
        .init(input: "t Pay rent @+0d", title: "Pay rent", scheduled: "2026-09-30"),
        .init(input: "t Pay rent @due:fri", title: "Pay rent", due: "2026-10-02"),
        .init(input: "t Pay rent @due:2026-12-01 @mon", title: "Pay rent", scheduled: "2026-10-05", due: "2026-12-01"),
        .init(input: "t Multiple @mon @tue", title: "Multiple", scheduled: "2026-10-06"),
        .init(input: "t @tom first", title: "first", scheduled: "2026-10-01"),
        // Never eat unknown text
        .init(input: "t Email @home about it", title: "Email @home about it"),
        .init(input: "t Email @due:someday", title: "Email @due:someday"),
        .init(input: "t Plan @2026-02-30", title: "Plan @2026-02-30"),
        .init(input: "t Fix #1 bug", title: "Fix #1 bug"),
        .init(input: "t Wow !4", title: "Wow !4"),
        .init(input: "t Wow !", title: "Wow !"),
        .init(input: "t Read ~soon", title: "Read ~soon"),
        .init(input: "t compare a > b", title: "compare a > b"),
        .init(input: "t Paren >", title: "Paren >"),
        .init(input: "t Link [[Unclosed", title: "Link [[Unclosed"),
        .init(input: "t mail me@example.com #x", title: "mail me@example.com", tags: ["x"]),
        // Tags, priority, estimate, parent, links
        .init(input: "t Tag #a #b #A", title: "Tag", tags: ["a", "b"]),
        .init(input: "t Read ~2h", title: "Read", estimate: 120),
        .init(input: "t Read ~1h30m !3", title: "Read", priority: 3, estimate: 90),
        .init(input: "t Draft PDF >Q4 invoicing", title: "Draft PDF", parent: "Q4 invoicing"),
        .init(input: "t Draft PDF >Q4 invoicing @fri #work", title: "Draft PDF", scheduled: "2026-10-02", tags: ["work"], parent: "Q4 invoicing"),
        .init(input: "t Call about [[Client note]] @tom", title: "Call about [[Client note]]", scheduled: "2026-10-01", links: ["Client note"]),
        .init(input: "t Rent #home/bills", title: "Rent", tags: ["home/bills"]),
        // Notes keep task tokens as text
        .init(input: "n See [[Antenna notes]] #rf", kind: .note, title: "See [[Antenna notes]]", tags: ["rf"], links: ["Antenna notes"]),
        .init(input: "n Budget !1 ~45m @fri >Parent", kind: .note, title: "Budget !1 ~45m @fri >Parent"),
        // Habit logs
        .init(input: "h swim", kind: .habitLog, title: "swim"),
        .init(input: "h piano practice 30", kind: .habitLog, title: "piano practice", minutes: 30),
        .init(input: "h swim 1h30m", kind: .habitLog, title: "swim", minutes: 90),
        .init(input: "h swim 45 @tom", kind: .habitLog, title: "swim", scheduled: "2026-10-01", minutes: 45),
        .init(input: "h swim 45 !1 #x", kind: .habitLog, title: "swim", minutes: 45, note: "!1 #x"),
        .init(input: "h walk dog 20m with Ayşe", kind: .habitLog, title: "walk dog", minutes: 20, note: "with Ayşe"),
        .init(input: "h 45", kind: .habitLog, minutes: 45),
        .init(input: "h yoga 0", kind: .habitLog, title: "yoga 0"),
    ]

    @Test(arguments: cases)
    func grammarTable(_ expected: QuickInputCase) {
        let parsed = QuickInputParser.parse(expected.input, today: Self.today)
        #expect(parsed.kind == expected.kind)
        #expect(parsed.title == expected.title)
        #expect(parsed.scheduled?.description == expected.scheduled)
        #expect(parsed.due?.description == expected.due)
        #expect(parsed.tags == expected.tags)
        #expect(parsed.priority == expected.priority)
        #expect(parsed.estimate?.minutes == expected.estimate)
        #expect(parsed.parent == expected.parent)
        #expect(parsed.links.map(\.target) == expected.links)
        #expect(parsed.minutes == expected.minutes)
        #expect(parsed.note == expected.note)
        #expect(parsed.command == expected.command)
    }

    @Test func tableHasAtLeastFortyCases() {
        #expect(Self.cases.count >= 40)
    }

    @Test func defaultKindAppliesWithoutAPrefix() {
        #expect(QuickInputParser.parse("hello world", today: Self.today, defaultKind: .note).kind == .note)
        #expect(QuickInputParser.parse("t hello", today: Self.today, defaultKind: .note).kind == .task)
        #expect(QuickInputParser.parse("hello", today: Self.today, defaultKind: .command).kind == .task)
    }

    @Test func tokensCarryTheirPlaceForChips() {
        let input = "t Send invoice >Q4 invoicing @fri #work"
        let parsed = QuickInputParser.parse(input, today: Self.today)
        #expect(parsed.tokens.map(\.kind) == [.kind, .parent, .scheduled, .tag])
        #expect(parsed.tokens.map { String(input[$0.range]) } == ["t", ">Q4 invoicing", "@fri", "#work"])
    }

    @Test func titleNeverLosesAWordThatIsNotAToken() {
        // Property: every word of the input is either in a token or in the title/note, in order.
        var rng = SplitMix64(seed: 5)
        let pool = ["@fri", "@nope", "#t", "#1", "!2", "!9", "~30m", "~x", ">Parent", "[[Link]]", "word", "a:b", "@due:tom", "45"]
        for _ in 0 ..< 300 {
            let prefix = rng.pick(["t ", "n ", "h ", ""])
            let words = (0 ..< rng.int(0 ... 6)).map { _ in rng.pick(pool) }
            let input = prefix + words.joined(separator: " ")
            let parsed = QuickInputParser.parse(input, today: Self.today)
            let tokenText = parsed.tokens.filter { $0.kind != .kind && $0.kind != .link }.map(\.text).joined(separator: " ")
            let kept = [parsed.title, parsed.note, tokenText].joined(separator: " ")
            for word in words where word != ">Parent" {
                #expect(kept.contains(word), "lost \(word) in \(input)")
            }
        }
    }
}
