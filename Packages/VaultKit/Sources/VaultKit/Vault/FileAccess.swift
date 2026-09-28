import Foundation

/// One Markdown file found in the vault.
public struct FileInfo: Equatable, Sendable {
    /// Vault-relative path with `/` separators.
    public let path: String
    public let modified: Date?
    public let size: Int?
    /// An iCloud file whose contents are not on this Mac yet (evicted, or a `.Name.md.icloud` stub).
    public let isPlaceholder: Bool
}

/// Every byte the app reads or writes in a vault goes through this (§8.3, A05).
public protocol FileAccess: Sendable {
    func read(_ url: URL) throws -> Data
    /// Atomic replace.
    func write(_ data: Data, to url: URL) throws
    /// Compare-and-write in one coordinated access: writes `data` only if the file's bytes are still
    /// `expected` (`nil`: only if no file exists). Returns false, writing nothing, when they aren't —
    /// so an edit made elsewhere between reading and writing can never be overwritten.
    func write(_ data: Data, to url: URL, ifCurrentContentsAre expected: Data?) throws -> Bool
    func move(from source: URL, to destination: URL) throws
    func createDirectory(at url: URL) throws
    func fileExists(at url: URL) -> Bool
    func isDirectory(at url: URL) -> Bool
    func attributes(of url: URL) -> (modified: Date?, size: Int?)
    /// File and folder names directly inside `directory`; empty if it does not exist.
    func names(in directory: URL) -> [String]
    /// All `.md` files under `root`, skipping dot-folders (`.persona`, `.obsidian`, `.trash`, `.git`) and
    /// dot-files, except iCloud `.Name.md.icloud` stubs, which are reported as placeholders for `Name.md`.
    func markdownFiles(in root: URL) throws -> [FileInfo]
    /// Asks iCloud to bring an evicted file back. The watcher sees it arrive.
    func startDownloading(_ url: URL) throws
}

/// File access coordinated with `NSFileCoordinator`, so the app never races the iCloud sync daemon,
/// Obsidian or any other coordinated writer (A05). On platforms without file coordination (the Linux
/// toolchain the agents test with — B02) the same operations run directly.
public struct CoordinatedFileAccess: FileAccess {
    public init() {}

