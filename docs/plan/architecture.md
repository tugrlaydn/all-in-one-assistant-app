# Architecture (§3)

Every decision is argued in its own file under `docs/decisions/` (format: *Alternatives* · **Why this one** · **What would change my mind** · **Reversal cost**). Every one starts as **proposed**; the owner ratifies or rejects. Nothing here is a given. The table is the index; the arguments are in the files.

| # | Decision | Tier | Status |
|---|---|---|---|
| A01 | [Swift 6 + SwiftUI, with AppKit where SwiftUI falls short](../decisions/A01-swift-swiftui-appkit.md) | A | proposed |
| A02 | [macOS 26 minimum](../decisions/A02-macos-26-minimum.md) | A | proposed |
| A03 | [XcodeGen owns the project file](../decisions/A03-xcodegen-project-file.md) | B | proposed |
| A04 | [Three modules](../decisions/A04-three-modules.md) | A | proposed |
| A05 | [The vault is a user-chosen folder in iCloud Drive; no CloudKit](../decisions/A05-vault-folder-icloud-drive.md) | A | proposed |
| A06 | [In-memory index with a JSON cache; no database](../decisions/A06-in-memory-index.md) | B | proposed |
| A07 | [Our own front-matter parser with byte-identical round-trip](../decisions/A07-own-parser-round-trip.md) | A | proposed |
| A08 | [NSTextView editor; no WYSIWYG](../decisions/A08-nstextview-editor.md) | A | proposed |
| A09 | [Carbon `RegisterEventHotKey` for the global shortcut](../decisions/A09-carbon-hotkey.md) | B | proposed |
| A10 | [`UNUserNotificationCenter` with actionable, text-input notifications](../decisions/A10-notification-actions.md) | B | proposed |
| A11 | [JSON Canvas 1.0 for the Vault view](../decisions/A11-json-canvas.md) | A | proposed |
| A12 | [Zero dependencies to start](../decisions/A12-zero-dependencies.md) | B | proposed |
| A13 | [Developer ID + notarised dmg; not the App Store](../decisions/A13-developer-id-dmg.md) | A | proposed |
| A14 | [Design tooling — Figma for screens, SwiftUI for motion, Blender for rendered assets](../decisions/A14-design-tooling.md) | A | proposed |
| A15 | [Vault format shape — one file per item, subtasks inline, week files, budgets in the vault](../decisions/A15-vault-format-shape.md) | A | proposed |
| A16 | [Quick Input grammar — prefix letters, symbol tokens, never eat unknown text](../decisions/A16-quick-input-grammar.md) | A | proposed |
| A17 | [Agent guardrails — settings.json deny rules, PreToolUse path guard, acceptEdits inside the repo](../decisions/A17-agent-guardrails.md) | A | proposed |
| A18 | [Three project subagents (reviewer, vault-tester, renderer) with tool and path limits](../decisions/A18-project-subagents.md) | A | proposed |

Repository layout:

```
persona/
  CLAUDE.md                 # ≤60 lines: pointers and hard rules, loaded every session
  .claude/
    settings.json           # permissions (allow / ask / deny) + hooks — the deterministic guardrails
    hooks/                  # guard-paths.py (PreToolUse), session-start.sh, read-only-bash.py, limit-writes.py
    agents/                 # reviewer.md, vault-tester.md, renderer.md
    skills/                 # report/, propose/ — the two session rituals, loaded only when invoked
    rules/                  # vaultkit.md, ui.md — path-scoped rules, loaded only when those files are touched
  Makefile                  # gen build test run format vault-dump stress-vault clean-stress dist
  project.yml               # XcodeGen
  App/
    App/                    # PersonaApp.swift, AppState, Settings
    Horizon/  QuickInput/  Notes/  Tasks/  Habits/  Canvas/  MenuBar/  MotionLab/
    Resources/
  Packages/
    VaultKit/               # models, format, parser, index, watcher, grammar, pace engine (Foundation only)
      Tests/Fixtures/       # committed golden vaults — the only test data in the repo
    DesignKit/              # tokens, components, motion
  Design/
    FIGMA.md                # link to the Figma file; which frame is ratified for which screen
    blender/                # .blend sources (agent-facing)
    renders/                # scratch renders (gitignored); ratified assets are copied into App/Resources
  docs/
    SPEC.md                 # the owner's requirements, verbatim — agents cannot edit it
    PROGRESS.md             # ≤40 lines: current status + last five sessions
    BACKLOG.md              # intake queue
    FORMAT.md               # the vault format + its change log
    plan/                   # README.md (map + protocol), product.md, architecture.md, grammar.md,
                            # working-agreements.md, owner-decisions.md, file-organization.md, phases/P0..P9.md
    decisions/              # README.md index + one file per decision, status in frontmatter
    reports/                # YYYY-MM-DD-Pn-k.md + img/
```
