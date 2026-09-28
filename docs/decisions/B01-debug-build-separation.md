---
id: B01
title: "Debug build separation: own bundle id, launch-time check, caches-only sandbox exception"
tier: B
status: decided
proposed: 2026-09-28
ratified:
owner_note:
---

# B01 — How the debug build stays a different app (§8.6)

*Alternatives:* a separate UserDefaults suite name inside one bundle id · no sandbox in debug builds.
**Why this one.** A different bundle id (`…persona.debug`) gives the debug build its own defaults domain,
its own sandbox container and therefore its own vault bookmark with no code at all — nothing to forget.
`BuildFlavor.checkSeparation()` refuses to launch if the configuration and the bundle id ever disagree.
The debug build keeps the sandbox, so it behaves like the real app, plus one temporary exception for
`~/Library/Caches/Persona/` so `--vault` can open stress vaults (§8.6); the release entitlements have no
exception. Hardened runtime is on for Release only: with ad-hoc signing, Debug library validation would
stop the unit-test bundle from loading.
**What would change my mind.** Notarisation (P9) rejecting the exception in any build we ship — it is
debug-only, so it should not.
**Reversal cost.** Minutes: two settings in `project.yml` and one entitlements file.