    public func read(_ url: URL) throws -> Data {
        #if canImport(Darwin)
            var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
            var coordinationError: NSError?
            NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
                result = Result { try Data(contentsOf: url) }
            }
            if let coordinationError { throw coordinationError }
            return try result.get()
        #else
            return try Data(contentsOf: url)
        #endif
    }

    public func write(_ data: Data, to url: URL) throws {
        #if canImport(Darwin)
            var result: Result<Void, Error> = .success(())
            var coordinationError: NSError?
            NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
                result = Result { try data.write(to: url, options: .atomic) }
            }
            if let coordinationError { throw coordinationError }
            try result.get()
        #else
            try data.write(to: url, options: .atomic)
        #endif
    }

    public func write(_ data: Data, to url: URL, ifCurrentContentsAre expected: Data?) throws -> Bool {
        #if canImport(Darwin)
            var result: Result<Bool, Error> = .success(false)
            var coordinationError: NSError?
            NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
                result = Result { try Self.compareAndWrite(data, to: url, expected: expected) }
            }
            if let coordinationError { throw coordinationError }
            return try result.get()
        #else
            return try Self.compareAndWrite(data, to: url, expected: expected)
        #endif
    }

    private static func compareAndWrite(_ data: Data, to url: URL, expected: Data?) throws -> Bool {
        guard let expected else {
            guard !FileManager.default.fileExists(atPath: url.path) else { return false }
            do {
                try data.write(to: url, options: .withoutOverwriting)
            } catch CocoaError.fileWriteFileExists {
                return false
            }
            return true
        }
        guard (try? Data(contentsOf: url)) == expected else { return false }
        try data.write(to: url, options: .atomic)
        return true
    }

    public func move(from source: URL, to destination: URL) throws {
        #if canImport(Darwin)
            var result: Result<Void, Error> = .success(())
            var coordinationError: NSError?
            let coordinator = NSFileCoordinator(filePresenter: nil)
            coordinator.coordinate(
                writingItemAt: source, options: .forMoving,
                writingItemAt: destination, options: .forReplacing,
                error: &coordinationError
            ) { from, to in
                result = Result {
                    coordinator.item(at: from, willMoveTo: to)
                    try FileManager.default.moveItem(at: from, to: to)
                    coordinator.item(at: from, didMoveTo: to)
                }
            }
            if let coordinationError { throw coordinationError }
            try result.get()
        #else
            try FileManager.default.moveItem(at: source, to: destination)
        #endif
    }

    public func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    public func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    public func isDirectory(at url: URL) -> Bool {
        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    public func attributes(of url: URL) -> (modified: Date?, size: Int?) {
        let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey])
        return (values?.contentModificationDate, values?.fileSize)
    }

    public func names(in directory: URL) -> [String] {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        // An evicted iCloud file `.X.md.icloud` still owns the name `X.md`.
        return names.map { $0.hasPrefix(".") && $0.hasSuffix(".icloud") ? String($0.dropFirst().dropLast(".icloud".count)) : $0 }
    }

    public func markdownFiles(in root: URL) throws -> [FileInfo] {
        var keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .contentModificationDateKey, .fileSizeKey]
        #if canImport(Darwin)
            keys.append(.ubiquitousItemDownloadingStatusKey)
        #endif
        let base = root.resolvingSymlinksInPath().standardizedFileURL.path
        guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        var files: [FileInfo] = []
        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isSymbolicLink == true { continue }
            if values?.isDirectory == true {
                if name.hasPrefix(".") { enumerator.skipDescendants() }
                continue
            }
            let fullPath = url.resolvingSymlinksInPath().standardizedFileURL.path
            guard fullPath.hasPrefix(base + "/") else { continue }
            let relative = String(fullPath.dropFirst(base.count + 1))
            if name.hasPrefix("."), name.hasSuffix(".md.icloud") {
                // `.Send invoice.md.icloud` stands for `Send invoice.md`.
                let realName = String(name.dropFirst().dropLast(".icloud".count))
                let folder = relative.split(separator: "/").dropLast().joined(separator: "/")
                files.append(FileInfo(path: folder.isEmpty ? realName : folder + "/" + realName, modified: nil, size: nil, isPlaceholder: true))
                continue
            }
            guard !name.hasPrefix("."), name.lowercased().hasSuffix(".md") else { continue }
            var isPlaceholder = false
            #if canImport(Darwin)
                isPlaceholder = values?.ubiquitousItemDownloadingStatus == .notDownloaded
            #endif
            files.append(FileInfo(path: relative, modified: values?.contentModificationDate, size: values?.fileSize, isPlaceholder: isPlaceholder))
        }
        return files.sorted { $0.path < $1.path }
    }

    public func startDownloading(_ url: URL) throws {
        #if canImport(Darwin)
            try FileManager.default.startDownloadingUbiquitousItem(at: url)
        #endif
    }
}

/// Wraps another `FileAccess` and refuses every write — for inspecting folders (`vaultctl`).
struct ReadOnlyFileAccess: FileAccess {
    let base: any FileAccess

    func read(_ url: URL) throws -> Data { try base.read(url) }
    func write(_ data: Data, to url: URL) throws { throw VaultError.readOnly }
    func write(_ data: Data, to url: URL, ifCurrentContentsAre expected: Data?) throws -> Bool { throw VaultError.readOnly }
    func move(from source: URL, to destination: URL) throws { throw VaultError.readOnly }
    func createDirectory(at url: URL) throws { throw VaultError.readOnly }
    func fileExists(at url: URL) -> Bool { base.fileExists(at: url) }
    func isDirectory(at url: URL) -> Bool { base.isDirectory(at: url) }
    func attributes(of url: URL) -> (modified: Date?, size: Int?) { base.attributes(of: url) }
    func names(in directory: URL) -> [String] { base.names(in: directory) }
    func markdownFiles(in root: URL) throws -> [FileInfo] { try base.markdownFiles(in: root) }
    /// Downloading an evicted iCloud file changes nothing the owner can see, but it is still not ours to ask.
    func startDownloading(_ url: URL) throws {}
}
