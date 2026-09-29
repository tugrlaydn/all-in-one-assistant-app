---
id: A09
title: "Carbon `RegisterEventHotKey` for the global shortcut"
tier: B
status: ratified
proposed: 2026-09-28
ratified: 2026-09-29
owner_note: "ratified in chat: \"ratify all\""
---

# A09 — Carbon `RegisterEventHotKey` for the global shortcut

*Alternatives:* an `NSEvent` global monitor (needs Accessibility permission) · a third-party library.
**Why this one.** It is the sandbox-safe way to get a system-wide shortcut without asking the owner to grant Accessibility access — a permission that is alarming, easily lost on updates, and unnecessary. It is old API, but Apple keeps it working and it is about 40 lines. No dependency needed.
**Reversal cost.** Trivial.
