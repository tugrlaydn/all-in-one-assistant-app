# Progress

Keep this file under 40 lines: it is read at the start of every session. History lives in docs/reports/.

## Current status
- Phase: P0 — Bootstrap (code done; owner checks on a Mac pending)
- Next up: owner runs `make gen build test run` + `/doctor` on the Mac; then P1 (VaultKit core)
- Blockers: Figma file — connected account has a View seat only (owner to choose account)
- Owner decisions pending: D1 domain (bundle id `com.tugrlaydn.persona`), D2–D10 (defaults in use)
- Proposals pending ratification: A01–A18 (docs/decisions/) · Tier B to veto: B01

## Session log (newest first, keep the last five)
### Session 1 — 2026-09-28 — [report](reports/2026-09-28-P0-1.md)
- Done: kit moved to root; `.claude/` rebuilt (hooks tested); VaultKit (ULID), DesignKit (tokens,
  HorizonLayout); app shell with placeholder Horizon + menu-bar extra; debug separation; macOS CI.
- Decisions: B01 (debug build separation).
- Next: owner verification on a Mac; P1 starts with the models and the front-matter parser.
