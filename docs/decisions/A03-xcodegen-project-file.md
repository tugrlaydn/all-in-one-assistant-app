---
id: A03
title: "XcodeGen owns the project file"
tier: B
status: ratified
proposed: 2026-09-28
ratified: 2026-09-29
owner_note: "ratified in chat: \"ratify all\""
---

# A03 — XcodeGen owns the project file

*Alternatives:* a hand-managed `.xcodeproj` · Tuist · SwiftPM-only.
**Why this one.** `.xcodeproj` is a merge-hostile plist that agents corrupt. A 60-line `project.yml` is readable, diff-able, and regenerated in one command. Tuist does far more than we need. SwiftPM alone cannot carry entitlements (sandbox, user-selected files) or a proper app bundle.
**What would change my mind.** Apple shipping a first-party text project format.
**Reversal cost.** An afternoon: generate once, commit the project file, delete the yml.
