#!/usr/bin/env bash
# Print all references to a symbol (file:line + context).
# Usage: refs.sh [ROOT] <SYMBOL>
# Does not resolve function-pointer dispatch; use ops.sh / grep for that.
set -euo pipefail

ROOT="${1:-.}"
SYM="${2:-}"
if [ -z "$SYM" ]; then
  echo "usage: refs.sh [ROOT] <SYMBOL>" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

if [ -f "$ROOT/GRTAGS" ] && command -v global >/dev/null 2>&1; then
  (cd "$ROOT" && global -x -r "$SYM") && exit 0
fi

if [ -f "$ROOT/cscope.out" ] && command -v cscope >/dev/null 2>&1; then
  (cd "$ROOT" && cscope -d -L0 "$SYM") && exit 0
fi

echo "code-nav: no index for $ROOT; run scripts/index.sh <ROOT> first." >&2
exit 1
