# Persona — Development plan (v1.2)

**Persona** (D1, answered). **macOS only.** A Markdown vault in the owner's iCloud Drive folder is the only truth. This folder *is* the plan; `../SPEC.md` is the owner's requirements, verbatim, and wins every conflict.

## What changed
- **v1.2 (2026-09-28)** — first adopted version: every decision argued and *proposed* until the owner ratifies it; design tooling decided (A14); test data can never reach the owner (§8.6); the plan is a living document (§8.7); file organisation shaped for Claude Code agents and argued in `file-organization.md`.

## Map — where each part lives
| Part | File |
|---|---|
| §0 protocol · §2 non-negotiables · roadmap order · kick-off | this file |
| §1 what we are building · §6 design brief + keyboard map | `product.md` |
| §3 architecture index + repository layout | `architecture.md` → arguments in `../decisions/A01–A13` |
| §4 vault format + change log | `../FORMAT.md` (its shape argued in `../decisions/A15`) |
| §5 quick-input grammar | `grammar.md` (argued in `../decisions/A16`) |
| §6.1 design tooling: Figma / SwiftUI Motion Lab / Blender | `../decisions/A14-design-tooling.md` |
| §7 phases P0–P9 | `phases/P0.md` … `phases/P9.md` |
| §8 working agreements (loop, tiers, code rules, report, subagents, test data, living plan) | `working-agreements.md` |
| §9 owner decisions D1–D10 | `owner-decisions.md` |
| How this repo is organised for agents, argued (O1–O10) | `file-organization.md` |
| Agent guardrails, subagents | `.claude/` — see `../decisions/A17`, `A18` |

Section numbers (§) are kept from the master plan so every cross-reference still resolves through this table.

## 0. Agent protocol

- **Read only what you need:** `CLAUDE.md` (loaded for you), the SessionStart hook output (current status, pending proposals), and the current phase file in `phases/`. Do not re-read the whole plan, old reports, or decision files that are already ratified.
- **One work package → one commit.** Every commit builds (`make build`) and passes tests (`make test`). Conventional commit messages: `feat(vault): …`, `fix(horizon): …`.
- **The owner holds control; the agent holds the pen.** Decisions come in three tiers (§8.2). Tier A — anything the owner will see, store, or live with for years — is *proposed* with its full argument (`/propose`, format in `../decisions/README.md`) and built only after the owner ratifies it. Tier B — internal engineering — the agent decides, records in one line, and the owner can veto in the next reply. Tier C is line-level and unrecorded. A pending Tier A never blocks a session: propose it, batch it into the report, work on something that doesn't depend on it.
- **Test data never touches the owner's world.** Fixtures and stress vaults live in the repo or in a caches folder — never in the owner's vault, never in iCloud Drive, never in the owner's settings (§8.6).
- **Ideas that are not in SPEC go to `docs/BACKLOG.md`**, not into the code.
- **Report every session** in two registers — plain language for a normal reader, then technical detail (§8.4). SPEC makes this mandatory.
- **No iOS/iPadOS.** No targets, no `#if os(iOS)`, no plans, no "while we're here". The only provision for the future is that `VaultKit` never imports AppKit or SwiftUI. Nothing else, until the owner says so.
- **No new process.** The plan shards, the decision files, `SPEC`, `PROGRESS`, `BACKLOG`, `FORMAT`, and the reports folder are the whole process. Do not add gates, ledgers, decision sheets, or extra documents; do not add files to `.claude/` without a proposal.

---

---

## 2. Non-negotiables (from SPEC)

