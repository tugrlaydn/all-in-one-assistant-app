---
id: A10
title: "`UNUserNotificationCenter` with actionable, text-input notifications"
tier: B
status: ratified
proposed: 2026-09-28
ratified: 2026-09-29
owner_note: "ratified in chat: \"ratify all\""
---

# A10 — `UNUserNotificationCenter` with actionable, text-input notifications

*Alternatives:* a custom floating popup · in-app banners.
**Why this one.** SPEC wants nudges that take input *without* the owner opening the app. Notification actions with a text field are exactly that: click "Log 30", or type `swim 45` into the notification, and the app writes the week file in the background. A custom popup would need the app in front, which defeats the purpose.
**Reversal cost.** Trivial.
