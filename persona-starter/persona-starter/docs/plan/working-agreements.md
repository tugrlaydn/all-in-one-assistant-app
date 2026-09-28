# Working agreements (§8)

### 8.1 The session loop
1. The SessionStart hook has already printed the *Current status* block of `PROGRESS.md` and the pending proposals. Read the current phase file in `docs/plan/phases/` — nothing else unless it points there.
2. Pick the next unticked package. Restate it in one line at the start of the session.
3. Build it. `make build test`. For UI packages: `make run`, then `screencapture -x docs/reports/img/<date>-<package>.png`.
4. Commit.
5. Run `/report`: it writes the two-register report, updates `PROGRESS.md`, and ticks the phase file. Stop — or take the next package if the context is still small.

### 8.2 Decisions — three tiers, the owner on top

| Tier | What | Who decides | How it is recorded |
|---|---|---|---|
| **A** | Anything the owner sees (screens, colours, motion, wording); anything stored (file format, folder layout); anything binding for years (stack, sync, dependencies, distribution); anything that costs money or needs the owner's accounts | **Owner.** The agent proposes in the decision format (`docs/decisions/README.md`) — alternatives, why, what would change it, reversal cost | a file in `docs/decisions/` with `status: proposed`; the owner flips it to `ratified` or `rejected` — by editing the line, or by saying so in chat and letting the agent edit it |
| **B** | Internal engineering: structure inside a package, naming, test strategy, refactors, small dependencies | **Agent**; the owner may veto | One short file with `status: decided`; listed under "you can veto these" in the session report |
| **C** | Line-level implementation | Agent | Not recorded |

Rules: proposals are batched into the report, never scattered through chat. A pending Tier A never blocks — the agent works on something independent. A rejected proposal is re-argued once with the owner's objection addressed, then goes to BACKLOG. Format changes are always Tier A and add-only (§4.5); golden files are regenerated in the same commit, with the reason.

### 8.3 Code rules
- `VaultKit` imports Foundation only. This is the iOS seam, and it is also what keeps the logic testable.
- All colours, fonts, and motion come from `DesignKit`. No literals in views.
- All file I/O goes through `Vault` (coordinated). Views never touch `FileManager`.
- No dependency without a decision file. Prefer none.
- Tests live next to logic. UI is verified by running and looking, not by UI tests — unless something regresses twice, then add one for that.
- Never write to a file the app did not change; never write on a timer; write on user action only.

### 8.4 Report template — `docs/reports/YYYY-MM-DD-<phase>-<n>.md`

```markdown
# Session <n> — <date> — <phase>: <package(s)>

## In plain language
What changed for you, what you can try right now (with the exact keys to press),
what comes next, and anything I need from you. Four to ten sentences, no jargon.

## Proposals — Tier A, need your yes/no
- A-…: decision · alternatives · why · what would change it · reversal cost

## Decided — Tier B, you can veto
- ADR-…: one line each

## Technical detail
- Changes: modules and files, key types, algorithms, trade-offs
- Tests: added / total / result — all run against fixtures, never your vault
- Performance or risk notes
- Screenshots / recordings: docs/reports/img/… (fixture data only)
```

### 8.5 Using several Claude Code agents

Three project subagents live in `.claude/agents/` and are the only ones the primary should spawn for project work (argued in `docs/plan/file-organization.md` O7):

| Agent | Can write to | Use for |
|---|---|---|
| `reviewer` | nothing (read-only, Bash writes blocked by hook) | the review pass before a phase's last commit |
| `vault-tester` | `Packages/VaultKit/Tests/**` only | golden/fuzz/fixture tests, running `swift test` with the noise kept out of the main context |
| `renderer` | `Design/renders/**`, `Design/blender/**` only | Blender MCP renders: icon layers, glyphs, illustrations, motion studies |

- One **primary** session owns `PROGRESS.md`, the ticks in the phase files, and the reports.
- Parallel work only where files don't overlap — for example a subagent writing VaultKit golden and fuzz tests while the primary builds UI. One `git worktree` per agent; merge through the primary.
- The `reviewer` pass before each phase's last commit: build, test, read the diff against SPEC, §8.3 and §8.6, list findings. The primary fixes.
- Never two agents on the same file. Never a subagent writing docs or reports.

### 8.6 Test data never reaches the owner

The owner must be able to use the app without ever seeing a fixture, a sample task, or a stress-test file. This is enforced by construction, not by discipline:

- **The app never reads or writes outside the vault the owner selected.** No sample data is ever written into that vault — not even on first launch; the empty folder skeleton is the only thing created.
- **Agent-side enforcement:** `.claude/settings.json` denies edits outside the repo, `$TMPDIR` and `~/Library/Caches/Persona`, and `.claude/hooks/guard-paths.py` blocks the same at the tool level, including shell commands that mention iCloud Drive or write the real app's defaults (see `docs/plan/file-organization.md` O5).
- **Fixtures are repo files:** `Packages/VaultKit/Tests/Fixtures/` holds committed golden vaults. A test that needs a writable vault copies a fixture into `NSTemporaryDirectory()` and deletes it afterwards.
- **Stress vaults are generated, never committed, never in iCloud:** `make stress-vault N=5000` writes under `~/Library/Caches/Persona/StressVaults/`; `make clean-stress` removes them. They open only through the `--vault <path>` launch argument in a debug build, which shows a red **TEST VAULT** badge in the window title and disables notifications and launch-at-login.
- **Debug builds are a different app to macOS:** bundle id `…persona.debug`, its own UserDefaults suite, its own bookmark storage. A debug run can therefore never change which vault the owner's real build opens, its hotkey, or its settings.
- **Screenshots and recordings in reports come from fixture vaults**, never from the owner's real data.
- **The agent tests against fixtures; the owner tests against real life.** The two never meet, and the owner sees only the app.

*Why this way and not a "demo mode" switch:* a switch inside one app is one bug away from writing demo data into the real vault. Two bundle ids and a launch argument make the mistake impossible rather than unlikely.

### 8.7 A plan that lives as long as the project

- The plan shards in `docs/plan/` are amended, never replaced. New work arrives as new phase files (`phases/P10.md`, `P11.md`, …) in the same format, each ratified by the owner before it starts. Superseded text is struck through, not deleted, so the history of *why* stays readable.
- `BACKLOG.md` is the intake queue. The owner adds ideas at any time; the agent never promotes one to a phase on its own.
- Once a quarter, or whenever the owner asks, the agent writes a "state of the project" report: what shipped, what the owner actually uses, what has gone stale, and three proposals for the next phases — argued, not decided.
- The non-negotiables (§2) change only by the owner editing them.
- The plan's own version number moves only on the owner's instruction; the changelog in `docs/plan/README.md` records what changed and why.
