# Owner decisions (§9)

Answer once — in chat, or by editing this table; the defaults apply until then. These are questions only the owner can answer; the argued architecture and organisation decisions live in `docs/decisions/`.

| ID | Question | Default used by this plan |
|---|---|---|
| D1 | App name and bundle id | **Answered: Persona.** Bundle id `com.<owner>.persona` — owner confirms the domain |
| D2 | Minimum macOS | macOS 26 |
| D3 | Global hotkey; accent colour | `⌥Space`; the agent proposes three accents with screenshots in P2 |
| D4 | Default vault location | `iCloud Drive/Persona` (any folder is allowed, e.g. inside an Obsidian vault) |
| D5 | Distribution | Developer ID + notarised dmg at P9 (needs the owner's Apple Developer membership) |
| D6 | UI language | English; localisation → BACKLOG |
| D7 | First day of the week | Monday (ISO 8601 weeks, as in `docs/FORMAT.md`) |
| D8 | Design tooling (A14 (`docs/decisions/A14-design-tooling.md`)): Figma for screens + SwiftUI Motion Lab for motion + Blender for rendered assets — or Blender for UI as an owner override | The proposal as written in A14 (`docs/decisions/A14-design-tooling.md`) |
| D9 | Where Tier A proposals are answered | The report's "Proposals" list, answered in chat; Figma comments for visual ones |
| D10 | Sample data on first launch | None — the owner's vault starts empty; a "load demo vault" button exists in debug builds only |

Assumptions made: single user; scheduling is day-level (no hours); notes are Markdown text, with images only via `Attachments/`.
