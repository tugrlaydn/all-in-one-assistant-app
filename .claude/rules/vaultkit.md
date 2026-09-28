---
paths:
  - "Packages/VaultKit/**"
---

# VaultKit rules (§8.3, §4.5, §8.6)
- `import Foundation` only. No AppKit, SwiftUI, Combine or other frameworks. This is the iOS seam.
- All file I/O goes through `Vault`, coordinated with NSFileCoordinator. No FileManager elsewhere.
- Round-trip is byte-identical: parse → serialize of an untouched file returns the same bytes.
  Writing a field changes only that field's lines. Unknown keys, comments and body bytes survive.
- Format changes are Tier A and add-only; regenerate golden files in the same commit, with the reason.
- Tests use committed fixtures in `Tests/Fixtures/`, copied into NSTemporaryDirectory() and deleted
  afterwards. No test touches any other path.
