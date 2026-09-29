# Persona — handoff for the next agent (as of 2026-09-29)

Written at the owner's request so a new agent can continue with no other context. Read this once,
then follow `CLAUDE.md` and the session loop in `docs/plan/working-agreements.md` §8.1. Where this file
and a plan document disagree, the plan document wins (`docs/SPEC.md` wins over everything); this file is
a snapshot, not a source of rules.

---

## 1. What Persona is (one paragraph)

A personal **macOS-only** SwiftUI app for one owner: notes, tasks (with subtasks) and habits (five fixed
categories with weekly budgets and nudges), laid out on a horizontal calendar called **the Horizon**, with a
Spotlight-style **Quick Input** panel (`⌥Space`, one-line grammar) and a JSON-Canvas **Vault view**. The only
truth is a folder of **Markdown files with YAML front matter** in the owner's iCloud Drive (the *vault*); the
app never uses a database as truth and never rewrites what it did not change. Requirements, verbatim from the
owner: `docs/SPEC.md` (agents may never edit it). Plan map: `docs/plan/README.md`.

## 2. Where things stand

| Phase | Status |
|---|---|
| P0 Bootstrap | Code done, CI green. Owner-side checks on a real Mac not done (nobody has launched the app by hand; `/doctor` not run on a Mac). Figma package not done (see §7). |
| P1 VaultKit core | **Done.** All 7 packages; reviewer pass done, all 15 findings handled. |
| P2 App shell + Horizon | **In progress.** Non-visual part done (open/remember/watch the vault). Every remaining item needs ratified **Figma frames**, which the owner has paused. |
| P3–P9 | Not started. |

- **All proposals A01–A18 are ratified** (2026-09-29, owner said "ratify all"). Tier B records B01–B03 are on
  file (owner may veto). No proposals are pending.
- **Owner decisions still open:** D1 domain (bundle id currently `com.tugrlaydn.persona`), D2–D10 use the
  defaults in `docs/plan/owner-decisions.md`.
- **Latest CI:** macOS 26 runner — app tests 12/12, VaultKit 102/102, DesignKit 7/7, `make vault-dump` OK
  (run 13, commit `f047df4`; the report commit after it touches only docs).
- **Branch:** all work is on `claude/gracious-gauss-bghnd0` in `tugrlaydn/all-in-one-assistant-app`. No PR
  has been opened (the owner has not asked for one).

## 3. How the owner works (important)

- **The owner stays in the cloud** and does not run the app on a Mac. The macOS GitHub Actions runner is
  the only Mac. Treat a CI run as the build/test gate for all app and SwiftUI code.
- The owner said: *"continue without me"* and *"do not start Figma now"*. Don't create Figma files or ask
  about Figma unless the owner raises it; do say plainly in reports that P2's screens are blocked on it.
- The owner answers decisions in chat ("ratify all"); the agent then edits the decision files.
- Every session ends with a two-register report (plain language first, then technical) in `docs/reports/`,
  an updated `docs/PROGRESS.md` (≤40 lines) and ticked phase file. SPEC requires this.

## 4. Rules that bind every change (short form — full text in CLAUDE.md and the plan)

- macOS only. No iOS/iPadOS code, targets, `#if os(iOS)` or plans.
- **Tier A** (anything the owner sees, stores, lives with for years or pays for) needs a ratified proposal
  (`/propose` → `docs/decisions/A19-…`). **Tier B** (internal engineering): decide, write one short
  `docs/decisions/B04-…` file, list it in the report for veto. Tier C: just do it.
- No new dependency, no new format key, no new doc or process without a ratified proposal. Ideas outside
  SPEC go to `docs/BACKLOG.md`.
- **VaultKit imports Foundation only.** All file I/O goes through `Vault` / `FileAccess` (coordinated).
  Round-trip stays byte-identical. Colours, fonts, spacing, motion only from DesignKit.
- Never write a file the app did not change; never write on a timer.
- **Test data never reaches the owner (§8.6):** fixtures live in `Packages/VaultKit/Tests/Fixtures/`; tests
  copy them into the temp directory; the debug build is a separate app (`…persona.debug`); `--vault <path>`
  only in debug builds, with a red TEST VAULT badge; a test vault is never remembered.
- **No screen is built before its Figma frame is ratified** (P2 onward, A14).
- One package → one commit with a conventional message (`feat(vault): …`, `fix(app): …`, `docs(report): …`).

## 5. Architecture and code map

