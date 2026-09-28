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
        (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
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
