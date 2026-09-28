# File organisation for Claude Code agents (v1.2, argued)

The owner allowed the file organisation to change to suit Claude Code agents, on the condition that every decision is argued. Each item below follows the decision format: *Alternatives* · **Why this one** · **What would change my mind** · **Reversal cost**. O1–O4, O6, O8–O10 are Tier B (internal engineering: the owner may veto). O5 and O7 change what the owner sees and how control is enforced, so they are Tier A and have their own decision files (`../decisions/A17`, `A18`).

**The principle behind all of them: an agent pays for every line it reads, every session, for years.** The owner reads a document once; the agent reads it hundreds of times, and each read costs tokens, time and — past a point — attention, because instructions buried in long files are followed less reliably than short ones. So the organisation optimises for the smallest *correct* read per session, and it moves the rules that matter most out of prose and into things Claude Code enforces mechanically.

**Read-per-session budget after this change:** `CLAUDE.md` (~55 lines) + SessionStart hook output (~12 lines: current status, pending proposals) + the current phase file (~25 lines) ≈ 90 lines. Before: one 670-line plan, of which any given session needed roughly a tenth. Everything else loads on demand, by pointer.

## O1 — The plan is sharded into `docs/plan/`, with a map
*Alternatives:* one `PLAN.md` (v1.1) · a wiki · GitHub issues.
**Why this one.** A single plan is best for the reader who reads it once — the owner — and worst for the reader who reads it every session. Sharding by *what a session needs* (one phase file, one agreements file, one product file) lets `CLAUDE.md` point at exactly one file per session. It also solves the long-term problem the owner named: a project developed for years accumulates phases, and `phases/P10.md` is a new file, not a growing scroll. Section numbers (§0–§9) are kept inside the shards, so nothing argued in v1.1 had to be rewritten and cross-references still resolve through the map in `README.md`.
**What would change my mind.** Claude Code gaining a reliable "read section N of file X" primitive — then one file with anchors would be equivalent.
**Reversal cost.** `cat docs/plan/*.md docs/plan/phases/*.md > PLAN.md`. Ten seconds.

## O2 — One file per decision, status in frontmatter
*Alternatives:* a `DECISIONS.md` table (v1.1) · decisions inline in the plan.
**Why this one.** The owner asked for arguments, and eighteen argued decisions are ~300 lines — too many to put in a file the agent scans for one status. A file per decision has three properties a table lacks: the status is a single frontmatter line the owner can flip in any editor; `grep -l '^status: proposed'` *is* the pending list, so the SessionStart hook prints it with no reasoning involved; and a decision's argument stays put while the index (`README.md` in `decisions/`, the table in `architecture.md`) stays short. The shape scales for years: `A47-….md` is no worse than `A05-….md`.
**What would change my mind.** Decisions turning out to be mostly one-liners with no argument — then a table is cheaper. The owner asked for the opposite.
**Reversal cost.** A script that concatenates frontmatter into a table. Minutes.

## O3 — `CLAUDE.md` is a pointer file, under 60 lines
*Alternatives:* a long `CLAUDE.md` with everything in it · no `CLAUDE.md`, rely on the plan.
**Why this one.** `CLAUDE.md` is loaded every session *and into every subagent*. Every line in it is paid for on every turn of every agent, forever. It should therefore say what to read and the handful of rules that must never be missed, and nothing else. Long guidance files are also followed less reliably than short ones — the length itself is a risk. Everything that was in the v1.1 `§10.1` template now lives in real files that load only when needed (O4, O6).
**What would change my mind.** Nothing foreseeable; this is the documented practice.
**Reversal cost.** Trivial.

## O4 — Path-scoped rules in `.claude/rules/`
*Alternatives:* module rules in `CLAUDE.md` · module rules only in the plan.
**Why this one.** The VaultKit rules (Foundation only, byte-identical round-trip, fixtures in the temp dir) matter only when an agent edits VaultKit; the UI rules (tokens only, ratified Figma frame first, Motion Lab numbers, debug bundle id) matter only when it edits `App/` or `DesignKit`. A rule file with a `paths:` list loads only when a matching file is touched — the right rule at the right moment, at zero cost the rest of the time. A session-wide `CLAUDE.md` cannot do that.
**What would change my mind.** The rule files not loading on the installed Claude Code version — P0 verifies with `/doctor`; if unsupported, the two files' content moves into `CLAUDE.md` (cost: ~15 lines per turn, forever).
**Reversal cost.** Trivial.

