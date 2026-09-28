import Foundation
import Testing
@testable import VaultKit

/// Every test works on a private copy of a fixture vault in the temp directory (§8.6).
@Suite("Vault", .serialized)
struct VaultTests {
    let files = CoordinatedFileAccess()

    func withVault(_ fixture: String? = "Basic", _ body: (Vault, URL) async throws -> Void) async throws {
        let root: URL
        if let fixture {
            root = try Fixtures.copyVault(fixture)
        } else {
            root = FileManager.default.temporaryDirectory.appendingPathComponent("persona-tests-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        defer { Fixtures.removeCopy(root) }
        try await body(try Vault(root: root, files: files), root)
    }

    func read(_ root: URL, _ path: String) throws -> String {
        try #require(String(validating: Data(contentsOf: root.appendingPathComponent(path)), as: UTF8.self))
    }

    func write(_ root: URL, _ path: String, _ text: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    // MARK: Skeleton

    @Test func skeletonCreatesFoldersOnlyAndOnlyOnce() async throws {
        try await withVault(nil) { vault, root in
            let created = try await vault.createSkeleton()
            let createdAgain = try await vault.createSkeleton()
            #expect(created == Vault.skeleton)
            #expect(createdAgain.isEmpty)
            let everything = FileManager.default.enumerator(atPath: root.path)?.allObjects as? [String] ?? []
            #expect(Set(everything) == Set(Vault.skeleton), "no sample files, ever (D10)")
            let categories = try await vault.categories()
            #expect(categories == nil)
        }
    }

    @Test func refusesAFileAsRoot() throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("persona-tests-\(UUID().uuidString).md")
        try Data().write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(throws: VaultError.notAFolder(file.path)) { try Vault(root: file) }
    }

    // MARK: Loading and the cache

    @Test func loadIndexesEveryFileAndCachesIt() async throws {
        try await withVault { vault, root in
            let first = try await vault.load()
            #expect(first.indexed == 9)
            #expect(first.parsed == 9)
            #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent(IndexCache.path).path))

            let second = try await Vault(root: root, files: files).load()
            #expect(second.fromCache == 9)
            #expect(second.parsed == 0)

            try write(root, "Notes/Client note.md", try read(root, "Notes/Client note.md") + "One more line.\n")
            let third = try await Vault(root: root, files: files).load()
            #expect(third.fromCache == 8)
            #expect(third.parsed == 1)

            let rebuilt = try await Vault(root: root, files: files).load(useCache: false)
            #expect(rebuilt.parsed == 9)
            #expect(await vault.index.entry(path: "Tasks/Send invoice.md")?.title == "Send invoice")
        }
    }

    @Test func loadSkipsDotFoldersAndReportsPlaceholdersAndBadFiles() async throws {
        try await withVault { vault, root in
            try write(root, ".obsidian/workspace.md", "hidden")
            try write(root, ".trash/Old.md", "deleted")
            try write(root, "Notes/.Ghost.md.icloud", "stub")
            try Data([0xFF, 0xFE, 0x00]).write(to: root.appendingPathComponent("Notes/Bad.md"))
            let report = try await vault.load()
            #expect(report.indexed == 9)
            #expect(report.placeholders == ["Notes/Ghost.md"])
            #expect(report.unreadable == ["Notes/Bad.md"])
        }
    }

    // MARK: Saving

    @Test func anUnchangedItemIsNeverWritten() async throws {
        try await withVault { vault, root in
            try await vault.load()
            let before = try Data(contentsOf: root.appendingPathComponent("Tasks/Send invoice.md"))
            let stampBefore = files.attributes(of: root.appendingPathComponent("Tasks/Send invoice.md"))
            let task = try await vault.item(TaskItem.self, at: "Tasks/Send invoice.md")
            let saved = try await vault.save(task, at: "Tasks/Send invoice.md")
            #expect(saved.path == "Tasks/Send invoice.md")
            #expect(try Data(contentsOf: root.appendingPathComponent("Tasks/Send invoice.md")) == before)
            #expect(files.attributes(of: root.appendingPathComponent("Tasks/Send invoice.md")).modified == stampBefore.modified)
        }
    }

    @Test func savingAnEditChangesOnlyTheEditedLinesAndStampsUpdated() async throws {
        try await withVault { vault, root in
            try await vault.load()
            let original = try read(root, "Tasks/Send invoice.md")
            var task = try await vault.item(TaskItem.self, at: "Tasks/Send invoice.md")
            let now = try #require(Timestamp("2026-09-30T18:00:00+03:00"))
            task.setStatus(.done, at: now)
            let saved = try await vault.save(task, at: "Tasks/Send invoice.md", now: now)

            let expected = original
                .replacingOccurrences(of: "status: todo  ", with: "status: done  ")
                .replacingOccurrences(of: "updated: 2026-09-28T09:12:00+03:00", with: "updated: 2026-09-30T18:00:00+03:00")
                .replacingOccurrences(of: "done_at:                  #", with: "done_at: 2026-09-30T18:00:00+03:00 #")
            #expect(try read(root, "Tasks/Send invoice.md") == expected)
            #expect(await vault.index.entry(path: "Tasks/Send invoice.md")?.status == "done")
            #expect(saved.item.loadedDocument?.text == expected)
        }
    }

    @Test func aNewTitleRenamesTheFile() async throws {
        try await withVault { vault, root in
            try await vault.load()
            var task = try await vault.item(TaskItem.self, at: "Tasks/Send invoice.md")
            task.setTitle("Send the invoice: ACME")
            let saved = try await vault.save(task, at: "Tasks/Send invoice.md")
            #expect(saved.path == "Tasks/Send the invoice- ACME.md")
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Tasks/Send invoice.md").path))
            #expect(try read(root, saved.path).contains("title: \"Send the invoice: ACME\""))
            #expect(await vault.index.entry(path: "Tasks/Send invoice.md") == nil)
            #expect(await vault.index.entry(id: task.id)?.path == saved.path)
        }
    }

    @Test func newItemsGetCollisionSafeNames() async throws {
        try await withVault { vault, root in
            try await vault.load()
            let created = Timestamp("2026-10-01T08:00:00+03:00")!
            let duplicate = TaskItem.new(title: "Q4 invoicing", created: created)
            let saved = try await vault.save(duplicate, at: nil)
            #expect(saved.path == "Tasks/Q4 invoicing-2.md")

            // Saving it again with its own title keeps the -2 name.
            var again = saved.item
            again.setPriority(1)
            let resaved = try await vault.save(again, at: saved.path)
            #expect(resaved.path == "Tasks/Q4 invoicing-2.md")

            // The same item can't be created twice.
            await #expect(throws: VaultError.alreadyExists("Tasks/Q4 invoicing-2.md")) {
                try await vault.save(saved.item, at: nil)
            }
            let week = try await vault.save(HabitWeek.new(week: ISOWeek("2026-W41")!), at: nil)
            #expect(week.path == "Habits/Weeks/2026-W41.md")
            await #expect(throws: VaultError.alreadyExists("Habits/Weeks/2026-W40.md")) {
                try await vault.save(HabitWeek.new(week: ISOWeek("2026-W40")!), at: nil)
            }
        }
    }

