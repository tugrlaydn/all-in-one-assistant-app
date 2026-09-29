import Foundation
import Testing
@testable import Persona

/// Runs inside the sandboxed debug app: every folder is created in its own temp directory (§8.6),
/// and bookmarks go to a throwaway defaults suite, never the app's real defaults.
@MainActor
@Suite("VaultSession", .serialized)
struct VaultSessionTests {
    func makeFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("persona-app-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Plain bookmarks: security scope needs a folder the owner picked, which a test can't do.
    func makeBookmarks() -> (VaultBookmarkStore, String) {
        let suite = "persona.tests.\(UUID().uuidString)"
        var store = VaultBookmarkStore(defaults: UserDefaults(suiteName: suite)!)
        store.makeBookmark = { try $0.bookmarkData() }
        store.resolveBookmark = { data in
            var stale = false
            let url = try URL(resolvingBookmarkData: data, bookmarkDataIsStale: &stale)
            return (url, stale)
        }
        return (store, suite)
    }

    func waitUntil(_ condition: @MainActor () -> Bool, within timeout: Duration = .seconds(3)) async -> Bool {
        let start = ContinuousClock.now
        while ContinuousClock.now - start < timeout {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(25))
        }
        return condition()
    }

    @Test func relativePathsFromFSEvents() {
        #expect(FolderEvents.relative("/v/Notes/A.md", to: "/v") == "Notes/A.md")
        #expect(FolderEvents.relative("/v/Notes/A.md", to: "/v/") == "Notes/A.md")
        #expect(FolderEvents.relative("/v", to: "/v") == nil)
        #expect(FolderEvents.relative("/vault2/A.md", to: "/v") == nil)
    }

    @Test func bookmarksRoundTrip() throws {
        let folder = try makeFolder()
        let (store, suite) = makeBookmarks()
        defer {
            UserDefaults().removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        #expect(store.load() == nil)
        try store.save(folder)
        #expect(store.load()?.standardizedFileURL.path == folder.standardizedFileURL.path)
        store.clear()
        #expect(store.load() == nil)
    }

    @Test func openingCreatesTheSkeletonRemembersTheFolderAndFollowsEdits() async throws {
        let folder = try makeFolder()
        let (store, suite) = makeBookmarks()
        defer {
            UserDefaults().removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        let session = VaultSession(launch: LaunchOptions(arguments: [], allowsTestVault: true), bookmarks: store)
        await session.openOnLaunch()
        #expect(session.state == .noVault)

        await session.open(folder, remember: true)
        #expect(session.state == .open(folder))
        for name in ["Notes", "Tasks", "Habits", "Habits/Weeks", "Attachments", ".persona"] {
            #expect(FileManager.default.fileExists(atPath: folder.appendingPathComponent(name).path), "\(name)")
        }
        #expect(session.index.count == 0) // folders only: never sample data

        // An edit made outside the app shows up quickly (FSEvents; polling is only every 10 s).
        let note = "---\nid: 01J9K3N0TE0000000000000001\ntype: note\ntitle: From outside\n---\n"
        try Data(note.utf8).write(to: folder.appendingPathComponent("Notes/From outside.md"))
        #expect(await waitUntil { session.index.count == 1 }, "FSEvents should deliver within a few seconds")
        #expect(session.index.entries(titled: "From outside").count == 1)

        // A new session (next launch) reopens the remembered folder.
        session.close()
        let next = VaultSession(launch: LaunchOptions(arguments: [], allowsTestVault: true), bookmarks: store)
        await next.openOnLaunch()
        #expect(next.openURL?.standardizedFileURL.path == folder.standardizedFileURL.path)
        #expect(next.index.count == 1)
        next.close()
    }

    @Test func aTestVaultIsNeverRemembered() async throws {
        let folder = try makeFolder()
        let (store, suite) = makeBookmarks()
        defer {
            UserDefaults().removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: folder)
        }
        let launch = LaunchOptions(arguments: ["Persona", "--vault", folder.path], allowsTestVault: true)
        let session = VaultSession(launch: launch, bookmarks: store)
        await session.openOnLaunch()
        #expect(session.openURL != nil)
        await session.open(folder, remember: true)
        #expect(store.load() == nil, "a test vault must never become the remembered vault (§8.6)")
        session.close()
    }

    @Test func aMissingFolderFailsCleanly() async {
        let (store, suite) = makeBookmarks()
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        let session = VaultSession(launch: LaunchOptions(arguments: [], allowsTestVault: true), bookmarks: store)
        await session.open(URL(fileURLWithPath: "/nonexistent-\(UUID().uuidString)"), remember: true)
        guard case .failed = session.state else {
            Issue.record("expected .failed, got \(session.state)")
            return
        }
        #expect(store.load() == nil)
    }
}