| # | Rule | Enforced in |
|---|---|---|
| N1 | macOS only, now. iOS/iPadOS is neither planned nor built until the owner says so. | §0, phases/P0 |
| N2 | Files are the only truth. Every file is readable and editable without the app; the app never rewrites what it did not change. | FORMAT §4.5, phases/P1 |
| N3 | The format must work on macOS, iOS, and iPadOS: UTF-8 Markdown + YAML front matter + JSON Canvas. No database or binary store as truth. | FORMAT.md |
| N4 | Sync = an iCloud Drive folder. Backup = a plain zip of the vault. | phases/P8 |
| N5 | One input surface for everything — the quick-input panel and the in-app ⌘K bar share one grammar. | grammar.md, phases/P3 |
| N6 | Calendar-first: the Horizon is the home screen. | product.md §6, phases/P2 |
| N7 | Native macOS feel plus a distinct identity. Keyboard-first, smooth motion, Reduce Motion honoured. | product.md §6 |
| N8 | Habits: five fixed categories, weekly budgets, category-level tracking, proactive nudges with in-notification logging. | phases/P6 |
| N9 | Tasks have subtasks; notes are simple (Obsidian-style links and tags, no plugins). | phases/P4, P5 |
| N10 | Every session ends with a two-register report. | working-agreements §8.4 |

---

---

## 7. Roadmap — phase index

Each phase file has a goal, packages (tick as done), an acceptance test, and — where it matters — the milestone the owner can feel. Estimates are Claude Code sessions. The order is fixed. Scope inside a phase changes only with a decision file.

**Why this order (argued).** P1 before any UI because every later phase writes files, and a wrong writer corrupts the owner's vault. P2 (read-only calendar) before P3 (capture) so the first capture lands on something visible. P3 before P4–P6 because the moment `⌥Space` works the app is worth using daily, and every later phase then gets real-use feedback instead of guesses. Habits (P6) after tasks and notes because it depends on both the Horizon and the notification pipeline. Canvas (P7) late because it is the least frequently used surface. Sync hardening (P8) once there is real data to conflict. Release (P9) last. *Alternative considered:* habits first, since it is the most novel feature — rejected because habits without capture and a calendar would be a form, not a product.

| Phase | Goal | Milestone | Status |
|---|---|---|---|
| [P0](phases/P0.md) | Bootstrap (1 session) |  | not started |
| [P1](phases/P1.md) | VaultKit core (2 sessions) |  | not started |
| [P2](phases/P2.md) | App shell + Horizon, read-only (2 sessions) | see my vault on the calendar | not started |
| [P3](phases/P3.md) | Quick Input everywhere (2 sessions) | daily use starts here | not started |
| [P4](phases/P4.md) | Tasks (2 sessions) |  | not started |
| [P5](phases/P5.md) | Notes (2 sessions) |  | not started |
| [P6](phases/P6.md) | Habits (3 sessions) |  | not started |
| [P7](phases/P7.md) | Vault canvas (2 sessions) |  | not started |
| [P8](phases/P8.md) | Sync, safety, performance (2 sessions) |  | not started |
| [P9](phases/P9.md) | Polish and release (2 sessions) | installed on a second Mac | not started |

**Total ≈ 20 sessions.** Explicitly outside this plan: iOS/iPadOS, multi-user or sharing, time-blocking within a day, plugins, CloudKit.

---

## Kick-off

1. Create the repository folder and copy this starter kit into it (`CLAUDE.md`, `.claude/`, `docs/`, `Design/`, `.gitignore`, `README.md`). Check that `docs/SPEC.md` is your requirements document, verbatim.
2. `chmod +x .claude/hooks/*` (the kit ships them executable; zip transfers sometimes drop it).
3. If you want Blender renders, configure the Blender MCP server in Claude Code under the name `blender` — the `renderer` subagent references it by that name. Optional; nothing else depends on it.
4. Start Claude Code in the folder. First prompt, verbatim if you like:

> Run /doctor, then read docs/plan/README.md and docs/plan/phases/P0.md. Execute P0 completely, using the defaults in docs/plan/owner-decisions.md meanwhile. Every decision in docs/decisions/ is proposed, not ratified: do not present any of them as settled, and list A01–A18 in report 0's Proposals section with a one-line summary and a link each. Finish with /report.

5. From then on, each session starts with *"Continue from PROGRESS."* — the SessionStart hook shows the status; you only answer proposals.

You are needed at these points: ratifying Tier A proposals in each report (usually a few yes/no lines, or editing `status:` in the decision file yourself), the Figma frames and accent pick in P2, the Motion Lab numbers, the Apple Developer account for P9, and a week of real use after P9. Everything else is the agents' job — and every decision they make is written down where you can veto it.
