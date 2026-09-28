import Foundation

/// Keeps a vault's index in step with the folder and tells the app what changed (P1: external edits
/// visible within one second).
///
/// VaultKit is Foundation-only, so the watcher itself polls `Vault.rescan()` — one directory listing
/// per tick, files re-read only when their date or size moved. A platform event source (FSEvents in the
/// app, P2) calls `nudge` with the paths it saw, which refreshes them at once; polling then only needs
/// to be a slow safety net (B03).
public actor VaultWatcher {
    public let vault: Vault
    public let interval: Duration
    private var continuation: AsyncStream<Set<String>>.Continuation?
    private var task: Task<Void, Never>?
    /// Which `start` the current stream belongs to, so an old stream ending can't stop a new one.
    private var generation = 0

    public init(vault: Vault, interval: Duration = .milliseconds(500)) {
        self.vault = vault
        self.interval = interval
    }

    deinit {
        task?.cancel()
        continuation?.finish()
    }

    /// Starts watching. Each element is the set of vault-relative paths whose index entry changed.
    /// Calling `start` again ends the previous stream and starts a new one.
    public func start() -> AsyncStream<Set<String>> {
        stop()
        generation += 1
        let current = generation
        let (stream, continuation) = AsyncStream<Set<String>>.makeStream(bufferingPolicy: .unbounded)
        self.continuation = continuation
        let vault = vault
        let interval = interval
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                // The watcher is gone (released without `stop`): stop polling too.
                guard !Task.isCancelled, let self else { break }
                if let changed = try? await vault.rescan(), !changed.isEmpty {
                    await self.emit(changed, generation: current)
                }
            }
        }
        continuation.onTermination = { [weak self] _ in
            Task { await self?.stop(generation: current) }
        }
        return stream
    }

    public func stop() {
        task?.cancel()
        task = nil
        let ending = continuation
        continuation = nil
        ending?.finish()
    }

    /// Stops only if `generation` is still the current stream (an old stream's termination is ignored).
    private func stop(generation: Int) {
        guard generation == self.generation else { return }
        stop()
    }

    /// Paths an event source saw change (vault-relative). Refreshed now, without waiting for a tick.
    public func nudge(_ paths: Set<String>) async {
        if let changed = try? await vault.refresh(paths), !changed.isEmpty {
            emit(changed, generation: generation)
        }
    }

    private func emit(_ changed: Set<String>, generation: Int) {
        guard generation == self.generation else { return }
        continuation?.yield(changed)
    }
}
