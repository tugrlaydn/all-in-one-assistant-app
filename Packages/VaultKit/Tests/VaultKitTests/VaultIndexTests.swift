import Foundation
import Testing
@testable import VaultKit

@Suite("VaultIndex")
struct VaultIndexTests {
    let index: VaultIndex

    init() throws {
        index = VaultIndex(entries: try Fixtures.files(inVault: "Basic").map { path in
            IndexEntry(path: path, document: MarkdownDocument(parsing: try Fixtures.text("Vaults/Basic/" + path)))
        })
    }

    func paths(_ entries: [IndexEntry]) -> [String] { entries.map(\.path) }

    @Test func entriesAndKinds() throws {
        #expect(index.count == 9)
        let kinds = Dictionary(grouping: index.entries.values, by: { $0.kind?.rawValue ?? "unmanaged" }).mapValues(\.count)
        #expect(kinds == ["task": 2, "note": 2, "unmanaged": 1, "habit": 2, "habit-week": 1, "habit-categories": 1])
        let plain = try #require(index.entry(path: "Notes/Plain note.md"))
        #expect(plain.title == "Plain note")
        #expect(plain.links == ["Antenna notes"])
        #expect(index.entry(path: "Habits/Categories.md")?.title == "Categories")
    }

    @Test func lookupsByIdTitleAndTag() throws {
        #expect(index.entry(id: try #require(ULID("01J9K4TASK0000000000000001")))?.title == "Send invoice")
        #expect(paths(index.entries(titled: "send INVOICE")) == ["Tasks/Send invoice.md"])
        #expect(paths(index.entries(tagged: "work")) == ["Notes/Client note.md", "Tasks/Q4 invoicing.md", "Tasks/Send invoice.md"])
        #expect(paths(index.entries(tagged: "#RF")) == ["Notes/Antenna notes.md"])
        #expect(paths(index.entries(tagged: "inline-tag")) == ["Notes/Antenna notes.md"])
    }

    @Test func linksResolveByTitlePathAndId() {
        #expect(index.resolve(WikiLink("client NOTE"))?.path == "Notes/Client note.md")
        #expect(index.resolve(WikiLink("Notes/Antenna notes"))?.path == "Notes/Antenna notes.md")
        #expect(index.resolve(WikiLink("01J9K5HAB1T000000000000002"))?.path == "Habits/Piano.md")
        #expect(index.resolve(WikiLink("Nowhere")) == nil)
    }

    @Test func backlinksAndOutgoing() {
        #expect(paths(index.backlinks(to: "Tasks/Q4 invoicing.md")) == ["Notes/Client note.md", "Tasks/Send invoice.md"])
        #expect(paths(index.backlinks(to: "Notes/Antenna notes.md")) == ["Notes/Plain note.md"])
        #expect(paths(index.backlinks(to: "Habits/Swimming.md")) == ["Habits/Weeks/2026-W40.md"])
        #expect(paths(index.backlinks(to: "Tasks/Send invoice.md")) == ["Notes/Antenna notes.md"])
        #expect(paths(index.outgoing(from: "Tasks/Send invoice.md")) == ["Notes/Client note.md", "Tasks/Q4 invoicing.md"])
    }

    @Test func daysForTheHorizon() throws {
        func titles(_ day: String) throws -> [String] { index.items(on: try #require(Day(day))).map(\.title) }
        #expect(try titles("2026-09-28") == ["Antenna notes", "2026-W40"])
        #expect(try titles("2026-09-29") == ["Client note", "2026-W40"]) // 23:30 +03:00 stays on the 29th
        #expect(try titles("2026-09-30") == ["Send invoice"]) // scheduled wins over due
        #expect(try titles("2026-10-31") == ["Q4 invoicing"]) // due when not scheduled
        let monday = try #require(Day("2026-09-28"))
        let week = monday ... monday.adding(days: 6)
        #expect(index.density(in: week) == [Day("2026-09-28")!: 2, Day("2026-09-29")!: 2, Day("2026-09-30")!: 1])
    }

    @Test func fuzzySearch() {
        #expect(index.search("inv").map(\.title) == ["Q4 invoicing", "Send invoice"])
        #expect(index.search("sinv").map(\.title) == ["Send invoice"])
        #expect(index.search("swim", kinds: [.habit]).map(\.title) == ["Swimming"])
        #expect(index.search("   ").isEmpty)
        #expect(index.search("zzz").isEmpty)
    }

    @Test func fuzzyScoring() throws {
        let matcher = FuzzyMatcher("cal")
        #expect(matcher.score("Çalışma planı") != nil)
        let exact = try #require(FuzzyMatcher("piano").score("Piano"))
        let prefix = try #require(FuzzyMatcher("pia").score("Piano"))
        let scattered = try #require(FuzzyMatcher("pno").score("Piano"))
        #expect(exact > prefix && prefix > scattered)
        #expect(FuzzyMatcher("isim").score("İsim listesi") != nil)
    }

    @Test func incrementalUpdates() throws {
        var index = index
        index.remove(path: "Tasks/Send invoice.md")
        #expect(index.backlinks(to: "Tasks/Q4 invoicing.md").map(\.path) == ["Notes/Client note.md"])
        #expect(index.items(on: try #require(Day("2026-09-30"))).isEmpty)
        #expect(index.entry(id: try #require(ULID("01J9K4TASK0000000000000001"))) == nil)

        var note = try #require(Note(document: MarkdownDocument(parsing: Fixtures.text("Vaults/Basic/Notes/Client note.md"))))
        note.setTitle("Customer note")
        index.upsert(IndexEntry(path: "Notes/Client note.md", document: note.document))
        #expect(index.entries(titled: "Client note").isEmpty)
        #expect(index.entries(titled: "Customer note").map(\.path) == ["Notes/Client note.md"])
        #expect(index.count == 8)
    }

    @Test func cacheRoundTrip() throws {
        let data = try IndexCache(index: index).encoded()
        let cache = try #require(IndexCache.decode(data))
        #expect(VaultIndex(entries: cache.entries) == index)
        #expect(IndexCache.decode(Data("{\"version\": 999, \"entries\": []}".utf8)) == nil)
        #expect(IndexCache.decode(Data("not json".utf8)) == nil)
    }
}