    @Test func anEditElsewhereIsNeverOverwritten() async throws {
        try await withVault { vault, root in
            try await vault.load()
            var note = try await vault.item(Note.self, at: "Notes/Client note.md")
            // Obsidian edits the file meanwhile…
            let external = try read(root, "Notes/Client note.md") + "Added in Obsidian.\n"
            try write(root, "Notes/Client note.md", external)
            // …and the watcher has already caught up.
            try await vault.refresh(["Notes/Client note.md"])

            note.setTitle("Client note (ACME)")
            await #expect(throws: VaultError.changedOnDisk("Notes/Client note.md")) {
                try await vault.save(note, at: "Notes/Client note.md")
            }
            #expect(try read(root, "Notes/Client note.md") == external)
        }
    }

    @Test func categoriesAreCreatedOnlyWhenSaved() async throws {
        try await withVault(nil) { vault, root in
            try await vault.createSkeleton()
            try await vault.load()
            let none = try await vault.categories()
            #expect(none == nil)
            var categories = HabitCategories.new(budgets: [.physical: 150], nudgeTimes: [])
            categories = try await vault.save(categories)
            #expect(try read(root, "Habits/Categories.md").contains("physical: 150"))
            categories.setBudget(120, for: .physical)
            let saved = try await vault.save(categories)
            let reread = try await vault.categories()
            #expect(reread?.budgets == [.physical: 120])
            #expect(saved.loadedDocument == saved.document)
        }
    }

    // MARK: Refresh (watcher events)

    @Test func refreshFollowsExternalChanges() async throws {
        try await withVault { vault, root in
            try await vault.load()
            let text = try read(root, "Notes/Client note.md").replacingOccurrences(of: "title: Client note", with: "title: Customer note")
            try write(root, "Notes/Client note.md", text)
            try write(root, "Notes/Brand new.md", "---\nid: 01J9K3N0TE0000000000000009\ntype: note\ntitle: Brand new\n---\n")
            try FileManager.default.removeItem(at: root.appendingPathComponent("Tasks/Q4 invoicing.md"))

            let changed = try await vault.refresh(["Notes/Client note.md", "Notes/Brand new.md", "Tasks/Q4 invoicing.md", "Notes/Antenna notes.md"])
            #expect(changed == ["Notes/Client note.md", "Notes/Brand new.md", "Tasks/Q4 invoicing.md"])
            let index = await vault.index
            #expect(index.entry(path: "Notes/Client note.md")?.title == "Customer note")
            #expect(index.entry(path: "Notes/Brand new.md")?.title == "Brand new")
            #expect(index.entry(path: "Tasks/Q4 invoicing.md") == nil)
        }
    }

    @Test func pathsCannotLeaveTheVault() async throws {
        try await withVault { vault, _ in
            await #expect(throws: VaultError.invalidPath("../outside.md")) { try await vault.document(at: "../outside.md") }
            await #expect(throws: VaultError.invalidPath("/etc/hosts")) { try await vault.document(at: "/etc/hosts") }
            await #expect(throws: VaultError.notFound("Notes/Missing.md")) { try await vault.document(at: "Notes/Missing.md") }
        }
    }
}

