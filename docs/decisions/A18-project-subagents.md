---
id: A18
title: "Three project subagents (reviewer, vault-tester, renderer) with tool and path limits"
tier: A
status: proposed
proposed: 2026-09-28
ratified:
owner_note:
---

# A18 — Three project subagents

Argued in `docs/plan/file-organization.md`, O7. Summary: `reviewer` is read-only (its Bash cannot write), `vault-tester` can write only under `Packages/VaultKit/Tests`, `renderer` can write only under `Design/renders` and `Design/blender` and is the only agent with the Blender MCP. Each limit is a hook, not a sentence. No other project subagents are defined; the built-in Explore/Plan stay available for read-only research.

**What would change my mind.** The `renderer` never being used — delete it when Blender turns out unnecessary.
**Reversal cost.** Trivial.
