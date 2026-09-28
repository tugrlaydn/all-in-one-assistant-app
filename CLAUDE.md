# Persona — Claude Code guide

macOS-only SwiftUI app: notes + tasks + habits on a horizontal calendar ("the Horizon"),
a Spotlight-style quick-input panel, five-category habits with nudges, a JSON Canvas vault view.
Markdown files in the owner's iCloud Drive folder are the only truth. The owner holds control;
the agent holds the pen.

## Start here, every session
The SessionStart hook has printed the current status and the pending proposals.
Read ONLY docs/plan/phases/<current phase>.md next. Read other files when it points to them.
Map of everything: docs/plan/README.md. Requirements: docs/SPEC.md (verbatim, wins conflicts).

## Commands — always through Make, never raw xcodebuild in the repo
make gen | build | test | run | format | vault-dump | stress-vault N=5000 | clean-stress | dist

## Who decides — docs/plan/working-agreements.md §8.2
Tier A (anything the owner sees, stores, lives with for years, or pays for): write a proposal with
/propose and build it only when its file says `status: ratified`. Tier B (internal engineering):
decide, record one short file in docs/decisions/, the owner may veto. Tier C: just do it.
A pending proposal never blocks a session — work on something that doesn't depend on it.

## Hard rules — most are enforced by .claude/settings.json and .claude/hooks/
- macOS only. No iOS/iPadOS targets, code, `#if os(iOS)`, or plans.
- Writes only inside this repo, $TMPDIR and ~/Library/Caches/Persona. Never iCloud Drive,
  never the owner's vault, never the real app's defaults (only *.persona.debug). §8.6.
- docs/SPEC.md is the owner's. Agents never edit it.
- Never hand-edit the .xcodeproj: edit project.yml, then `make gen`.
- No new dependency, no new format key, no new doc or process without a ratified proposal.
- Ideas outside SPEC go to docs/BACKLOG.md, not into code.
- VaultKit imports Foundation only. All file I/O through Vault (NSFileCoordinator).
  Round-trip stays byte-identical. Colours, fonts, motion only from DesignKit.
- One package → one green commit (`make build test`), conventional message.
- End every session with /report (two registers: plain language, then technical).

## Where things are
docs/plan/ — the plan, sharded (README.md is the map) · docs/plan/phases/ — one file per phase
docs/decisions/ — one file per decision, status in frontmatter · docs/FORMAT.md — the vault format
docs/PROGRESS.md (≤40 lines) · docs/BACKLOG.md · docs/reports/ — session reports + img/
Design/FIGMA.md — ratified frames · Design/blender/ — .blend sources · Design/renders/ — scratch
.claude/agents/ — reviewer, vault-tester, renderer · .claude/skills/ — /report, /propose
.claude/rules/ — module rules that load themselves when you touch VaultKit or UI code
