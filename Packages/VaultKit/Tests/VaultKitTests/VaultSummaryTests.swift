import Foundation
import Testing
@testable import VaultKit

@Suite("vaultctl summary and read-only vaults")
struct VaultSummaryTests {
    @Test func summarisesTheFixtureVaultWithoutWritingToIt() async throws {
        let root = Fixtures.url("Vaults/Basic")
        let before = Fixtures.files(inVault: "Basic")
        let vault = try Vault(root: root, readOnly: true)
        let report = try await vault.load()
        let summary = VaultSummary.render(index: await vault.index, report: report, root: "Basic")

        #expect(summary == """
        Vault: Basic
        Files: 9 (notes 2, tasks 2, habits 2, habit weeks 1, category files 1, unmanaged 1)
        Loaded: 9 parsed, 0 from cache, 0 in iCloud only, 0 unreadable
        Tasks: 1 todo, 1 doing, 0 done, 0 dropped
        Tags: #work (3), #capsule (1), #clients (1), #inline-tag (1), #rf (1)
        Unresolved links: none
        Days with items: 4
          2026-09-28  Antenna notes (note), 2026-W40 (habit-week)
          2026-09-29  Client note (note), 2026-W40 (habit-week)
          2026-09-30  Send invoice (task)
          2026-10-31  Q4 invoicing (task)

        """)
        // Read-only means read-only: no cache, no folders, nothing new in the fixture.
        #expect(Fixtures.files(inVault: "Basic") == before)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(".persona").path))
    }

    @Test func aReadOnlyVaultRefusesEveryWrite() async throws {
        let root = try Fixtures.copyVault("Basic")
        defer { Fixtures.removeCopy(root) }
        let vault = try Vault(root: root, readOnly: true)
        try await vault.load()
        var task = try await vault.item(TaskItem.self, at: "Tasks/Send invoice.md")
        task.setPriority(1)
        await #expect(throws: VaultError.readOnly) { try await vault.save(task, at: "Tasks/Send invoice.md") }
        await #expect(throws: VaultError.readOnly) { try await vault.save(Note.new(title: "New"), at: nil) }
        await #expect(throws: VaultError.readOnly) { try await vault.createSkeleton() }
    }

    @Test func unresolvedLinksAreListed() {
        var index = VaultIndex()
        index.upsert(IndexEntry(path: "Notes/A.md", document: MarkdownDocument(parsing: "See [[Nowhere]].")))
        let summary = VaultSummary.render(index: index, report: LoadReport(), root: "x")
        #expect(summary.contains("Unresolved links: 1\n  [[Nowhere]] in Notes/A.md\n"))
    }
}
