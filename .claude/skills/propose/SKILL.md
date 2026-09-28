---
name: propose
description: Create a Tier A proposal file in docs/decisions/ with the full argument (alternatives, why, what would change my mind, reversal cost). Use for anything the owner sees, stores, lives with for years or pays for.
disable-model-invocation: true
argument-hint: <short title>
---

Today: !`date +%Y-%m-%d`
Highest existing Tier A id: !`ls docs/decisions/ | grep -o '^A[0-9]*' | sort -V | tail -n 1`

Title: $ARGUMENTS

1. The new id is the next A-number after the one above (two digits: A19, A20, …).
2. Create `docs/decisions/A<nn>-<kebab-slug>.md`:

```markdown
---
id: A<nn>
title: "<title>"
tier: A
status: proposed
proposed: <today>
ratified:
owner_note:
---

# A<nn> — <title>

*Alternatives:* <each real alternative, one clause each>.
**Why this one.** <the argument, in plain language first, then the technical reason>
**What would change my mind.** <the concrete evidence that would reverse it>
**Reversal cost.** <what undoing it would take>
```

3. Add a row to the table in `docs/decisions/README.md`, and in `docs/plan/architecture.md` when it
   is architectural.
4. Do not build anything that depends on it until the owner sets `status: ratified`. List it in
   this session's report under Proposals.
