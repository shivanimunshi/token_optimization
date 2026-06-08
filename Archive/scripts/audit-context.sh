# audit-context.sh — list the largest source files in the repo so the agent
# knows which files MUST be read with line ranges, never whole.
#
# Usage:
#   ./audit-context.sh                  # top 30 files repo-wide (code only)
#   ./audit-context.sh backend/src 50   # custom path + count

set -euo pipefail

ROOT="${1:-.}"
TOP="${2:-30}"

# Code extensions we care about; tweak if needed.
EXTS='\.(ts|tsx|js|jsx|cjs|mjs|json|md|py|sh)$'

echo "Largest source files under ${ROOT} (top ${TOP} by line count):"
echo

# Skip node_modules, build outputs, lockfiles, .git.
find "${ROOT}" \
  -type d \( -name node_modules -o -name dist -o -name build -o -name .git -o -name coverage -o -name .next -o -name .venv \) -prune -o \
  -type f -print 2>/dev/null \
  | grep -E "${EXTS}" \
  | grep -vE '(package-lock\.json|pnpm-lock\.yaml|yarn\.lock)$' \
  | while read -r f; do
      lines=$(wc -l < "$f" 2>/dev/null || echo 0)
      printf '%6d  %s\n' "$lines" "$f"
    done \
  | sort -rn \
  | head -n "${TOP}"

echo
echo "Tip: any file >300 lines should be read with startLine/endLine, not in full."
