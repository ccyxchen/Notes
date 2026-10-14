---
name: code-nav
description: "Precise C/C++ code navigation: call chains, definitions, references, function-pointer/ops dispatch. Use for 'who calls X', 'where is X defined', 'trace the call chain/data flow', or finding code across files. Uses clangd/LSP, ripgrep, GNU Global, ctags, cscope; graphify only as a fallback for unknown-symbol navigation."
---

# code-nav

Precise symbol tools first; graph only when the symbol is unknown.

## Tool order

0. **clangd/LSP** — if `compile_commands.json` exists (definition / references / call hierarchy)
1. **`rg`** — exact matches
2. **`global`** — `-x -r` refs, `-d` definition
3. **`readtags`** — definition + signature (`query.sh`)
4. **cscope** — callers/callees (`callers.sh`)
5. **graphify** — navigation only (`query`/`path`/`explain`); its `calls` edges are `INFERRED`

## Scripts (`~/.config/opencode/skills/code-nav/scripts/`)

| Command | Output |
|---|---|
| `index.sh <ROOT>` | build indexes (kernel mode: config-aware) |
| `query.sh <ROOT> <SYM>` | definition: kind, signature, file:line |
| `refs.sh <ROOT> <SYM>` | all references |
| `callers.sh <ROOT> <SYM> [callers\|callees]` | callers / callees |
| `ops.sh <ROOT> <SYM\|--register\|--invoke>` | indirect-dispatch wiring |

## Routing

- Symbol known → precise tools; never graphify.
- Call chain → `callers.sh` + `refs.sh`; never trust graph `calls` edges.
- Indirect (fn ptr / callback / ops / hook) → grep the wiring (below).
- Symbol unknown → `graphify query/explain` to locate, then verify with `rg`.
- Index first if missing: `index.sh <ROOT>`.

## Indirect dispatch (mandatory)

Static call graphs (graphify/gtags/cscope) do NOT resolve function pointers. Also grep:

```
rg -n '\.\w+\s*=\s*SYM\b'     # designated initializer:  .read = SYM
rg -n '->\w+\s*=\s*SYM\b'     # runtime assignment:      ops->cb = SYM
rg -n '=\s*SYM\s*[,;]'        # table/array initializer
```

Kernel:

```
bash scripts/ops.sh <ROOT> <SYM>       # where SYM is wired as a callback
bash scripts/ops.sh <ROOT> --register  # initcall + designated-initializer tables
bash scripts/ops.sh <ROOT> --invoke    # ->f_op-> / ->netdev_ops-> / ...
```

Raw forms:
```
rg -n '\b(module_init|subsys_initcall|fs_initcall|device_initcall|core_initcall|module_platform_driver|module_pci_driver)\s*\('
rg -n -- '->\s*[a-z_]*ops\s*->'
```

Then find the invocation site (`->mod(`) and continue from there. Never report an inferred edge as fact.

## Kernel / large project

`index.sh` detects kbuild (`Kconfig` + `scripts/tags.sh` or `Makefile` `gtags:`/`cscope:`).

- `.config` present → `make gtags` + `make cscope` — config-aware (only built files). No `.tags`; `query.sh` falls back to `global -d`.
- No `.config` → warns, uses list mode.
- Indexing is slow/large; build once.
- Linux scale: graph overviews degrade; SVF/CodeQL need a full per-config bitcode build and reflect only one config. Use config-aware xref + clangd + ops grep.

## Tokens

- Exact symbol > semantic retrieval (few lines vs. noisy subgraph).
- Consult indexes before reading files; read only relevant regions.
- Many hits → narrow by file/glob, keep top-k.
- Verify every reported edge against source.

## Gotchas

- cscope `-L2` / `global -x` list macros as calls (`swap16()`, `CRASHDEBUG()`); filter.
- List mode skips `.git/ gdb*/ graphify-out/ build/ node_modules/ .opencode/`; extend via `CODE_NAV_SKIP`, `CODE_NAV_EXTRA_GLOB`.
- Re-run `index.sh` after large edits.

## Example

```
bash scripts/query.sh   . read_netdump          # netdump.c:761
bash scripts/callers.sh . read_netdump          # read_kdump, handle_connection
bash scripts/ops.sh     . read_diskdump         # pc->readmem = read_diskdump (main.c:627)
```
