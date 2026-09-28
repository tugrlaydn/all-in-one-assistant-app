---
id: A16
title: "Quick Input grammar — prefix letters, symbol tokens, never eat unknown text"
tier: A
status: proposed
proposed: 2026-09-28
ratified:
owner_note:
---

# A16 — Why the Quick Input grammar looks like this

The grammar itself is in `docs/plan/grammar.md`.

 Prefix letters (`t`, `n`, `h`) are one keystroke and can never collide with a title. The token symbols (`@ # ! ~ >`) are what Todoist, Things, and Alfred users already type, so nothing new has to be learned. Parsing is a pure function in VaultKit, so the panel, ⌘K, and the notification text field cannot disagree. The "never eat unknown text" rule means a mistyped token becomes a word in the title rather than a lost thought — capture must never fail. *Alternatives:* natural-language dates only (ambiguous, and slower to type than `@fri`); a form with fields (SPEC explicitly asks for one line).
