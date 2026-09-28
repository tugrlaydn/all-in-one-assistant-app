---
id: A17
title: "Agent guardrails — settings.json deny rules, PreToolUse path guard, acceptEdits inside the repo"
tier: A
status: proposed
proposed: 2026-09-28
ratified:
owner_note:
---

# A17 — Agent guardrails

Argued in `docs/plan/file-organization.md`, O5. Summary: the test-data rule (§8.6) and "SPEC wins" are enforced by Claude Code itself — `.claude/settings.json` deny rules plus a `PreToolUse` hook that blocks any write outside the repo, `$TMPDIR` and `~/Library/Caches/Persona`, any edit of `docs/SPEC.md`, and any shell command that touches iCloud Drive or the real app's defaults. `defaultMode: acceptEdits` removes per-edit prompts *inside* the fence so the owner's control sits at the decision level, not the keystroke level.

**What would change my mind.** The owner preferring to approve every file edit — set `defaultMode` to `default`; the fence still holds.
**Reversal cost.** Trivial: delete two files.
