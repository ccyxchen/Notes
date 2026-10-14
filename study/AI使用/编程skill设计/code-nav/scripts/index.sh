#!/usr/bin/env bash
# Build precise code-navigation indexes.
#
#   small/medium repo : one filtered file list -> GNU Global + ctags + cscope
#   kernel/large repo : config-aware kbuild targets (make gtags / make cscope)
#
# Usage: index.sh [ROOT]
# Env:   CODE_NAV_SKIP="dir1 dir2"      extra dirs/globs to exclude (list mode)
#        CODE_NAV_EXTRA_GLOB="*.py"     extra file glob to include (list mode)
#        CODE_NAV_FORCE_LIST=1          force file-list mode even in a kernel tree
set -euo pipefail

ROOT="${1:-.}"
ROOT="$(cd "$ROOT" && pwd)"
cd "$ROOT"

FILES="$ROOT/gtags.files"
ABSFILES="$ROOT/cscope.files"

# --- detect a kbuild kernel/large tree (config-aware indexing available) ---
kernel_tree() {
  [ -f "$ROOT/Kconfig" ] || return 1
  [ -f "$ROOT/scripts/tags.sh" ] && return 0
  [ -f "$ROOT/Makefile" ] && grep -qE '^(gtags|cscope):' "$ROOT/Makefile"
}

KERNEL=0
if [ "${CODE_NAV_FORCE_LIST:-0}" != 1 ] && kernel_tree; then
  if [ -f "$ROOT/.config" ]; then
    KERNEL=1
  else
    echo "code-nav: kernel tree detected but no .config — run 'make <defconfig>' first." >&2
    echo "code-nav: falling back to file-list mode (NOT config-aware)." >&2
  fi
fi

if [ "$KERNEL" = 1 ]; then
  # ---- kernel / large project: config-aware kbuild indexes ----
  echo "code-nav: kernel mode (config-aware, kbuild)"
  if command -v gtags >/dev/null 2>&1; then
    make gtags >/dev/null 2>&1 && echo "code-nav: make gtags -> GTAGS/GRTAGS/GPATH" \
      || echo "code-nav: make gtags failed (skipped)" >&2
  fi
  if command -v cscope >/dev/null 2>&1; then
    make cscope >/dev/null 2>&1 && echo "code-nav: make cscope -> cscope.out" \
      || echo "code-nav: make cscope failed (skipped)" >&2
  elif command -v gtags-cscope >/dev/null 2>&1; then
    make gtags-cscope >/dev/null 2>&1 && echo "code-nav: make gtags-cscope -> cscope.out" \
      || echo "code-nav: make gtags-cscope failed (skipped)" >&2
  fi
else
  # ---- small/medium: one filtered file list drives all three indexers ----
  EXCLUDES=(
    '!.git/**'
    '!gdb*/**'
    '!graphify-out/**'
    '!build/**'
    '!node_modules/**'
    '!.opencode/**'
  )
  for d in ${CODE_NAV_SKIP:-}; do EXCLUDES+=("!$d/**"); done
  RG_ARGS=()
  for e in "${EXCLUDES[@]}"; do RG_ARGS+=(-g "$e"); done

  rg --files \
     "${RG_ARGS[@]}" \
     -g '*.{c,h,s,S}' \
     -g '*.{cc,cpp,cxx,hpp,hxx,hh}' \
     ${CODE_NAV_EXTRA_GLOB:+-g "$CODE_NAV_EXTRA_GLOB"} \
     | sort -u > "$FILES"

  if command -v gtags >/dev/null 2>&1; then
    gtags -f "$FILES" && echo "code-nav: gtags -> GTAGS/GRTAGS/GPATH"
  fi
  if command -v ctags >/dev/null 2>&1; then
    ctags -L "$FILES" -o "$ROOT/.tags" \
      --languages=C,C++ \
      --c-kinds=+pxdfgmstuv --c++-kinds=+pxdfgmnstuv \
      --fields=+nKzS --extras=+q \
      && echo "code-nav: ctags -> .tags"
  fi
  if command -v cscope >/dev/null 2>&1; then
    sed "s#^#$ROOT/#" "$FILES" > "$ABSFILES"
    cscope -b -q -i "$ABSFILES" && echo "code-nav: cscope -> cscope.out"
  fi

  printf 'code-nav: indexed %s files under %s\n' "$(wc -l < "$FILES" | tr -d ' ')" "$ROOT"
fi

# --- compiler-grade semantic index hint (both modes) ---
if [ -f "$ROOT/compile_commands.json" ]; then
  echo "code-nav: compile_commands.json found — prefer opencode LSP (clangd) for"
  echo "          definition/references/call-hierarchy (config-aware, compiler-grade)."
fi