Three modules (A04): **App** (macOS, SwiftUI + AppKit), **VaultKit** (Foundation only — the iOS seam),
**DesignKit** (identity tokens). The Xcode project is generated from `project.yml` by XcodeGen (A03); never
hand-edit `Persona.xcodeproj` (it's gitignored).

### VaultKit (`Packages/VaultKit/Sources/VaultKit/`)
| File | What it does |
|---|---|
| `ULID.swift` | 128-bit ids, Crockford base32, string order = creation order. |
| `Document/Line.swift` | Splits text into lines keeping exact terminators (works on UTF-8 bytes; `\r\n` is one Swift Character). |
| `Document/MarkdownDocument.swift` | BOM + front matter + body; `text(parse(x)) == x` for any input; invalid UTF-8 refused (`init?(data:)` uses `String(validating:as:)` because `String(data:encoding:)` can drop a BOM). |
| `Document/FrontMatter.swift` | Reads the YAML subset (scalars w/ comments & quotes, flow/block lists, one-level maps, block scalars). `set(key, value, as:)` rewrites only that key's lines, keeps indentation, comment column, list style, CRLF; `setMapValue` edits one map line. `KeyLine` does the line surgery. |
| `Document/YAMLScalar.swift` | Comment splitting, unquoting, flow splitting, quoting rules (`.text` quotes anything YAML would read as non-string, incl. `20:00` which YAML 1.1 reads as base-60). |
| `Values/Day.swift` | `Day` (YYYY-MM-DD, Hinnant algorithms, clamped to years 1–9999, overflow-safe) and `ISOWeek` (`2026-W40`, Monday start). |
| `Values/Timestamp.swift` | ISO 8601 with the *written* UTC offset kept; `day` uses that offset. `TimeOfDay` (`"12:30"`). |
| `Values/MarkdownText.swift` | `WikiLink` (`[[T#h|alias]]`), `Estimate` (`45m`, `1h30m`, max 1000 h), inline `#tag` and link extraction that skips code. |
| `Models/VaultItem.swift` | `ItemKind`, `VaultItem` protocol (models are *views over their document*), `DocumentBacked` edit helpers, `MarkdownSection` (headings outside fenced code). Every model keeps `loadedDocument` (bytes it was read from) for conflict refusal. |
| `Models/Note.swift`, `TaskItem.swift`, `Habits.swift` | Note; TaskItem with subtask tree (`## Subtasks` checklist, any depth, one-character ticks, `addSubtask`); Habit; HabitCategories (`Habits/Categories.md`, budgets + nudge times); HabitWeek (`## Log` table, follows the table's own column order). `.new(...)` writes FORMAT keys in FORMAT order, never empty optional keys. |
| `QuickInput/QuickInputParser.swift` | Grammar §5: `t/n/h` prefixes, `/command`, `@today @tom @mon…@sun @YYYY-MM-DD @+Nd`, `@due:`, `#tag`, `!1-3`, `~45m`, `>Parent title`, `[[links]]`; returns fields + token ranges for chips. Never eats unknown text; first date/priority/estimate/parent wins. |
| `Index/IndexEntry.swift`, `VaultIndex.swift` | Per-file summary (kind, id, title, tags, links, parent, Horizon days, status/category, habit log rows, mtime/size). Index maps by id/title/tag/link/day, backlinks, `resolve(link)`, `items(on:)`, `density(in:)`, fuzzy `search`. Duplicate ids (iCloud conflict copies) handled. `IndexCache` = `.persona/index.json` (versioned, never truth). |
| `Index/FuzzyMatcher.swift` | Subsequence match, case/diacritic-insensitive, word-start/run/prefix bonuses. |
| `Index/VaultSummary.swift` | Text summary printed by `vaultctl`. |
| `Vault/FileAccess.swift` | `FileAccess` protocol; `CoordinatedFileAccess` uses `NSFileCoordinator` on macOS and direct I/O on Linux (B02). Key call: `write(_:to:ifCurrentContentsAre:)` = compare-and-write in one coordinated access (nil = create only). `ReadOnlyFileAccess` refuses all writes. iCloud `.X.md.icloud` stubs count as `X.md`. |
| `Vault/FileName.swift` | Slugs (only `/ \ : * ? " < > \| # ^ [ ]` + control chars → `-`, 200-byte cap, `Untitled`), `-2/-3` collisions ignoring case and Unicode normalisation, `matches` keeps numbered names. |
| `Vault/Vault.swift` | `actor Vault`: `createSkeleton` (folders only), `load(useCache:)`, `rescan()`, `refresh(paths)`, `document/item/categories`, `save(item, at:)` → `Saved<T>` (unchanged → no write; note/task get `updated`; compare-and-write against `loadedDocument` else `changedOnDisk`; rename only when the title changed; creates never overwrite; `notLoaded` guard), `save(categories)`, `writeCache` (only when changed, never from the watcher), `readOnly:` mode. Paths can't leave the vault. |
| `Vault/VaultWatcher.swift` | `actor VaultWatcher`: polls `rescan()`, streams changed paths, `nudge(paths)` for event sources; generation-safe restart. |
| `Sources/vaultctl/main.swift` | `vaultctl <folder> [--rebuild]` — read-only summary. |

### App (`App/`, `AppTests/`)
| File | What it does |
|---|---|
| `App/PersonaApp.swift` | `Window` + `MenuBarExtra`; owns `VaultSession`; `.task { openOnLaunch }`; menu **File → Choose Vault…** (⇧⌘O). |
| `App/MainWindow.swift` | Placeholder Horizon; subtitle = vault name + file count; TEST VAULT badge. |
| `App/BuildFlavor.swift`, `LaunchOptions.swift` | Debug/release separation check (B01); `--vault` parsing (debug only). |
| `App/VaultBookmarkStore.swift` | Security-scoped bookmark in the app's own defaults; injectable for tests. |
| `App/FolderEvents.swift` | FSEvents (CoreServices) → vault-relative paths → `VaultWatcher.nudge` (B03). |
| `App/VaultSession.swift` | `@MainActor @Observable`: open test vault → remembered vault → none; `open` (security scope, skeleton, load, watch with 10 s polling + FSEvents), `close`, `chooseVault` (`NSOpenPanel`, starts in iCloud Drive/Persona). |
| `Horizon/HorizonPlaceholderView.swift` | Seven static columns via `DesignKit.HorizonLayout` — placeholder until Figma. |
| `AppTests/*` | Hosted Swift Testing tests (run inside the sandboxed debug app; temp folders only; throwaway defaults suites). |

### DesignKit (`Packages/DesignKit/`)
`Palette` (system-colour placeholders; real accent/kind colours are Tier A, from Figma in P2), `Typography`,
`Spacing`, `Motion` (quick 0.25 s / settle 0.45 s springs, Reduce Motion → crossfade; final numbers come from
the Motion Lab), `HorizonLayout.columnWidths` (pure maths, tested).

### Tests and fixtures
- VaultKit: 102 tests — document round-trip + 200-file fuzz, golden edits (`Tests/Fixtures/Golden/`), fixture
  vault `Tests/Fixtures/Vaults/Basic` (every file type, a CRLF plain Obsidian note, unknown keys), 61-row grammar
  table, index, Vault (on temp copies), watcher timing, review regressions. `.gitattributes` keeps fixture
  bytes exact.
- App: 12 tests (launch options, build flavour, bookmark store, session open/watch/reopen).
- DesignKit: 7 tests.

## 6. Tooling in this cloud container (read before running anything)

- **No Swift or Xcode on the host.** VaultKit (and any Foundation-only code) is compiled and tested in Docker:
  image `swift:6.2-noble`. The daemons do not survive container restarts; start them like this (a stale
  `/var/run/docker.pid` breaks the default start):
  ```sh
  pgrep -x containerd >/dev/null || (containerd > /tmp/claude-0/containerd.log 2>&1 &)
  pgrep -x dockerd >/dev/null || (dockerd --pidfile /tmp/claude-0/dockerd.pid \
      --containerd=/run/containerd/containerd.sock > /tmp/claude-0/dockerd.log 2>&1 &)
  docker image inspect swift:6.2-noble >/dev/null 2>&1 || docker pull -q swift:6.2-noble
  docker run --rm -v "$PWD/Packages/VaultKit":/src:ro swift:6.2-noble \
      sh -c 'cp -r /src /tmp/w && cd /tmp/w && swift test 2>&1' | grep -E "error:|✘|Test run with"
  ```
  Use paths under `/tmp/...` *inside* the container command — the guard hook reads `sh -c` strings and blocks
  absolute paths outside the repo/tmp.
- **SwiftUI/AppKit/CoreServices code cannot compile here.** Push and read the macOS CI result (GitHub MCP:
  `mcp__github__actions_list` → `list_workflow_runs` / `list_workflow_jobs`, `mcp__github__get_job_logs` with
  the job id). `make test-app` prints an xcresult summary (`passedTests`, `failedTests`) near the end of the
  log — check it, "green" alone doesn't prove tests ran. `-quiet` hides per-test lines.
- **CI:** `.github/workflows/ci.yml` on `macos-26`: `brew install xcodegen`, `make gen build test`,
  `make vault-dump`. `concurrency: cancel-in-progress` — pushing again cancels the previous run.
- **Guard hooks (`.claude/`, A17) are live in this session:**
  - Writes outside the repo, `$TMPDIR`, `/tmp` and `~/Library/Caches/Persona` are blocked; so is any edit of
    `docs/SPEC.md`.
  - **Any Bash command that mentions iCloud Drive / "Mobile Documents" / personal folders is blocked — this
    includes `git commit -m "…"` messages.** Write commit messages to a scratchpad file with the Write tool and
    use `git commit -F <file>`.
  - Lesson learned: when adding a hook, write the script *before* the settings entry that calls it — settings
    hot-reload and a missing script blocks every tool.
- Subagents: `reviewer` (read-only; used for the P1 review pass — very effective), `vault-tester`
  (writes only under `Packages/VaultKit/Tests`), `renderer` (Blender; unused).
- Commit trailers the environment asks for:
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` and
  `Claude-Session: https://claude.ai/code/session_01WEPc4EPDXaFEbjmv5mBSfY` (a new session will be given its
  own values in a system reminder — use those).

## 7. What to do next

1. **P2 screens are blocked on Figma.** P2 package 1 is "Figma frames for the main window and the Horizon in
   three accent options, ratified before any SwiftUI work". The connected Figma account (`tugrl.aydn2`) had
   only a *View* seat in session 1. The owner has paused Figma — wait for them to reopen it; don't build
   Horizon screens meanwhile.
2. **Work that does not need Figma** (only if the owner asks for progress while Figma waits — confirm
   scope first, and respect phase order in `docs/plan/README.md` §7):
   - P2 inspector/detail layout needs a decision file (P2 says "agent decides, records a decision file") —
     but it is a screen, so it still waits for frames.
   - P3's `QuickInputParser` already exists; the panel UI, `⌥Space` Carbon hotkey (A09) and the save path
     (parse → `TaskItem.new` / `Note.new` / `HabitWeek.appendLog` → `Vault.save`) are P3 work. The *logic*
     glue (resolving `>Parent` and `h swim` via `VaultIndex.search`, choosing the week file, creating it if
     missing) is Foundation-only and testable now — but P3 comes after P2 in the fixed order, so ask first.
   - Known follow-ups recorded in reports: link rewriting when a title changes (P4/P5), conflict merging (P8),
     measuring cache/polling cost with 5000 files (P8), `make stress-vault`/`clean-stress` (P8), `dist` (P9).
3. **Owner-side checks still open:** first real launch on a Mac (`make gen build test run`), `/doctor`,
   choosing a real iCloud folder through the panel (the security-scoped bookmark path is untested by
   automation), D1 bundle domain.

## 8. History in one screen

- **Session 1 (P0):** flattened the uploaded kit to the repo root; rebuilt the missing `.claude/` from A17/A18
  (and briefly locked the session out by enabling settings before the hook script existed — fixed with the
  owner's go-ahead); VaultKit/DesignKit/app skeleton; debug separation (B01); macOS CI. Report:
  `docs/reports/2026-09-28-P0-1.md`.
- **Session 2 (P1):** document layer, models, grammar, index, Vault, watcher, vaultctl; reviewer subagent found
  15 issues (typed-input crashes, a compare/write race, renames on unrelated edits, cache writes on the timer,
  watcher restart, code-fence parsing, …) — all code findings fixed with regression tests. B02, B03. Report:
  `docs/reports/2026-09-28-P1-1.md`.
- **Session 3 (P2, non-visual):** owner ratified A01–A18; grammar details and slug rules written into
  `grammar.md` and FORMAT §4.1; `VaultBookmarkStore`, `FolderEvents`, `VaultSession`, File → Choose Vault….
  Report: `docs/reports/2026-09-29-P2-1.md`.

## 9. Start-of-session checklist for the next agent

1. `git fetch origin claude/gracious-gauss-bghnd0 && git status` — work on that branch.
2. Read `CLAUDE.md`, the SessionStart output, `docs/PROGRESS.md`, then `docs/plan/phases/P2.md`.
3. Check the latest CI run is green before building on it.
4. Restart Docker (§6) if you'll touch VaultKit.
5. Restate the next package in one line; build; test (Docker and/or CI); commit; push; confirm CI; `/report`.
