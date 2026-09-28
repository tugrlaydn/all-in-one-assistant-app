---
name: report
description: End-of-session report in two registers (plain language, then technical). Writes docs/reports/<date>-<phase>-<n>.md, updates docs/PROGRESS.md and ticks the phase file. Run at the end of every session.
disable-model-invocation: true
---

Today: !`date +%Y-%m-%d`
Current status:
!`awk '/^## Current status/{on=1; next} /^## /{on=0} on && NF' docs/PROGRESS.md`
Existing reports: !`ls docs/reports/*.md 2>/dev/null | tail -n 5 || echo none`
Recent commits:
!`git log --oneline -n 20`
Pending proposals: !`grep -l '^status: proposed' docs/decisions/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | tr '\n' ' '`

Steps:
1. File name: `docs/reports/<today>-<phase>-<n>.md`, where n is one more than the highest n for
   this phase in the list above (1 if none).
2. Write the report with exactly the template in docs/plan/working-agreements.md §8.4:
   `## In plain language` (4–10 sentences, no jargon, exact keys to press, what I need from the
   owner) · `## Proposals — Tier A, need your yes/no` (one line each with a link to its file) ·
   `## Decided — Tier B, you can veto` · `## Technical detail` (changes, tests added/total/result,
   risks, screenshots from fixture vaults only).
   Be honest: anything not built, not verified, or failing is said plainly in both registers.
3. Tick the finished packages in the current phase file (`- [x]`). Update its `Status:` line.
4. Update docs/PROGRESS.md: rewrite the Current status block; add this session at the top of the
   session log; delete entries beyond the newest five (O8). Keep the file under 40 lines.
5. If a phase finished, update its row in docs/plan/README.md (§7 table).
6. Commit: `docs(report): session <n> — <phase>`.
