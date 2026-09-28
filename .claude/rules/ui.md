---
paths:
  - "App/**"
  - "Packages/DesignKit/**"
---

# UI rules (§6, A14, §8.3, §8.6)
- Colours, fonts, spacing and motion come only from DesignKit tokens. No literals in views.
- A screen is built only after its Figma frame is `ratified` in Design/FIGMA.md (P2 onward).
- Motion numbers live only in `DesignKit.Motion`; they come from the Motion Lab. Reduce Motion → crossfade.
- Views never touch FileManager; they go through VaultKit's `Vault`.
- Debug builds are a separate app: bundle id `…persona.debug`, own defaults, own bookmarks. Only
  debug builds accept `--vault <path>`, and they show a red TEST VAULT badge when they do.
- No iOS code, targets or `#if os(iOS)`.
- Every UI package ships with a screenshot from a fixture vault in its report.
