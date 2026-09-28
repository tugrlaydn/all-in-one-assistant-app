import Foundation
import Testing
@testable import VaultKit

/// One test per finding of the P1 review pass, so none of them can come back.
@Suite("P1 review regressions", .serialized)
struct ReviewRegressionTests {
    let id = ULID("01J9K4TASK0000000000000009")!

    @Test func hugeDatesAndEstimatesNeverTrap() {
        #expect(Day(daysSince1970: .max).description == "9999-12-31")
        #expect(Day(daysSince1970: .min).description == "0001-01-01")
        let today = Day("2026-09-30")!
        #expect(today.adding(days: .max).description == "9999-12-31")
        #expect(today.adding(days: .min).description == "0001-01-01")
        #expect(today.adding(days: .max).week.year == 9999)
        #expect(ISOWeek("2026-W40")!.adding(weeks: .max).year == 9999)
        #expect(Estimate("153722867280912931h") == nil)
        #expect(Estimate("99999999999999999999m") == nil)
        #expect(Estimate("1000h")?.minutes == 60_000)
    }

    @Test func aBodyAfterABareClosingDelimiterStartsOnItsOwnLine() {
        var task = TaskItem(document: MarkdownDocument(parsing: "---\nid: \(id)\ntype: task\ntitle: T\n---"))!
        task.addSubtask("First")
        #expect(task.document.text == "---\nid: \(id)\ntype: task\ntitle: T\n---\n## Subtasks\n- [ ] First\n")
        #expect(TaskItem(document: MarkdownDocument(parsing: task.document.text))?.subtasks.map(\.text) == ["First"])
    }

    @Test func logRowsFollowTheTablesColumnOrder() {
        let text = "---\nid: \(id)\ntype: habit-week\nweek: 2026-W40\n---\n## Log\n| minutes | date | habit | where | note |\n|---|---|---|---|---|\n"
        var week = HabitWeek(document: MarkdownDocument(parsing: text))!
        week.appendLog(day: Day("2026-09-30")!, habit: WikiLink("Swimming"), minutes: 40, note: "lake")
        #expect(week.document.body.hasSuffix("| 40 | 2026-09-30 | [[Swimming]] |  | lake |\n"))
        #expect(week.log.first?.minutes == 40)
        #expect(week.log.first?.note == "lake")
    }

    @Test func fencedCodeIsNotStructure() {
        let body = "## Subtasks\n- [ ] Real\n```\n# not a heading\n- [ ] not a subtask\n```\n- [ ] Also real\n"
        let task = TaskItem(document: MarkdownDocument(parsing: "---\nid: \(id)\ntype: task\n---\n" + body))!
        #expect(task.subtasks.map(\.text) == ["Real", "Also real"])

        let week = HabitWeek(document: MarkdownDocument(parsing: """
        ---
        id: \(id)
        type: habit-week
        week: 2026-W40
        ---
        ```
        ## Log
        | date | habit | minutes | note |
        |---|---|---|---|
        | 2026-09-01 | [[Fake]] | 1 | in code |
        ```
        ## Log
        | date | habit | minutes | note |
        |---|---|---|---|
        | 2026-09-30 | [[Swimming]] | 45 | real |
        """))!
        #expect(week.log.map(\.note) == ["real"])
    }

    @Test func duplicateIdsSurviveRemovingOneCopy() {
        let text = "---\nid: \(id)\ntype: note\ntitle: A\n---\n"
        var index = VaultIndex()
        index.upsert(IndexEntry(path: "Notes/A.md", document: MarkdownDocument(parsing: text)))
        index.upsert(IndexEntry(path: "Notes/A 2.md", document: MarkdownDocument(parsing: text)))
        #expect(index.entry(id: id)?.path == "Notes/A.md")
        #expect(index.entries(id: id).count == 2)
        index.remove(path: "Notes/A.md")
        #expect(index.entry(id: id)?.path == "Notes/A 2.md")
    }

