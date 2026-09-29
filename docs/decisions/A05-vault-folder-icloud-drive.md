---
id: A05
title: "The vault is a user-chosen folder in iCloud Drive; no CloudKit"
tier: A
status: ratified
proposed: 2026-09-28
ratified: 2026-09-29
owner_note: "ratified in chat: \"ratify all\""
---

# A05 — The vault is a user-chosen folder in iCloud Drive; no CloudKit

*Alternatives:* a CloudKit database · an app-private iCloud container · Dropbox or git.
**Why this one.** The most important sentence in SPEC is that files must be usable without the app. CloudKit makes a database the truth and the files an export — the exact opposite. An app-private container syncs, but hides the folder from Obsidian and Finder and needs a Developer-account entitlement before the first build. A plain folder that the owner picks (suggested `iCloud Drive/Persona`; an existing Obsidian vault works too) syncs through iCloud Drive with zero code, is visible everywhere, and is backed up by zipping it. The price is real and accepted: we handle iCloud's evicted-file placeholders and version conflicts ourselves (P1, P8), and every read/write goes through `NSFileCoordinator` so we never race the sync daemon.
**What would change my mind.** iCloud Drive conflicts proving unmanageable in daily use — then a CloudKit *mirror* (files still the truth) goes to BACKLOG.
**Reversal cost.** Medium. The files never change; only the sync layer would.