## O5 — `settings.json` + a `PreToolUse` hook enforce the test-data and SPEC rules (Tier A → A17)
*Alternatives:* prose rules only (v1.1) · a sandboxed VM · relying on the app-level fence alone.
**Why this one.** §8.6 promised "by construction, not discipline", and v1.1 delivered the construction only on the app side (debug bundle id, `--vault`). On the agent side it was still prose. Claude Code has two mechanical layers: deny rules in `.claude/settings.json`, and hooks. Deny rules are declarative and cheap; hooks run before every tool call — before permission modes, even under `bypassPermissions` — and are the layer Anthropic itself recommends for checks that must never be skipped. The kit uses both. Deny rules cover `Edit`/`Read` of iCloud Drive and the personal folders and `Edit` of `docs/SPEC.md`; `guard-paths.py` blocks any write outside the repo, `$TMPDIR` or `~/Library/Caches/Persona`, any edit of `SPEC.md`, any shell command that mentions iCloud Drive or a personal folder, any `defaults write` that isn't for the `.debug` bundle, and any `rm` on an absolute or home path outside the sandboxed places. The owner's vault can no longer be touched by an agent even by accident, and "SPEC wins" is a file the agent physically cannot edit. `defaultMode: acceptEdits` is set so that *inside* the fence the agent doesn't stop for every file edit — the owner's control is at the decision level (§8.2), not the keystroke level. If the owner prefers per-edit prompts, delete that one line; the fence still holds.
**What would change my mind.** The owner running Claude Code in a container that already cannot see `~/Library` — then the deny rules are redundant (the hook still costs nothing).
**Reversal cost.** Trivial to remove — and removing it re-opens the risk.

## O6 — Session rituals are a SessionStart hook and two skills, not prose
*Alternatives:* the ritual written out in `CLAUDE.md` (v1.1) · slash commands in `.claude/commands/`.
**Why this one.** Two things happen every session: orient at the start, report at the end. Orientation is now a `SessionStart` hook that prints the *Current status* block and the pending proposals — the agent no longer has to remember to look, and it costs ~12 lines. Reporting and proposing are skills (`/report`, `/propose`): a skill's instructions load only when invoked, so the templates live outside the per-turn context; and skills can inject live data with `` !`command` `` (today's date, the current status, the last commits, the next decision id), which removes the most common mistakes — wrong file name, wrong next id, a forgotten tick. `.claude/skills/` is the current mechanism; `.claude/commands/` is the older form of the same thing.
**What would change my mind.** Nothing foreseeable.
**Reversal cost.** Trivial.

## O7 — Three project subagents with tool and path limits (Tier A → A18)
*Alternatives:* no custom subagents, roles described in prose (v1.1) · one general subagent · many specialists.
**Why this one.** §8.5 already wanted a reviewer and a test-writer; v1.1 described them in sentences, which an agent can misread. Claude Code subagents are files with a `tools` allowlist and per-agent hooks, so a role's limits become mechanical: `reviewer` cannot write (its shell is filtered by `read-only-bash.py`), `vault-tester` writes only under `Packages/VaultKit/Tests`, `renderer` writes only under `Design/` and is the *only* agent that sees the Blender MCP — which keeps Blender's tool descriptions out of the main conversation and guarantees no Blender output lands anywhere the owner would see a `.blend`. Three is the number of distinct, recurring, isolatable jobs in the roadmap; a fourth would be invented. The built-in Explore and Plan agents remain for read-only research.
**What would change my mind.** `renderer` going unused because Blender proves unnecessary (D8) — delete it.
**Reversal cost.** Trivial.

## O8 — `PROGRESS.md` is capped at 40 lines; history lives in reports
*Alternatives:* an ever-growing session log (the v1.1 template implied one).
**Why this one.** `PROGRESS.md` is printed at every session start. A log that grows by three lines a session is 300 lines in a year, all of it paid for at every start and none of it needed. The status block plus the last five sessions is what orientation needs; every session's full record is already a report file. `/report` enforces the cap by deleting the sixth-oldest entry.
**Reversal cost.** Trivial.

## O9 — `docs/SPEC.md` is read-only to agents
*Alternatives:* trust.
**Why this one.** "SPEC wins conflicts" only means something if an agent cannot quietly make SPEC agree with the code. A deny rule and the hook make it impossible; the owner edits SPEC, and only the owner.
**Reversal cost.** Trivial.

## O10 — What deliberately did not change
- The content: every argument from v1.1 is carried into its shard or decision file verbatim; nothing was re-decided by the reorganisation.
- The size of the process: `SPEC`, `PROGRESS`, `BACKLOG`, `FORMAT`, the plan shards, the decision files, the reports. No gates, no ledgers, no decision sheets. `.claude/` holds enforcement, not process.
- Make targets, module boundaries, the vault format, the roadmap and its order.
