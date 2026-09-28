import Foundation
import Testing
@testable import VaultKit

@Suite("MarkdownDocument — reading and round-trip")
struct MarkdownDocumentReadTests {
    /// FORMAT §4.3, verbatim — comments, alignment and all.
    static let task = """
    ---
    id: 01J9K4ABCDEFGHJKMNPQRSTVWX
    type: task
    title: Send invoice
    status: todo              # todo | doing | done | dropped
    created: 2026-09-28T09:12:00+03:00
    updated: 2026-09-28T09:12:00+03:00
    scheduled: 2026-09-30     # the day it sits on in the Horizon (optional)
    due: 2026-10-03           # deadline (optional)
    done_at:                  # set when status becomes done
    priority: 2               # 1 high · 2 normal · 3 low (optional)
    estimate: 45m             # optional
    tags: [work]
    parent: "[[Q4 invoicing]]"      # optional — another task
    links: ["[[Client note]]"]      # optional — [[links]] in the body also count
    ---
    Free notes about the task.

    ## Subtasks
    - [ ] Draft the PDF
      - [ ] Check hours
    - [x] Get the PO number

    """

    static let categories = """
    ---
    type: habit-categories
    budget_minutes_per_week:
      physical: 150
      creative: 90
      knowledge: 120
      mindset: 60
      monetizable: 90
    nudge_times: ["12:30", "20:00"]
    ---

    """

    @Test(arguments: [
        task,
        categories,
        "",
        "just a body\nno front matter",
        "---\n",
        "---\nunterminated: yes\nbody",
        "---\n---\n",
        "---\r\ntitle: CRLF\r\n---\r\nbody\r\n",
        "\u{FEFF}---\ntitle: BOM\n---\nbody",
        "---\ntitle: x\n...\nYAML end marker",
        "---\ntitle: no newline at end\n---",
        "---\ntags:\n- a\n- b\n# comment\nweird line without colon\n  indented orphan\n---\n---\nbody with a rule\n",
        "  ---\nnot front matter\n---\n",
        "---\ntitle: tab\there\n---\n\t\n\r\n\r",
    ])
    func roundTripIsByteIdentical(_ text: String) {
        #expect(MarkdownDocument(parsing: text).text == text)
        #expect(MarkdownDocument(data: Data(text.utf8))?.data == Data(text.utf8))
    }

    @Test func readsTheTaskExample() throws {
        let doc = MarkdownDocument(parsing: Self.task)
        let fm = try #require(doc.frontMatter)
        #expect(doc.type == "task")
        #expect(fm.string("status") == "todo")
        #expect(fm.string("scheduled") == "2026-09-30")
        #expect(fm.string("done_at") == nil)
        #expect(fm.value("done_at") == .null)
        #expect(fm.int("priority") == 2)
        #expect(fm.string("estimate") == "45m")
        #expect(fm.list("tags") == ["work"])
        #expect(fm.string("parent") == "[[Q4 invoicing]]")
        #expect(fm.list("links") == ["[[Client note]]"])
        #expect(fm.keys == ["id", "type", "title", "status", "created", "updated", "scheduled", "due",
                            "done_at", "priority", "estimate", "tags", "parent", "links"])
        #expect(doc.body.hasPrefix("Free notes about the task.\n"))
    }

    @Test func readsMapsAndBlockLists() throws {
        let fm = try #require(MarkdownDocument(parsing: Self.categories).frontMatter)
        #expect(fm.map("budget_minutes_per_week") == [
            YAMLPair("physical", "150"), YAMLPair("creative", "90"), YAMLPair("knowledge", "120"),
            YAMLPair("mindset", "60"), YAMLPair("monetizable", "90"),
        ])
        #expect(fm.list("nudge_times") == ["12:30", "20:00"])

        let obsidian = try #require(MarkdownDocument(parsing: "---\ntags:\n  - rf\n  - \"capsule\"\naliases:\n- A\n---\n").frontMatter)
        #expect(obsidian.list("tags") == ["rf", "capsule"])
        #expect(obsidian.list("aliases") == ["A"])
    }

    @Test func readsQuotingAndComments() throws {
        let text = """
        ---
        a: "say \\"hi\\"\\n"   # comment
        b: 'it''s'
        c: C# is not a comment
        d: "# is a value"
        e: plain # comment
        f: {x: 1, y: "two"}
        g: |
          line one
          line two
        "quoted key": v
        ---
        """
        let fm = try #require(MarkdownDocument(parsing: text).frontMatter)
        #expect(fm.string("a") == "say \"hi\"\n")
        #expect(fm.string("b") == "it's")
        #expect(fm.string("c") == "C# is not a comment")
        #expect(fm.string("d") == "# is a value")
        #expect(fm.string("e") == "plain")
        #expect(fm.map("f") == [YAMLPair("x", "1"), YAMLPair("y", "two")])
        #expect(fm.string("g") == "line one\nline two")
        #expect(fm.string("quoted key") == "v")
    }

    @Test func invalidUTF8IsRefusedNotMangled() {
        #expect(MarkdownDocument(data: Data([0x2D, 0x2D, 0x2D, 0x0A, 0xFF, 0xFE])) == nil)
    }
}