@Suite("FileName")
struct FileNameTests {
    @Test(arguments: [
        ("Send invoice", "Send invoice"),
        ("Q4: plan / review", "Q4- plan - review"),
        ("  lots   of   space  ", "lots of space"),
        ("..hidden", "hidden"),
        ("Çalışma planı ☀️", "Çalışma planı ☀️"),
        ("[[Link]] #tag", "--Link-- -tag"),
        ("", "Untitled"),
        ("///", "---"),
        ("line\nbreak", "line-break"),
    ])
    func slugs(_ title: String, _ expected: String) {
        #expect(FileName.slug(title) == expected)
    }

    @Test func longTitlesAreCutOnACharacterBoundary() {
        let slug = FileName.slug(String(repeating: "ş", count: 300))
        #expect(slug.utf8.count <= FileName.maxBytes)
        #expect(slug.allSatisfy { $0 == "ş" })
    }

    @Test func collisionsIgnoreCaseAndNormalisation() {
        #expect(FileName.available(for: "Plan", taken: []) == "Plan.md")
        #expect(FileName.available(for: "Plan", taken: ["plan.md"]) == "Plan-2.md")
        #expect(FileName.available(for: "Plan", taken: ["Plan.md", "Plan-2.md"]) == "Plan-3.md")
        // é precomposed vs e + combining accent: the same name on APFS.
        #expect(FileName.available(for: "Caf\u{E9}", taken: ["Cafe\u{301}.md"]) == "Caf\u{E9}-2.md")
    }

    @Test func matchesKeepsNumberedNames() {
        #expect(FileName.matches("Send invoice.md", title: "Send invoice"))
        #expect(FileName.matches("send INVOICE-3.md", title: "Send invoice"))
        #expect(!FileName.matches("Send invoice-1.md", title: "Send invoice"))
        #expect(!FileName.matches("Send invoice-x.md", title: "Send invoice"))
        #expect(!FileName.matches("Send.md", title: "Send invoice"))
    }
}
