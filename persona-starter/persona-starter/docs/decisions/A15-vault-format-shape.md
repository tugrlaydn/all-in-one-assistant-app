---
id: A15
title: "Vault format shape — one file per item, subtasks inline, week files, budgets in the vault"
tier: A
status: proposed
proposed: 2026-09-28
ratified:
owner_note:
---

# A15 — Why the vault format has this shape

The format itself is specified in `docs/FORMAT.md`. This file argues its shape.

- **One file per task and per note, not one big file.** iCloud syncs and conflicts per file; a single `tasks.md` would turn every two-device edit into a conflict of everything. One file per item also makes each task linkable with `[[Title]]`, openable on its own in Obsidian, and diff-able in git.
- **Subtasks inside the task file, not as separate files.** SPEC wants tasks split into smaller pieces; most subtasks are three-word checklist lines. A file for each would flood the folder and distort the "feel how full the day is" reading. Nesting by indentation is exactly how Obsidian writes checklists, so it round-trips. A subtask that grows up is promoted to its own file with `parent:` (P4).
- **Habit weeks as one file per ISO week.** SPEC tracks habits *weekly*, per category, with a hobby that may change week to week. A week file holds the plan and the log together, is the natural unit for the Monday nudge, and keeps the log table short enough to read. A file per entry would be hundreds of tiny files; one endless log would conflict on every edit.
- **Budgets and nudge times in `Habits/Categories.md`, not in app settings.** They are the owner's data and must reach every device; app settings don't sync. In the vault they are also editable without the app.
- **ULID ids that never change; file names that follow the title.** People rename things; links by title alone would break, so links resolve by title and fall back to id. ULIDs sort by creation time, which gives "recent" ordering for free.
- **YAML front matter, not inline `key:: value` fields.** Front matter is what Obsidian, Hugo, and every Markdown tool already parse; inline fields are specific to one Obsidian plugin.
