# Progress

Keep this file under 40 lines: it is read at the start of every session. History lives in docs/reports/.

## Current status
- Phase: P2 — App shell + Horizon (not started). P1 done; P0 code done.
- Next up: P2 packages that need no screen design (bookmark store, FSEvents → `VaultWatcher.nudge`);
  every screen waits for ratified Figma frames — the owner deferred Figma for now.
- Blockers: Figma frames for P2 screens (owner deferred); owner works from the cloud, so macOS CI is
  the only Mac check (app never launched by a person yet).
- Owner decisions pending: D1 domain (bundle id `com.tugrlaydn.persona`), D2–D10 (defaults in use)
- Proposals: A01–A18 ratified 2026-09-29 (owner: "ratify all"), incl. P1's grammar/file-name choices.
  Tier B on record (owner may veto): B01, B02, B03.
- Agent tooling: Swift 6.2 via Docker for VaultKit tests (see report P1-1); CI on macos-26 for all.

## Session log (newest first, keep the last five)
### Session 2 — 2026-09-28 — [report](reports/2026-09-28-P1-1.md)
- Done: all P1 packages — byte-identical front-matter document + fuzz, models + golden files,
  Quick Input parser (61-row table), index + cache, Vault (coordinated, conflict-refusing saves),
  watcher, vaultctl/`make vault-dump`; reviewer pass: 15 findings, all code findings fixed.
- Decisions: B02 (coordinated I/O, Linux fallback; bookmark → P2), B03 (watcher polling + nudges).
- Next: P2 non-visual packages; owner ratifies A05–A07, A15, A16.

### Session 1 — 2026-09-28 — [report](reports/2026-09-28-P0-1.md)
- Done: kit moved to root; `.claude/` rebuilt (hooks tested); VaultKit (ULID), DesignKit (tokens,
  HorizonLayout); app shell with placeholder Horizon + menu-bar extra; debug separation; macOS CI.
- Decisions: B01 (debug build separation).
- Next: owner verification on a Mac; P1 starts with the models and the front-matter parser.
