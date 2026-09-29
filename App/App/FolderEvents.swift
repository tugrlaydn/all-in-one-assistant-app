import CoreServices
import Foundation

/// FSEvents for one folder (B03): reports the vault-relative paths that changed, usually within a fraction
/// of a second. VaultKit stays Foundation-only; this lives in the app and feeds `VaultWatcher.nudge`.
final class FolderEvents: @unchecked Sendable {
    let rootPath: String
    private let onChange: @Sendable (Set<String>) -> Void
    private let queue = DispatchQueue(label: "persona.folder-events")
    private var stream: FSEventStreamRef?

    init(root: URL, onChange: @escaping @Sendable (Set<String>) -> Void) {
        rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        self.onChange = onChange
    }

    deinit {
        stop()
    }

    /// Starts the stream; false if FSEvents refused (the watcher's polling still covers the folder).
    @discardableResult
    func start() -> Bool {
        guard stream == nil else { return true }
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(), retain: nil, release: nil, copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, _, eventPaths, _, _ in
            guard let info else { return }
            let events = Unmanaged<FolderEvents>.fromOpaque(info).takeUnretainedValue()
            let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] ?? []
            events.deliver(paths)
        }
        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer
        )
        guard let stream = FSEventStreamCreate(
            nil, callback, &context, [rootPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.2, flags
        ) else { return false }
        FSEventStreamSetDispatchQueue(stream, queue)
        guard FSEventStreamStart(stream) else {
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            return false
        }
        self.stream = stream
        return true
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    private func deliver(_ absolutePaths: [String]) {
        let paths = Set(absolutePaths.compactMap { Self.relative($0, to: rootPath) })
        if !paths.isEmpty { onChange(paths) }
    }

    /// `/…/Vault/Notes/A.md` → `Notes/A.md`; nil for the root itself or anything outside it.
    static func relative(_ absolute: String, to root: String) -> String? {
        let root = root.hasSuffix("/") ? String(root.dropLast()) : root
        guard absolute.hasPrefix(root + "/") else { return nil }
        let relative = String(absolute.dropFirst(root.count + 1))
        return relative.isEmpty ? nil : relative
    }
}
