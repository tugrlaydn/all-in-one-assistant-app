---
id: B03
title: "Watcher: Foundation-only rescan polling in VaultKit, FSEvents nudges from the app"
tier: B
status: decided
proposed: 2026-09-28
ratified:
owner_note:
---

# B03 — How external edits reach the index

*Alternatives:* FSEvents inside VaultKit · `NSFilePresenter` only · per-file dispatch sources.
**Why this one.** FSEvents is the right macOS event source (recursive, kernel-backed, cheap) but it is
CoreServices, and VaultKit imports Foundation only (§8.3). `NSFilePresenter` hears only coordinated
writers — Obsidian, vim and git don't coordinate. Dispatch sources need one open file per note.
So VaultKit owns the *logic* — `Vault.rescan()` reconciles the listing with the index by modification
date and size and re-reads only what moved; `VaultWatcher` polls it (0.5 s today, meeting "visible
within one second") and has a `nudge(paths)` door. In P2 the app adds an FSEvents source that calls
`nudge` the moment something changes, and the polling interval rises to a slow safety net.
**What would change my mind.** A measured idle cost that matters before P2 lands (P8 has the
benchmark with 5000 files).
**Reversal cost.** Low — the event source is one small type in the app.
