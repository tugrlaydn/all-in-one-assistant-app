---
id: A04
title: "Three modules"
tier: A
status: proposed
proposed: 2026-09-28
ratified:
owner_note:
---

# A04 — Three modules

*Alternatives:* one app target · many small packages.
**Why this one.** `VaultKit` (Foundation only) holds every rule about files, so it is tested in seconds without a UI. It is also the *entire* provision for a future iOS app: no iOS code is written, but nothing in the logic layer will need rewriting either. `DesignKit` holds the identity in one place so the look cannot drift screen by screen. One target would let views reach into file I/O; more than three packages adds build-graph overhead with no reader benefit.
**Reversal cost.** Low — moving files between packages is mechanical.