@Suite("MarkdownDocument — minimal edits")
struct MarkdownDocumentEditTests {
    func edited(_ text: String, _ edit: (inout FrontMatter) -> Void) -> String {
        var doc = MarkdownDocument(parsing: text)
        edit(&doc.frontMatter!)
        return doc.text
    }

    @Test func changingAValueKeepsItsCommentColumn() {
        let result = edited(MarkdownDocumentReadTests.task) { $0.set("status", .scalar("done"), as: .literal) }
        #expect(result == MarkdownDocumentReadTests.task.replacingOccurrences(
            of: "status: todo              #", with: "status: done              #"
        ))
    }

    @Test func fillingAnEmptyValueEatsIntoThePadding() {
        let result = edited(MarkdownDocumentReadTests.task) {
            $0.set("done_at", .scalar("2026-09-30T18:00:00+03:00"), as: .literal)
        }
        #expect(result.contains("\ndone_at: 2026-09-30T18:00:00+03:00 # set when status becomes done\n"))
        #expect(MarkdownDocument(parsing: result).frontMatter?.string("done_at") == "2026-09-30T18:00:00+03:00")
    }

    @Test func clearingAValueKeepsTheComment() {
        let result = edited(MarkdownDocumentReadTests.task) { $0.set("due", .null) }
        #expect(result.contains("\ndue:                      # deadline (optional)\n"))
    }

    @Test func onlyTheEditedLineChanges() {
        let before = Line.split(MarkdownDocumentReadTests.task)
        let after = Line.split(edited(MarkdownDocumentReadTests.task) { $0.set("title", .scalar("Send the invoice")) })
        #expect(before.count == after.count)
        let changed = zip(before, after).enumerated().filter { $0.element.0 != $0.element.1 }.map(\.offset)
        #expect(changed == [3])
        #expect(after[3].content == "title: Send the invoice")
    }

    @Test func newKeysAreAppendedAtTheEnd() {
        let result = edited("---\ntitle: A\n# keep me\n---\nbody") { $0.set("tags", .list(["x", "y z"])) }
        #expect(result == "---\ntitle: A\n# keep me\ntags: [x, y z]\n---\nbody")
    }

    @Test func blockListsStayBlockLists() {
        let result = edited("---\ntags:\n  - a\n  - b\ntitle: T\n---\n") { $0.set("tags", .list(["c", "[[d]]"])) }
        #expect(result == "---\ntags:\n  - c\n  - \"[[d]]\"\ntitle: T\n---\n")
    }

    @Test func mapValuesChangeOneLine() {
        let result = edited(MarkdownDocumentReadTests.categories) {
            $0.setMapValue("budget_minutes_per_week", "mindset", "75", as: .literal)
        }
        #expect(result == MarkdownDocumentReadTests.categories.replacingOccurrences(of: "mindset: 60", with: "mindset: 75"))

        let added = edited("---\nplan:\n  physical: \"[[Swimming]]\"\nweek: 2026-W40\n---\n") {
            $0.setMapValue("plan", "creative", "[[Piano]]")
        }
        #expect(added == "---\nplan:\n  physical: \"[[Swimming]]\"\n  creative: \"[[Piano]]\"\nweek: 2026-W40\n---\n")

        let fresh = edited("---\nweek: 2026-W40\nplan:\n---\n") { $0.setMapValue("plan", "physical", "[[Swim]]") }
        #expect(fresh == "---\nweek: 2026-W40\nplan:\n  physical: \"[[Swim]]\"\n---\n")
    }

    @Test func crlfFilesGetCRLFLines() {
        let result = edited("---\r\ntitle: A\r\n---\r\n") { $0.set("status", .scalar("todo"), as: .literal) }
        #expect(result == "---\r\ntitle: A\r\nstatus: todo\r\n---\r\n")
    }

    @Test(arguments: [
        ("Send invoice", "Send invoice"),
        ("Q4: plan", "\"Q4: plan\""),
        ("2026", "\"2026\""),
        ("true", "\"true\""),
        ("2026-09-30", "\"2026-09-30\""),
        ("[[Link]]", "\"[[Link]]\""),
        ("- dash", "\"- dash\""),
        ("a #b", "\"a #b\""),
        ("", "\"\""),
        ("line\nbreak", "\"line\\nbreak\""),
        ("Çalışma planı ☀️", "Çalışma planı ☀️"),
        ("C# notes", "C# notes"),
    ])
    func textScalarsAreQuotedOnlyWhenNeeded(_ input: String, _ expected: String) {
        let result = edited("---\n---\n") { $0.set("title", .scalar(input)) }
        #expect(result == "---\ntitle: \(expected)\n---\n")
        #expect(MarkdownDocument(parsing: result).frontMatter?.string("title") == input)
    }

    @Test func literalsAreWrittenAsGiven() {
        let result = edited("---\n---\n") {
            $0.set("priority", .scalar("2"), as: .literal)
            $0.set("active", .scalar("true"), as: .literal)
            $0.set("scheduled", .scalar("2026-09-30"), as: .literal)
        }
        #expect(result == "---\npriority: 2\nactive: true\nscheduled: 2026-09-30\n---\n")
    }
}

