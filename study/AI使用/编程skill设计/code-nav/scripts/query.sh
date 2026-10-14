#!/usr/bin/env bash
# Print the definition(s) of a symbol: kind, signature, file:line.
# Prefers readtags (.tags) for precise output; falls back to GNU Global.
# Usage: query.sh [ROOT] <SYMBOL>
set -euo pipefail

ROOT="${1:-.}"
SYM="${2:-}"
if [ -z "$SYM" ]; then
  echo "usage: query.sh [ROOT] <SYMBOL>" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

if [ -f "$ROOT/.tags" ] && command -v readtags >/dev/null 2>&1; then
  readtags -t "$ROOT/.tags" -e -n - "$SYM" && exit 0
fi

if [ -f "$ROOT/GTAGS" ] && command -v global >/dev/null 2>&1; then
  (cd "$ROOT" && global -d "$SYM") && exit 0
fi

echo "code-nav: no index for $ROOT; run scripts/index.sh <ROOT> first." >&2
exit 1
