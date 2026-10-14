#!/usr/bin/env bash
# Print callers (functions calling SYMBOL) and callees (functions called by SYMBOL).
# Uses cscope (-L3 callers, -L2 callees); falls back to GNU Global references.
# Usage: callers.sh [ROOT] <SYMBOL>   (callers)    callers.sh [ROOT] <SYMBOL> callees
set -euo pipefail

ROOT="${1:-.}"
SYM="${2:-}"
MODE="${3:-callers}"
if [ -z "$SYM" ]; then
  echo "usage: callers.sh [ROOT] <SYMBOL> [callers|callees]" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

if [ -f "$ROOT/cscope.out" ] && command -v cscope >/dev/null 2>&1; then
  case "$MODE" in
    callees) (cd "$ROOT" && cscope -d -L2 "$SYM") && exit 0 ;;
    *)       (cd "$ROOT" && cscope -d -L3 "$SYM") && exit 0 ;;
  esac
fi

if [ -f "$ROOT/GRTAGS" ] && command -v global >/dev/null 2>&1; then
  (cd "$ROOT" && global -x -r "$SYM") && exit 0
fi

echo "code-nav: no cscope index for $ROOT; run scripts/index.sh <ROOT> first." >&2
exit 1