    @Test func secondDateOrPriorityStaysInTheTitle() {
        let parsed = QuickInputParser.parse("t Call @mon @tue !1 !2", today: Day("2026-09-30")!)
        #expect(parsed.scheduled?.description == "2026-10-05")
        #expect(parsed.priority == 1)
        #expect(parsed.title == "Call @tue !2")
    }

    // MARK: Vault

    func withVault(_ body: (Vault, URL) async throws -> Void) async throws {
        let root = try Fixtures.copyVault("Basic")
        defer { Fixtures.removeCopy(root) }
        try await body(try Vault(root: root), root)
    }

    @Test func aFileNamedDifferentlyIsNotRenamedByAnUnrelatedEdit() async throws {
        try await withVault { vault, root in
            try FileManager.default.moveItem(
                at: root.appendingPathComponent("Tasks/Send invoice.md"),
                to: root.appendingPathComponent("Tasks/ACME invoice (owner named).md")
            )
            try await vault.load()
            var task = try await vault.item(TaskItem.self, at: "Tasks/ACME invoice (owner named).md")
            task.setPriority(1)
            let saved = try await vault.save(task, at: "Tasks/ACME invoice (owner named).md")
            #expect(saved.path == "Tasks/ACME invoice (owner named).md")
        }
    }

    @Test func anICloudStubStillOwnsItsName() async throws {
        try await withVault { vault, root in
            try Data("stub".utf8).write(to: root.appendingPathComponent("Notes/.Ideas.md.icloud"))
            try await vault.load()
            let saved = try await vault.save(Note.new(title: "Ideas"), at: nil)
            #expect(saved.path == "Notes/Ideas-2.md")
        }
    }

    @Test func creatingBeforeLoadingIsRefused() async throws {
        try await withVault { vault, _ in
            await #expect(throws: VaultError.notLoaded) { try await vault.save(Note.new(title: "Early"), at: nil) }
        }
    }

    @Test func refreshIgnoresWhatTheScanIgnores() async throws {
        try await withVault { vault, root in
            try await vault.load()
            try FileManager.default.createDirectory(at: root.appendingPathComponent(".obsidian"), withIntermediateDirectories: true)
            try Data("---\ntitle: hidden\n---\n".utf8).write(to: root.appendingPathComponent(".obsidian/x.md"))
            let changed = try await vault.refresh([".obsidian/x.md", "Notes/.hidden.md"])
            #expect(changed.isEmpty)
            #expect(await vault.index.entry(path: ".obsidian/x.md") == nil)
        }
    }

    @Test func rescanWritesNothing() async throws {
        try await withVault { vault, root in
            try await vault.load()
            let cacheURL = root.appendingPathComponent(IndexCache.path)
            let before = try Data(contentsOf: cacheURL)
            try Data("---\ntitle: Touched\n---\n".utf8).write(to: root.appendingPathComponent("Notes/Plain note.md"))
            let changed = try await vault.rescan()
            #expect(changed == ["Notes/Plain note.md"])
            #expect(try Data(contentsOf: cacheURL) == before, "no write on the watcher's tick (§8.3)")
        }
    }

    @Test func restartingTheWatcherKeepsTheNewStream() async throws {
        try await withVault { vault, root in
            try await vault.load()
            let watcher = VaultWatcher(vault: vault, interval: .milliseconds(100))
            _ = await watcher.start()
            let second = await watcher.start()
            let received = Task { () -> Set<String>? in
                for await batch in second { return batch }
                return nil
            }
            try await Task.sleep(for: .milliseconds(300)) // let the old stream's termination run
            try Data("---\ntitle: Touched\n---\n".utf8).write(to: root.appendingPathComponent("Notes/Plain note.md"))
            let deadline = ContinuousClock.now + .seconds(2)
            while ContinuousClock.now < deadline, !(await vault.index.entry(path: "Notes/Plain note.md")?.title == "Touched") {
                try await Task.sleep(for: .milliseconds(20))
            }
            try await Task.sleep(for: .milliseconds(100))
            await watcher.stop()
            #expect(await received.value == ["Notes/Plain note.md"])
        }
    }
}
