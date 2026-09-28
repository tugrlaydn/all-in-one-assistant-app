---
id: A06
title: "In-memory index with a JSON cache; no database"
tier: B
status: proposed
proposed: 2026-09-28
ratified:
owner_note:
---

# A06 — In-memory index with a JSON cache; no database

*Alternatives:* SQLite (GRDB or SwiftData) · no index, scan on demand.
**Why this one.** A few thousand small Markdown files parse in well under a second on any current Mac. A database adds a dependency, a schema, migrations, and a second thing that can disagree with the files. The cache only makes the second launch faster and can be deleted at any time. If the vault ever passes ~10k files, the decision is revisited with a measurement (P8 has the benchmark), not a guess.
**Reversal cost.** Low — the index sits behind one protocol.
