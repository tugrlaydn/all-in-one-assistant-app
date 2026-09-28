---
id: B02
title: "Coordinated file I/O with a direct fallback where coordination does not exist"
tier: B
status: decided
proposed: 2026-09-28
ratified:
owner_note:
---

# B02 — `CoordinatedFileAccess` falls back to direct I/O without `NSFileCoordinator`

*Alternatives:* coordinated I/O only, testing VaultKit's file layer on macOS CI alone · a test-only
fake file system.
**Why this one.** The owner chose to keep development in the cloud, where the agents build on Linux:
Swift runs there, but Foundation has no `NSFileCoordinator`. One type, `CoordinatedFileAccess`, coordinates
every read, write and move on macOS (A05) and does the same operations directly where coordination
does not exist — one `#if canImport(Darwin)` per operation, nothing else. The Vault logic (skeleton,
naming, rename-on-title, conflict refusal, cache) then runs in the agents' fast loop against real
temp-directory files, and macOS CI runs the very same tests through the coordinated path. A fake file
system would test the fake, not the files. This is not an iOS provision: no `#if os(iOS)` anywhere.
**What would change my mind.** A macOS-only behaviour (iCloud placeholders, coordination deadlocks)
that the Linux path hides — then those tests move to a macOS-only suite.
**Reversal cost.** Minutes: delete the `#else` branches.

Also decided with P1: opening the vault **from a security-scoped bookmark** moves to P2, next to the
vault picker that creates the bookmark; VaultKit takes a folder URL, and the app owns the bookmark
(macOS sandbox API, so it stays out of the Foundation-only package).
