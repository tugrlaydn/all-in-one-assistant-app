# Vault format v1 (`docs/FORMAT.md`)

### 4.1 Folder layout

```
<Vault>/
  Notes/                 one .md per note
  Tasks/                 one .md per task (subtasks live inside the file)
  Habits/
    Categories.md        category budgets + nudge times
    <habit>.md           one .md per habit
    Weeks/2026-W40.md    weekly plan + time log, one file per ISO week
  Attachments/           images and files referenced from notes
  Vault.canvas           JSON Canvas layout for the Vault view
  .persona/             app cache (index.json) — never truth, safe to delete
```

Rules: file name = `<Title slug>.md`; collisions get `-2`, `-3`. `id` is a ULID and never changes; renaming the title renames the file. Timestamps are ISO 8601 with offset; days are `YYYY-MM-DD`; weeks are ISO weeks (`2026-W40`, Monday start).

### 4.2 Note — `Notes/<title>.md`

```markdown
---
id: 01J9K3…
type: note
title: Antenna notes
created: 2026-09-28T09:12:00+03:00
updated: 2026-09-28T09:40:00+03:00
tags: [rf, capsule]
---
Body in Markdown. Links: [[Task title]] or [[Note title]]. Tags: #inline-tag.
```

### 4.3 Task — `Tasks/<title>.md`

```markdown
---
id: 01J9K4…
type: task
title: Send invoice
status: todo              # todo | doing | done | dropped
created: 2026-09-28T09:12:00+03:00
updated: 2026-09-28T09:12:00+03:00
scheduled: 2026-09-30     # the day it sits on in the Horizon (optional)
due: 2026-10-03           # deadline (optional)
done_at:                  # set when status becomes done
priority: 2               # 1 high · 2 normal · 3 low (optional)
estimate: 45m             # optional
tags: [work]
parent: "[[Q4 invoicing]]"      # optional — another task
links: ["[[Client note]]"]      # optional — [[links]] in the body also count
---
Free notes about the task.

## Subtasks
- [ ] Draft the PDF
  - [ ] Check hours
- [x] Get the PO number
```

Subtasks are checklist lines under `## Subtasks`, nested by two spaces, any depth (the UI shows two levels; deeper levels stay in the file untouched). Progress = done leaves ÷ all leaves. A task with `parent` is a subtask that earned its own file.

### 4.4 Habits — definition, categories, weeks

`Habits/<title>.md`

```markdown
---
id: 01J9K5…
type: habit
title: Swimming
category: physical        # physical | creative | knowledge | mindset | monetizable
active: true
default_minutes: 45
created: 2026-09-28T09:12:00+03:00
---
Optional notes about the habit.
```

`Habits/Categories.md`

```markdown
---
type: habit-categories
budget_minutes_per_week:
  physical: 150
  creative: 90
  knowledge: 120
  mindset: 60
  monetizable: 90
nudge_times: ["12:30", "20:00"]
---
```

`Habits/Weeks/2026-W40.md`

```markdown
---
id: 01J9K6…
type: habit-week
week: 2026-W40
plan:                     # this week's hobby per category (each optional)
  physical: "[[Swimming]]"
  creative: "[[Piano]]"
---
## Log
| date | habit | minutes | note |
|---|---|---|---|
| 2026-09-28 | [[Swimming]] | 45 | evening |
```

Budgets live in the vault (not in app settings) so they sync with everything else.

### 4.5 Round-trip rule (tested from P1 onward)

Parse → serialize of an untouched file is **byte-identical**. Writing a field changes only that field's line(s); unknown keys, comments, and body bytes are preserved. A golden-file test locks every file type. Any format change is **add-only**, recorded as one dated line in `docs/FORMAT.md`; keys are never renamed or removed. Format changes are always Tier A.

### 4.6 Why the format has this shape

Argued in `docs/decisions/A15-vault-format-shape.md` (Tier A, proposed).

---

## Change log (add-only; every line is a ratified Tier A decision)

| date | file type | change | decision |
|---|---|---|---|
| 2026-09-28 | all | format v1 as above | A07, A15 |