@Suite("MarkdownDocument — fuzz")
struct MarkdownDocumentFuzzTests {
    static let keys = ["id", "type", "title", "status", "tags", "links", "plan", "notes", "x-custom", "Çeşit"]

    static let texts = [
        "Send invoice", "Q4: plan", "2026", "true", "[[Link]]", "- dash", "a #b", "", " padded ",
        "line\nbreak", "tab\there", "Çalışma ☀️", "C# notes", "\"quoted\"", "it's", "{brace}", "a, b",
        "|pipe", ">gt", "@at", "!bang", "~tilde", "%pct", "back\\slash", "\u{00A0}nbsp", "end:",
    ]

    /// A random vault-ish file: every construct the parser knows, plus junk it must leave alone.
    static func randomDocument(_ rng: inout SplitMix64) -> String {
        let nl = rng.chance(0.2) ? "\r\n" : "\n"
        var out = rng.chance(0.05) ? "\u{FEFF}" : ""
        let hasFrontMatter = rng.chance(0.9)
        if hasFrontMatter {
            out += "---" + nl
            for key in keys.shuffled(using: &rng).prefix(rng.int(0 ... keys.count)) {
                out += randomEntry(key, nl: nl, &rng)
                if rng.chance(0.1) { out += nl }
                if rng.chance(0.1) { out += "# a comment line" + nl }
            }
            if rng.chance(0.05) { out += "junk line without a colon" + nl }
            out += (rng.chance(0.1) ? "..." : "---") + (rng.chance(0.1) ? "" : nl)
        }
        for _ in 0 ..< rng.int(0 ... 6) {
            out += rng.pick(["Body text", "## Subtasks", "- [ ] item", "  - [x] nested", "---", "| a | b |", "", "#tag [[Link]]"])
            out += nl
        }
        if rng.chance(0.3) { out += "no final newline" }
        return out
    }

    static func randomEntry(_ key: String, nl: String, _ rng: inout SplitMix64) -> String {
        let comment = rng.chance(0.3) ? "   # note" : ""
        switch rng.int(0 ... 5) {
        case 0: return "\(key): \(YAMLScalar.render(rng.pick(texts), style: .text))\(comment)\(nl)"
        case 1: return "\(key):\(comment)\(nl)"
        case 2:
            let items = (0 ..< rng.int(0 ... 3)).map { _ in YAMLScalar.render(rng.pick(texts), style: .text, inFlow: true) }
            return "\(key): [\(items.joined(separator: ", "))]\(comment)\(nl)"
        case 3:
            let dash = rng.chance(0.5) ? "  - " : "- "
            return "\(key):\(nl)" + (1 ... rng.int(1 ... 3)).map { _ in dash + YAMLScalar.render(rng.pick(texts), style: .text) + nl }.joined()
        case 4:
            return "\(key):\(nl)" + ["physical", "creative", "mindset"].prefix(rng.int(1 ... 3)).map {
                "  \($0): \(YAMLScalar.render(rng.pick(texts), style: .text))\(nl)"
            }.joined()
        default: return "\(key): plain value\(comment)\(nl)"
        }
    }

    static func randomValue(_ rng: inout SplitMix64) -> YAMLValue {
        switch rng.int(0 ... 3) {
        case 0: .null
        case 1: .scalar(rng.pick(texts))
        case 2: .list((0 ..< rng.int(0 ... 3)).map { _ in rng.pick(texts) })
        default: .map(["physical", "creative"].prefix(rng.int(1 ... 2)).map { YAMLPair($0, rng.chance(0.2) ? nil : rng.pick(texts)) })
        }
    }

    @Test func twoHundredGeneratedFilesRoundTripAndEditMinimally() throws {
        var rng = SplitMix64(seed: 2026)
        for _ in 0 ..< 200 {
            let text = Self.randomDocument(&rng)
            let doc = MarkdownDocument(parsing: text)
            try #require(doc.text == text, "round trip failed for:\n\(text)")
            guard let original = doc.frontMatter else { continue }

            let key = rng.pick(Self.keys)
            let value = Self.randomValue(&rng)
            var edited = doc
            edited.frontMatter!.set(key, value)

            // What was written reads back — through a full re-parse of the bytes.
            let reparsed = MarkdownDocument(parsing: edited.text)
            try #require(reparsed.frontMatter != nil)
            #expect(reparsed.frontMatter!.value(key) == value, "\(key) = \(value) in:\n\(edited.text)")
            // Nothing else moved: body, other keys' lines, and the delimiters.
            #expect(reparsed.body == doc.body)
            #expect(reparsed.frontMatter!.opening == original.opening)
            for other in original.keys where other != key {
                let before = original.entry(for: other).map { Array(original.lines[$0.range]) }
                let after = reparsed.frontMatter!.entry(for: other).map { Array(reparsed.frontMatter!.lines[$0.range]) }
                #expect(before == after, "\(other) changed after editing \(key) in:\n\(text)")
            }
        }
    }
}
