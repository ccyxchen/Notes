#!/usr/bin/env bash
# Find kernel-style indirect dispatch ("ops struct" wiring and invocation).
# Static call-graph tools (graphify/gtags/cscope) do NOT resolve these.
#
#   ops.sh <ROOT> <SYMBOL>     where SYMBOL is wired as a callback / ops member
#   ops.sh <ROOT> --register   all callback registration sites (designated inits)
#   ops.sh <ROOT> --invoke     all ops-struct invocation sites
set -euo pipefail

ROOT="${1:-.}"
ARG="${2:-}"
if [ -z "$ARG" ]; then
  echo "usage: ops.sh <ROOT> <SYMBOL|--register|--invoke>" >&2
  exit 2
fi
ROOT="$(cd "$ROOT" && pwd)"

GLOBS=(-g '!{.git,gdb*,graphify-out,build,node_modules}/**' -g '*.{c,h}')

case "$ARG" in
  --register)
    rg -n --no-heading \
      -e '\.\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*[A-Za-z_][A-Za-z0-9_]*\s*,' \
      -e '\b(module_init|module_exit|subsys_initcall|fs_initcall|device_initcall|core_initcall|postcore_initcall|arch_initcall|late_initcall|module_platform_driver|module_pci_driver|module_usb_driver)\s*\(' \
      "${GLOBS[@]}" "$ROOT"
    ;;
  --invoke)
    rg -n --no-heading \
      -e '->\s*[a-z_]*ops\s*->' \
      -e '->\s*(f_op|i_op|i_fop|a_ops|d_op|s_op|vm_ops|netdev_ops|ethtool_ops|proto_ops)\s*->' \
      "${GLOBS[@]}" "$ROOT"
    ;;
  *)
    SYM="$ARG"
    rg -n --no-heading \
      -e "\.\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*${SYM}\b" \
      -e "->\s*[A-Za-z_][A-Za-z0-9_]*\s*=\s*${SYM}\b" \
      -e "=\s*${SYM}\s*[,;]" \
      "${GLOBS[@]}" "$ROOT"
    ;;
esac
