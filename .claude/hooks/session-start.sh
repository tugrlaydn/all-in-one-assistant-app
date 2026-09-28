#!/bin/sh
# SessionStart hook (file-organization.md O6): print the current status and the
# pending proposals so every session starts oriented. Read-only.
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0

echo "== Persona — current status (docs/PROGRESS.md) =="
awk '/^## Current status/{on=1; next} /^## /{on=0} on && NF' docs/PROGRESS.md 2>/dev/null

echo
echo "== Proposals waiting for the owner (status: proposed) =="
found=0
for f in docs/decisions/A*.md; do
  [ -f "$f" ] || continue
  grep -q '^status: proposed' "$f" || continue
  title=$(sed -n 's/^title: *"\{0,1\}\(.*[^"]\)"\{0,1\} *$/\1/p' "$f" | head -n 1)
  echo "- $(basename "$f" | cut -d- -f1): $title"
  found=1
done
[ "$found" -eq 1 ] || echo "- none"

phase=$(sed -n 's/^- Phase: *\(P[0-9]*\).*/\1/p' docs/PROGRESS.md 2>/dev/null | head -n 1)
[ -n "$phase" ] && printf '\nNext read: docs/plan/phases/%s.md\n' "$phase"
exit 0
