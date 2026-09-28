---
id: A02
title: "macOS 26 minimum"
tier: A
status: proposed
proposed: 2026-09-28
ratified:
owner_note:
---

# A02 — macOS 26 minimum

*Alternatives:* macOS 15 for wider reach.
**Why this one.** One user, one Mac, on the current OS. Every older release we support costs conditional code and blocks the current SwiftUI and Glass APIs the identity depends on. The agent verifies at P0 what Xcode and macOS are actually installed; if the owner is already on a newer release, 26 stays the floor unless the owner raises it.
**What would change my mind.** The owner's Mac not running 26.
**Reversal cost.** Raising the floor later is free; lowering it later is expensive.
