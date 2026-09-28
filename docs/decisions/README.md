# Decisions — one file each, status in frontmatter

Format of every file: YAML frontmatter (`id`, `title`, `tier`, `status`, `proposed`, `ratified`, `owner_note`) then the argument: **Alternatives · Why this one · What would change my mind · Reversal cost**.

Status values: `proposed` → `ratified` | `rejected` (Tier A: only the owner flips it) · `decided` (Tier B: the agent decides, the owner may veto by setting `rejected`).

Pending list at any time: `grep -l '^status: proposed' docs/decisions/*.md` — the SessionStart hook prints it.

New Tier A proposal: `/propose <title>` creates the next `A##-<slug>.md`. Tier B records use `B##-<slug>.md` with `status: decided`.

| # | Decision | Tier | Status |
|---|---|---|---|
| A01 | [Swift 6 + SwiftUI, with AppKit where SwiftUI falls short](A01-swift-swiftui-appkit.md) | A | proposed |
| A02 | [macOS 26 minimum](A02-macos-26-minimum.md) | A | proposed |
| A03 | [XcodeGen owns the project file](A03-xcodegen-project-file.md) | B | proposed |
| A04 | [Three modules](A04-three-modules.md) | A | proposed |
| A05 | [The vault is a user-chosen folder in iCloud Drive; no CloudKit](A05-vault-folder-icloud-drive.md) | A | proposed |
| A06 | [In-memory index with a JSON cache; no database](A06-in-memory-index.md) | B | proposed |
| A07 | [Our own front-matter parser with byte-identical round-trip](A07-own-parser-round-trip.md) | A | proposed |
| A08 | [NSTextView editor; no WYSIWYG](A08-nstextview-editor.md) | A | proposed |
| A09 | [Carbon `RegisterEventHotKey` for the global shortcut](A09-carbon-hotkey.md) | B | proposed |
| A10 | [`UNUserNotificationCenter` with actionable, text-input notifications](A10-notification-actions.md) | B | proposed |
| A11 | [JSON Canvas 1.0 for the Vault view](A11-json-canvas.md) | A | proposed |
| A12 | [Zero dependencies to start](A12-zero-dependencies.md) | B | proposed |
| A13 | [Developer ID + notarised dmg; not the App Store](A13-developer-id-dmg.md) | A | proposed |
| A14 | [Design tooling — Figma for screens, SwiftUI for motion, Blender for rendered assets](A14-design-tooling.md) | A | proposed |
| A15 | [Vault format shape — one file per item, subtasks inline, week files, budgets in the vault](A15-vault-format-shape.md) | A | proposed |
| A16 | [Quick Input grammar — prefix letters, symbol tokens, never eat unknown text](A16-quick-input-grammar.md) | A | proposed |
| A17 | [Agent guardrails — settings.json deny rules, PreToolUse path guard, acceptEdits inside the repo](A17-agent-guardrails.md) | A | proposed |
| A18 | [Three project subagents (reviewer, vault-tester, renderer) with tool and path limits](A18-project-subagents.md) | A | proposed |
| B01 | [Debug build separation: own bundle id, launch-time check, caches-only sandbox exception](B01-debug-build-separation.md) | B | decided |
| B02 | [Coordinated file I/O with a direct fallback where coordination does not exist](B02-coordinated-io-linux-fallback.md) | B | decided |
