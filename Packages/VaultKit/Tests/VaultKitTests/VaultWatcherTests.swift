import Foundation
import Testing
@testable import VaultKit

@Suite("VaultWatcher", .serialized)
struct VaultWatcherTests {
    /// Collects every batch from one long-lived consumer. (Cancelling a task that iterates an
    /// AsyncStream ends the stream, so tests must not time out an iteration directly.)
    actor Collector {
        private(set) var seen = Set<String>()
        private(set) var batches = 0

        func add(_ batch: Set<String>) {
            seen.formUnion(batch)
            batches += 1
        }

        func reset() {
            seen = []
            batches = 0
        }
    }

    func consume(_ stream: AsyncStream<Set<String>>) -> (Collector, Task<Void, Never>) {
        let collector = Collector()
        let task = Task { for await batch in stream { await collector.add(batch) } }
        return (collector, task)
    }

    /// Waits until `collector` has seen `paths`; returns how long it took, or nil after `timeout`.
    func wait(for paths: Set<String>, in collector: Collector, within timeout: Duration) async -> Duration? {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < timeout {
            if await collector.seen.isSuperset(of: paths) { return ContinuousClock.now - start }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return nil
    }

    @Test func externalEditsReachTheIndexWithinOneSecond() async throws {
        let root = try Fixtures.copyVault("Basic")
        defer { Fixtures.removeCopy(root) }
        let vault = try Vault(root: root)
        try await vault.load()
        let watcher = VaultWatcher(vault: vault, interval: .milliseconds(250))
        let (collector, consumer) = consume(await watcher.start())

        // An idle vault reports nothing.
        try await Task.sleep(for: .milliseconds(600))
        #expect(await collector.batches == 0)

        let noteURL = root.appendingPathComponent("Notes/Client note.md")
        let text = try #require(String(validating: Data(contentsOf: noteURL), as: UTF8.self))
        try Data(text.replacingOccurrences(of: "title: Client note", with: "title: Customer note").utf8).write(to: noteURL)
        let latency = await wait(for: ["Notes/Client note.md"], in: collector, within: .seconds(1))
        #expect(latency != nil, "an external edit must be visible within one second")
        #expect(await vault.index.entry(path: "Notes/Client note.md")?.title == "Customer note")

        await collector.reset()
        try Data("---\nid: 01J9K3N0TE0000000000000009\ntype: note\ntitle: Fresh\n---\n".utf8)
            .write(to: root.appendingPathComponent("Notes/Fresh.md"))
        try FileManager.default.removeItem(at: root.appendingPathComponent("Tasks/Q4 invoicing.md"))
        #expect(await wait(for: ["Notes/Fresh.md", "Tasks/Q4 invoicing.md"], in: collector, within: .seconds(1)) != nil)
        #expect(await collector.seen == ["Notes/Fresh.md", "Tasks/Q4 invoicing.md"])
        #expect(await vault.index.entry(path: "Tasks/Q4 invoicing.md") == nil)
        consumer.cancel()
        await watcher.stop()
    }

    @Test func nudgesRefreshImmediately() async throws {
        let root = try Fixtures.copyVault("Basic")
        defer { Fixtures.removeCopy(root) }
        let vault = try Vault(root: root)
        try await vault.load()
        let watcher = VaultWatcher(vault: vault, interval: .seconds(60)) // polling effectively off
        let (collector, consumer) = consume(await watcher.start())

        try FileManager.default.removeItem(at: root.appendingPathComponent("Habits/Piano.md"))
        await watcher.nudge(["Habits/Piano.md"])
        #expect(await wait(for: ["Habits/Piano.md"], in: collector, within: .milliseconds(500)) != nil)
        consumer.cancel()
        await watcher.stop()
    }

    @Test func rescanIsIncremental() async throws {
        let root = try Fixtures.copyVault("Basic")
        defer { Fixtures.removeCopy(root) }
        let vault = try Vault(root: root)
        try await vault.load()
        let idle = try await vault.rescan()
        #expect(idle.isEmpty)
        try Data("---\ntitle: Touched\n---\n".utf8).write(to: root.appendingPathComponent("Notes/Plain note.md"))
        let changed = try await vault.rescan()
        #expect(changed == ["Notes/Plain note.md"])
        #expect(await vault.index.entry(path: "Notes/Plain note.md")?.title == "Touched")
    }
}
