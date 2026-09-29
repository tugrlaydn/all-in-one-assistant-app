---
id: A08
title: "NSTextView editor; no WYSIWYG"
tier: A
status: ratified
proposed: 2026-09-28
ratified: 2026-09-29
owner_note: "ratified in chat: \"ratify all\""
---

# A08 — NSTextView editor; no WYSIWYG

*Alternatives:* a WYSIWYG SwiftUI editor · a web-view editor (CodeMirror).
**Why this one.** A live-rendering Markdown editor is a multi-month project on its own and the single biggest schedule risk. `NSTextView` on TextKit 2 gives native selection, undo, dictation, spell-check, find, and speed for free; styling headings, links, and checkboxes on top of plain text is a few hundred lines. A web view would break the native feel SPEC insists on.
**Reversal cost.** Medium — the editor is one view.
