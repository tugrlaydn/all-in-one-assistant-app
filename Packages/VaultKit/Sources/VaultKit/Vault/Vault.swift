import Foundation

public enum VaultError: Error, Equatable, Sendable {
    case notAFolder(String)
    case invalidPath(String)
    case notFound(String)
    /// The file is not valid UTF-8; the app leaves it alone.
    case notUTF8(String)
    /// The file isn't the kind of item asked for (or has no valid id).
    case wrongKind(String)
    /// Someone else changed the file since it was read; reload before saving.
    case changedOnDisk(String)
    case alreadyExists(String)
    /// The vault was opened read-only (`vaultctl`): nothing may be written.
    case readOnly
    /// `load()` must run before creating items, so a duplicate id can be detected.
    case notLoaded
}

/// The result of a save: where the file is now and the item as written.
public struct Saved<T: VaultItem>: Sendable {
    public let path: String
    public let item: T
}

/// What `load` did.
public struct LoadReport: Equatable, Sendable {
    public var indexed = 0
    public var fromCache = 0
    public var parsed = 0
    /// Evicted iCloud files; a download was requested and the watcher will index them on arrival.
    public var placeholders: [String] = []
    public var unreadable: [String] = []
}

/// A vault folder (A05): the only door to the owner's files. Reads, writes and renames go through
/// `FileAccess` (coordinated), the index follows every change, and nothing is ever written that the
/// owner did not change (§8.3).
public actor Vault {
    public nonisolated let root: URL
    /// Opened for inspection only: no file, folder or cache is ever written.
    public nonisolated let isReadOnly: Bool
    let files: any FileAccess
    public private(set) var index = VaultIndex()

    /// FORMAT §4.1. Only folders: the owner's vault starts empty, never with sample files (D10, §8.6).
    public static let skeleton = ["Notes", "Tasks", "Habits", "Habits/Weeks", "Attachments", ".persona"]

    public init(root: URL, files: any FileAccess = CoordinatedFileAccess(), readOnly: Bool = false) throws {
        guard files.isDirectory(at: root) else { throw VaultError.notAFolder(root.path) }
        self.root = root.standardizedFileURL
        isReadOnly = readOnly
        self.files = readOnly ? ReadOnlyFileAccess(base: files) : files
    }

    /// Creates the skeleton folders that are missing; returns the ones it created.
    @discardableResult
    public func createSkeleton() throws -> [String] {
        var created: [String] = []
        for folder in Self.skeleton {
            let folderURL = try url(folder)
            guard !files.isDirectory(at: folderURL) else { continue }
            try files.createDirectory(at: folderURL)
            created.append(folder)
        }
        return created
    }

    // MARK: Loading

    /// Builds the index from the files. Cached entries are reused only when a file's modification
    /// date and size are unchanged; `useCache: false` is the full rebuild.
    @discardableResult
    public func load(useCache: Bool = true) throws -> LoadReport {
        let listing = try files.markdownFiles(in: root)
        let cached = useCache ? readCache() : [:]
        var report = LoadReport()
        var newIndex = VaultIndex()
        for info in listing {
            if info.isPlaceholder {
                report.placeholders.append(info.path)
                try? files.startDownloading(try url(info.path))
                if let old = cached[info.path] { newIndex.upsert(old) } // keep showing it meanwhile
                continue
            }
            if let old = cached[info.path], Self.sameStamp(old, modified: info.modified, size: info.size) {
                newIndex.upsert(old)
                report.fromCache += 1
                continue
            }
            do {
                newIndex.upsert(try readEntry(info.path))
                report.parsed += 1
            } catch VaultError.notUTF8 {
                report.unreadable.append(info.path)
            }
        }
        index = newIndex
        isLoaded = true
        report.indexed = newIndex.count
        try writeCache()
        return report
    }

    /// Re-reads the given paths (watcher events): changed files are re-indexed, vanished ones removed.
    /// Returns the paths whose index entry changed.
    @discardableResult
    public func refresh(_ paths: Set<String>) throws -> Set<String> {
        var changed = Set<String>()
        for path in paths where Self.isIndexable(path) {
            let fileURL = try url(path)
            guard files.fileExists(at: fileURL) else {
                if index.entry(path: path) != nil {
                    index.remove(path: path)
                    changed.insert(path)
                }
                continue
            }
            let stamp = files.attributes(of: fileURL)
            if let old = index.entry(path: path), Self.sameStamp(old, modified: stamp.modified, size: stamp.size) { continue }
            guard let entry = try? readEntry(path) else { continue }
            if index.entry(path: path) != entry {
                index.upsert(entry)
                changed.insert(path)
            }
        }
        return changed
    }

    /// Reconciles the index with the folder: new and changed files (by modification date and size)
    /// are re-read, vanished ones dropped, evicted iCloud files asked to download once. Returns the
    /// paths whose entry changed; an idle vault costs one directory listing.
    @discardableResult
    public func rescan() throws -> Set<String> {
        let listing = try files.markdownFiles(in: root)
        var seen = Set<String>()
        var changed = Set<String>()
        for info in listing {
            seen.insert(info.path)
            if info.isPlaceholder {
                if requestedDownloads.insert(info.path).inserted { try? files.startDownloading(try url(info.path)) }
                continue
            }
            requestedDownloads.remove(info.path)
            if let old = index.entry(path: info.path), Self.sameStamp(old, modified: info.modified, size: info.size) { continue }
            guard let entry = try? readEntry(info.path) else { continue }
            if index.entry(path: info.path) != entry {
                index.upsert(entry)
                changed.insert(info.path)
            }
        }
        for path in index.entries.keys where !seen.contains(path) {
            index.remove(path: path)
            changed.insert(path)
        }
        // No cache write here: rescan runs on the watcher's tick, and nothing is written on a timer
        // (§8.3). The next load reconciles a stale cache by date and size anyway.
        return changed
    }

    private var requestedDownloads = Set<String>()
    private var isLoaded = false

    /// What the folder scan indexes: `.md` files outside dot-folders, not dot-files.
    static func isIndexable(_ path: String) -> Bool {
        path.lowercased().hasSuffix(".md") && !path.split(separator: "/").contains { $0.hasPrefix(".") }
    }

    // MARK: Reading

    public func document(at path: String) throws -> MarkdownDocument {
        let fileURL = try url(path)
        guard files.fileExists(at: fileURL) else { throw VaultError.notFound(path) }
        guard let document = MarkdownDocument(data: try files.read(fileURL)) else { throw VaultError.notUTF8(path) }
        return document
    }

    public func item<T: VaultItem>(_ type: T.Type, at path: String) throws -> T {
        guard let item = T(document: try document(at: path)) else { throw VaultError.wrongKind(path) }
        return item
    }

    public func categories() throws -> HabitCategories? {
        let path = "Habits/" + HabitCategories.fileName
        guard files.fileExists(at: try url(path)) else { return nil }
        guard let categories = HabitCategories(document: try document(at: path)) else { throw VaultError.wrongKind(path) }
        return categories
    }

    // MARK: Saving — only on a user action, never on a timer (§8.3)

    /// Saves an item. `path == nil` creates a new file named after the title (FORMAT §4.1).
    /// An unchanged item is not written; a changed title renames the file. Throws `changedOnDisk`
    /// when the file no longer matches what the item was loaded from — someone else edited it.
    /// Returns the path and the item as saved (its new `loadedDocument`) for the next edit.
    @discardableResult
    public func save<T: VaultItem>(_ item: T, at path: String?, now: Timestamp = .now()) throws -> Saved<T> {
        guard let path else {
            // A second file with the same id would split the item in two — which only the index can tell.
            guard isLoaded else { throw VaultError.notLoaded }
            if let existing = index.entry(id: item.id) { throw VaultError.alreadyExists(existing.path) }
            let created = try create(item.document, kind: T.kind, title: item.title)
            return Saved(path: created, item: T(document: item.document)!)
        }

        let fileURL = try url(path)
        guard files.fileExists(at: fileURL) else { throw VaultError.notFound(path) }
        if try files.read(fileURL) == item.document.data { return Saved(path: path, item: T(document: item.document)!) }
        guard let loaded = item.loadedDocument else { throw VaultError.changedOnDisk(path) }

        var document = item.document
        if T.kind == .note || T.kind == .task {
            var frontMatter = document.frontMatter ?? FrontMatter()
            frontMatter.set("updated", .scalar(now.description), as: .literal)
            document.frontMatter = frontMatter
        }
        // Compare and write in one coordinated access: an edit made elsewhere since loading wins.
        guard try files.write(document.data, to: fileURL, ifCurrentContentsAre: loaded.data) else {
            throw VaultError.changedOnDisk(path)
        }

        // Rename only when the title itself changed — a file the owner named differently keeps its name.
        var target = path
        let fileName = String(path.split(separator: "/").last ?? "")
        let loadedTitle = T(document: loaded)?.title
        if T.kind != .habitWeek, !item.title.isEmpty, item.title != loadedTitle, !FileName.matches(fileName, title: item.title) {
            let folder = String(path.dropLast(fileName.count))
            let taken = Set(files.names(in: try url(folder.isEmpty ? "." : folder))).subtracting([fileName])
            let renamed = folder + FileName.available(for: item.title, taken: taken)
            // A failed rename leaves the saved file under its old name — nothing is lost.
            if (try? files.move(from: fileURL, to: try url(renamed))) != nil { target = renamed }
        }
        index.remove(path: path)
        index.upsert(try readEntry(target))
        try writeCache()
        return Saved(path: target, item: T(document: document)!)
    }

    /// Saves `Habits/Categories.md`, creating it on the owner's first budget (never as sample data).
    @discardableResult
    public func save(_ categories: HabitCategories) throws -> HabitCategories {
        let path = "Habits/" + HabitCategories.fileName
        let fileURL = try url(path)
        let exists = files.fileExists(at: fileURL)
        if exists, try files.read(fileURL) == categories.document.data { return HabitCategories(document: categories.document)! }
        if !exists { try files.createDirectory(at: try url("Habits")) }
        // nil loadedDocument = a new file: only written if none exists.
        guard try files.write(categories.document.data, to: fileURL, ifCurrentContentsAre: categories.loadedDocument?.data) else {
            throw VaultError.changedOnDisk(path)
        }
        index.upsert(try readEntry(path))
        try writeCache()
        return HabitCategories(document: categories.document)!
    }

    private func create(_ document: MarkdownDocument, kind: ItemKind, title: String) throws -> String {
        let folder = Self.folder(for: kind)
        try files.createDirectory(at: try url(folder))
        let name = kind == .habitWeek
            ? title + ".md"
            : FileName.available(for: title, taken: Set(files.names(in: try url(folder))))
        let path = folder + "/" + name
        // Never over an existing file, even one that appeared a moment ago.
        guard try files.write(document.data, to: try url(path), ifCurrentContentsAre: nil) else {
            throw VaultError.alreadyExists(path)
        }
        index.upsert(try readEntry(path))
        try writeCache()
        return path
    }

    static func folder(for kind: ItemKind) -> String {
        switch kind {
        case .note: "Notes"
        case .task: "Tasks"
        case .habit, .habitCategories: "Habits"
        case .habitWeek: "Habits/Weeks"
        }
    }

    // MARK: Cache

    private func readCache() -> [String: IndexEntry] {
        guard let cacheURL = try? url(IndexCache.path), files.fileExists(at: cacheURL),
              let data = try? files.read(cacheURL), let cache = IndexCache.decode(data)
        else { return [:] }
        return Dictionary(cache.entries.map { ($0.path, $0) }, uniquingKeysWith: { first, _ in first })
    }

    /// Writes `.persona/index.json` only when its contents change — no churn for iCloud to sync.
    public func writeCache() throws {
        guard !isReadOnly else { return }
        let cacheURL = try url(IndexCache.path)
        let data = try IndexCache(index: index).encoded()
        if files.fileExists(at: cacheURL), (try? files.read(cacheURL)) == data { return }
        try files.createDirectory(at: cacheURL.deletingLastPathComponent())
        try files.write(data, to: cacheURL)
    }

    // MARK: Paths

    private func readEntry(_ path: String) throws -> IndexEntry {
        let fileURL = try url(path)
        let stamp = files.attributes(of: fileURL)
        guard let document = MarkdownDocument(data: try files.read(fileURL)) else { throw VaultError.notUTF8(path) }
        return IndexEntry(path: path, document: document, modified: stamp.modified, size: stamp.size)
    }

    /// A vault-relative path as a URL. Absolute paths and `..` are refused: nothing outside the vault.
    func url(_ path: String) throws -> URL {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard !path.hasPrefix("/"), !parts.contains(".."), !parts.contains(where: { $0.contains("\\") }) else {
            throw VaultError.invalidPath(path)
        }
        return parts.reduce(root) { $0.appendingPathComponent(String($1)) }
    }

    static func sameStamp(_ entry: IndexEntry, modified: Date?, size: Int?) -> Bool {
        guard let old = entry.modified, let new = modified, entry.size == size else { return false }
        return abs(old.timeIntervalSince(new)) < 0.001
    }
}
