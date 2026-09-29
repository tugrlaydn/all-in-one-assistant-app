import AppKit
import Foundation
import Observation
import VaultKit

/// The open vault, for the whole app: which folder, its index, and keeping both current (P2).
///
/// On launch it opens the debug `--vault` test folder, else the folder remembered as a bookmark, else
/// nothing — the owner chooses one (File → Choose Vault…). Opening creates the empty skeleton (folders
/// only, never sample data), loads the index, and watches: FSEvents nudges changed paths at once and a
/// slow poll is the safety net (B03).
@MainActor
@Observable
final class VaultSession {
    enum State: Equatable {
        case noVault
        case open(URL)
        case failed(String)
    }

    /// Polling only backs up FSEvents, so it can be slow (B03).
    static let pollInterval: Duration = .seconds(10)

    private(set) var state: State = .noVault
    private(set) var index = VaultIndex()
    private(set) var lastLoad: LoadReport?
    private(set) var vault: Vault?

    @ObservationIgnored private let bookmarks: VaultBookmarkStore
    @ObservationIgnored private let launch: LaunchOptions
    @ObservationIgnored private var watcher: VaultWatcher?
    @ObservationIgnored private var events: FolderEvents?
    @ObservationIgnored private var watchTask: Task<Void, Never>?
    @ObservationIgnored private var scopedURL: URL?

    init(launch: LaunchOptions, bookmarks: VaultBookmarkStore = VaultBookmarkStore()) {
        self.launch = launch
        self.bookmarks = bookmarks
    }

    var openURL: URL? {
        if case let .open(url) = state { return url }
        return nil
    }

    /// Test vault (debug `--vault`), else the remembered folder, else nothing.
    func openOnLaunch() async {
        if let testVault = launch.testVault {
            await open(testVault, remember: false)
        } else if let remembered = bookmarks.load() {
            await open(remembered, remember: false)
        } else {
            state = .noVault
        }
    }

    /// Opens `url` as the vault. `remember` keeps it for the next launch — never for a test vault.
    func open(_ url: URL, remember: Bool) async {
        close()
        if url.startAccessingSecurityScopedResource() { scopedURL = url }
        do {
            let vault = try Vault(root: url)
            try await vault.createSkeleton()
            lastLoad = try await vault.load()
            if remember, !launch.isTestVault { try bookmarks.save(url) }
            self.vault = vault
            index = await vault.index
            startWatching(vault, root: url)
            state = .open(url)
        } catch {
            close()
            state = .failed(String(describing: error))
        }
    }

    func close() {
        watchTask?.cancel()
        watchTask = nil
        events?.stop()
        events = nil
        if let watcher { Task { await watcher.stop() } }
        watcher = nil
        vault = nil
        index = VaultIndex()
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
        state = .noVault
    }

    private func startWatching(_ vault: Vault, root: URL) {
        let watcher = VaultWatcher(vault: vault, interval: Self.pollInterval)
        self.watcher = watcher
        let events = FolderEvents(root: root) { paths in
            Task { await watcher.nudge(paths) }
        }
        events.start()
        self.events = events
        watchTask = Task { [weak self] in
            for await _ in await watcher.start() {
                let index = await vault.index
                self?.index = index
            }
        }
    }

    // MARK: Choosing a vault

    /// The system folder panel, starting in iCloud Drive (D4 suggests `iCloud Drive/Persona`).
    func chooseVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Use as Vault"
        panel.message = "Choose the folder that holds your Persona vault — or create one, e.g. “Persona” in iCloud Drive."
        panel.directoryURL = Self.suggestedFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await open(url, remember: true) }
    }

    /// `iCloud Drive/Persona` if it exists, else iCloud Drive, else the home folder. Real home, not the
    /// sandbox container: the panel runs outside the sandbox and grants access to what the owner picks.
    static var suggestedFolder: URL {
        let home = getpwuid(getuid()).flatMap { URL(fileURLWithPath: String(cString: $0.pointee.pw_dir)) }
            ?? FileManager.default.homeDirectoryForCurrentUser
        let iCloudDrive = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        let persona = iCloudDrive.appendingPathComponent("Persona", isDirectory: true)
        if FileManager.default.fileExists(atPath: persona.path) { return persona }
        if FileManager.default.fileExists(atPath: iCloudDrive.path) { return iCloudDrive }
        return home
    }
}
