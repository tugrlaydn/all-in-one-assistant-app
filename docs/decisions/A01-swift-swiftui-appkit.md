---
id: A01
title: "Swift 6 + SwiftUI, with AppKit where SwiftUI falls short"
tier: A
status: ratified
proposed: 2026-09-28
ratified: 2026-09-29
owner_note: "ratified in chat: \"ratify all\""
---

# A01 — Swift 6 + SwiftUI, with AppKit where SwiftUI falls short

*Alternatives:* pure AppKit · Electron/Tauri · Flutter · Mac Catalyst.
**Why this one.** SPEC asks for two things at once: a native macOS feel and a distinctive look. Only Swift delivers both. Native means Liquid Glass, real menus, Settings, Services, Shortcuts, notifications with actions, and the security-scoped file access that lets a sandboxed app work on an iCloud-synced folder — web stacks imitate the first half and cannot do the second. Pure AppKit would be honest but slow to iterate on an animated accordion of columns; SwiftUI's declarative layout and spring animations are precisely the tool for the Horizon. AppKit stays for the four things SwiftUI still does poorly on macOS: a non-activating floating panel, a global hotkey, a serious text editor, and the status item.
**What would change my mind.** A requirement for Windows or Linux. Nothing in SPEC points there.
**Reversal cost.** Total. This is the one effectively permanent decision, which is why it is argued first.
