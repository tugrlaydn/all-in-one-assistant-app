import Foundation

/// The in-memory index of a vault (A06): lookups by id, title, tag and link, backlinks, the
/// day → items map for the Horizon, and fuzzy title search. Never the truth — the files are; the
/// index is rebuilt from them at any time, and updated one file at a time by the watcher.
public struct VaultIndex: Sendable, Equatable {
    public private(set) var entries: [String: IndexEntry] = [:]

    private var byID: [ULID: String] = [:]
    private var byTitle: [String: Set<String>] = [:]
    private var byTag: [String: Set<String>] = [:]
    /// Link-target key → paths linking to it (including `parent:`).
    private var linksTo: [String: Set<String>] = [:]
    private var byDay: [Day: Set<String>] = [:]

    public init(entries: [IndexEntry] = []) {
        for entry in entries { upsert(entry) }
    }

    public var count: Int { entries.count }

    // MARK: Updating

    /// Adds or replaces the entry for `entry.path`.
    public mutating func upsert(_ entry: IndexEntry) {
        remove(path: entry.path)
        entries[entry.path] = entry
        if let id = entry.id { byID[id] = entry.path }
        byTitle[entry.titleKey, default: []].insert(entry.path)
        for tag in entry.tags { byTag[tag.lowercased(), default: []].insert(entry.path) }
        for target in Self.linkKeys(of: entry) { linksTo[target, default: []].insert(entry.path) }
        for day in entry.days { byDay[day, default: []].insert(entry.path) }
    }

    public mutating func remove(path: String) {
        guard let old = entries.removeValue(forKey: path) else { return }
        if let id = old.id, byID[id] == path { byID[id] = nil }
        Self.drop(path, from: old.titleKey, in: &byTitle)
        for tag in old.tags { Self.drop(path, from: tag.lowercased(), in: &byTag) }
        for target in Self.linkKeys(of: old) { Self.drop(path, from: target, in: &linksTo) }
        for day in old.days { Self.drop(path, from: day, in: &byDay) }
    }

    /// A file moved: same entry, new path.
    public mutating func move(from oldPath: String, to newPath: String, entry: IndexEntry) {
        remove(path: oldPath)
        upsert(entry)
    }

    private static func drop<Key: Hashable>(_ path: String, from key: Key, in map: inout [Key: Set<String>]) {
        map[key]?.remove(path)
        if map[key]?.isEmpty == true { map[key] = nil }
    }

    private static func linkKeys(of entry: IndexEntry) -> Set<String> {
        Set((entry.links + (entry.parent.map { [$0] } ?? [])).map(MarkdownText.titleKey))
    }

    // MARK: Lookups

    public func entry(path: String) -> IndexEntry? {
        entries[path]
    }

    public func entry(id: ULID) -> IndexEntry? {
        byID[id].flatMap { entries[$0] }
    }

    /// Case-insensitive; several files can share a title (in different folders). Sorted by path.
    public func entries(titled title: String) -> [IndexEntry] {
        sorted(byTitle[MarkdownText.titleKey(title)])
    }

    public func entries(tagged tag: String) -> [IndexEntry] {
        sorted(byTag[tag.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "#"))])
    }

    /// The file a `[[link]]` points to: by title (managed items first, then shortest path), then
    /// by the last path component (`[[Notes/Antenna notes]]`), then by id.
    public func resolve(_ link: WikiLink) -> IndexEntry? {
        let candidates = entries(titled: link.target)
        if let best = candidates.min(by: { Self.preference($0) < Self.preference($1) }) { return best }
        if let last = link.target.split(separator: "/").last, last.count < link.target.count {
            return entries(titled: String(last)).min { Self.preference($0) < Self.preference($1) }
        }
        return ULID(link.target).flatMap { entry(id: $0) }
    }

    private static func preference(_ entry: IndexEntry) -> (Int, Int, String) {
        (entry.kind == nil ? 1 : 0, entry.path.count, entry.path)
    }

    /// Everything linking to `path` by title, by last path component or by id. Sorted by path.
    public func backlinks(to path: String) -> [IndexEntry] {
        guard let target = entries[path] else { return [] }
        var keys: Set<String> = [target.titleKey, MarkdownText.titleKey(String(path.dropLast(path.hasSuffix(".md") ? 3 : 0)))]
        if let id = target.id { keys.insert(id.description.lowercased()) }
        let sources = keys.reduce(into: Set<String>()) { $0.formUnion(linksTo[$1] ?? []) }
        return sorted(sources.subtracting([path])).filter { source in
            // A title shared by several files: count the link only if it resolves here.
            (source.links + (source.parent.map { [$0] } ?? [])).contains { resolve(WikiLink($0))?.path == path }
        }
    }

    /// Outgoing links that resolve to a file, in order, without duplicates.
    public func outgoing(from path: String) -> [IndexEntry] {
        guard let entry = entries[path] else { return [] }
        var seen = Set<String>()
        return (entry.links + (entry.parent.map { [$0] } ?? [])).compactMap { resolve(WikiLink($0)) }
            .filter { $0.path != path && seen.insert($0.path).inserted }
    }

    /// Items on `day` in the Horizon, sorted by kind then title.
    public func items(on day: Day) -> [IndexEntry] {
        (byDay[day] ?? []).compactMap { entries[$0] }.sorted {
            ($0.kind.map { ItemKind.allCases.firstIndex(of: $0)! } ?? 99, $0.titleKey) <
                ($1.kind.map { ItemKind.allCases.firstIndex(of: $0)! } ?? 99, $1.titleKey)
        }
    }

    /// How many items sit on each day in `range` — the Horizon's density strip.
    public func density(in range: ClosedRange<Day>) -> [Day: Int] {
        var result: [Day: Int] = [:]
        for (day, paths) in byDay where range.contains(day) { result[day] = paths.count }
        return result
    }

    /// Fuzzy title search, best first. Empty query → nothing.
    public func search(_ query: String, kinds: Set<ItemKind>? = nil, limit: Int = 20) -> [IndexEntry] {
        let matcher = FuzzyMatcher(query)
        guard !matcher.isEmpty else { return [] }
        return entries.values
            .filter { entry in kinds.map { entry.kind.map($0.contains) ?? false } ?? true }
            .compactMap { entry in matcher.score(entry.title).map { (entry, $0) } }
            .sorted { ($1.1, $0.0.titleKey, $0.0.path) < ($0.1, $1.0.titleKey, $1.0.path) }
            .prefix(limit)
            .map(\.0)
    }

    private func sorted(_ paths: Set<String>?) -> [IndexEntry] {
        (paths ?? []).sorted().compactMap { entries[$0] }
    }
}

// MARK: - Cache

/// `.persona/index.json` — only makes the second launch faster; safe to delete at any time (A06).
public struct IndexCache: Codable, Sendable {
    public static let version = 1
    public static let path = ".persona/index.json"

    public let version: Int
    public let entries: [IndexEntry]

    public init(index: VaultIndex) {
        version = Self.version
        entries = index.entries.values.sorted { $0.path < $1.path }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    /// Nil for a cache from another version or an unreadable file: the caller rebuilds.
    public static func decode(_ data: Data) -> IndexCache? {
        guard let cache = try? JSONDecoder().decode(IndexCache.self, from: data), cache.version == version else { return nil }
        return cache
    }
}
