import Foundation

/// Remembers the vault folder the owner chose, as a security-scoped bookmark (P2, B02).
///
/// Stored in the app's own defaults. The debug build is a different bundle id, so it has its own
/// defaults and its own bookmark — a debug run can never change which vault the real app opens (§8.6).
struct VaultBookmarkStore {
    static let key = "vaultBookmark"

    let defaults: UserDefaults
    var makeBookmark: (URL) throws -> Data = { url in
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }
    var resolveBookmark: (Data) throws -> (url: URL, isStale: Bool) = { data in
        var isStale = false
        let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
        return (url, isStale)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func save(_ url: URL) throws {
        defaults.set(try makeBookmark(url), forKey: Self.key)
    }

    /// The remembered folder, or nil. A stale bookmark (the folder moved) is renewed while it still resolves.
    func load() -> URL? {
        guard let data = defaults.data(forKey: Self.key), let resolved = try? resolveBookmark(data) else { return nil }
        if resolved.isStale { try? save(resolved.url) }
        return resolved.url
    }

    func clear() {
        defaults.removeObject(forKey: Self.key)
    }
}
