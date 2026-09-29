---
id: A07
title: "Our own front-matter parser with byte-identical round-trip"
tier: A
status: ratified
proposed: 2026-09-28
ratified: 2026-09-29
owner_note: "ratified in chat: \"ratify all\""
---

# A07 — Our own front-matter parser with byte-identical round-trip

*Alternatives:* swift-markdown (cmark) plus a YAML library · regenerating every file from the model on save.
**Why this one.** SPEC says files are the truth and will be edited elsewhere. Any parser that builds a tree and re-serialises it reorders keys, normalises quotes, and strips comments — every save would silently rewrite what Obsidian or the owner wrote. A line-oriented parser that understands front matter, headings, checklist lines, and tables, and touches only the lines it changes, keeps files exactly as they were. Golden and fuzz tests make that promise checkable rather than hoped-for. Full CommonMark is not needed: SPEC says notes stay simple.
**What would change my mind.** The owner wanting rich rendering — a *read-only* renderer can be added later without touching the writer.
**Reversal cost.** Medium. The writer is small, but its guarantee is load-bearing.
