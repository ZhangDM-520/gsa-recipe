---
permalink: gsa-recipe/agents
title: AGENTS
type: note
---

# AGENTS.md — the recipe half of `gsa`, and how to work in it

Last reviewed: 2026-11-18. This is the agent-facing README: the mental model, the commands, the rule and pitfall index, and how to work here. Durable memory — measurements, campaign history, owner rulings, the rule/pitfall bodies and the incident record — lives outside this public repository in the maintainer's private warehouse, and never in a tracked file.

## 0 · What this repository is

`gsa-recipe` is the **data half** of the `gsa` system: recipes under `packages/<category>/<id>/` (`PKGBUILD` plus committed `.SRCINFO` and any local patch, asset or licence), the declarative build topology in `config/{topology,build-defaults,abi-exclusions}.conf`, shared recipe modules in `lib/`, host diagnostics in `tools/`, and the `$TMPDIR`-scoped fixture battery in `tests/`.

- **Boundary.** The engine — a Rust workspace that produces `/usr/bin/gsa` — lives in `ZhangDM-520/gentoo-style-arch`; this repository never vendors or patches engine code, and `packages/core/gsa-pm` builds and installs it as a self-tracking recipe. `docs/gsa-contract.md` in that repository is authoritative over every document here.
- **Topology, not directories.** `config/topology.conf` binds an id to its path, groups and build-order edges; the physical categories (`git`, `stable`, `core`, `misc`, `deprecated`) are only a filing system, and one malformed record breaks every command. The engine also composes the compiler and linker line over `/etc/gsa/{gcc,clang}-makepkg.conf`, so a recipe keeps only a reasoned delta.
- **Landmines.** Build in the store or a copy, never in the checkout (a repo-cwd build rewrites `pkgver=`); never run two heavy builds concurrently; `gsa --print-*` seams must reach a shipped file or the seam fixture fails by name.

## 1 · Read before changing anything

| File | Role |
|---|---|
| `README.md`, `CONTEXT.md`, `CONTRIBUTING.md`, `SECURITY.md` | Purpose, vocabulary, the recipe checklist and trimming/ABI discipline, trust model |
| `docs/package-policy.md` | What a recipe directory may hold versus what is fetched at build time |
| `docs/source-sharing.md` | The `gsa -Mm` mirror contract: canonical selection, confirmation gate, runtime-state boundary |
| `../gentoo-style-arch/docs/{gsa-contract,build-guide,architecture,portability}.md` | Authoritative engine interface, operations, crate split and portability |
| The maintainer's private warehouse | Rule and pitfall bodies, action history, plans, reviews and owner rulings |

## 2 · Commands

```sh
bash tests/run-all.sh [filter|--serial|-j N]               # the battery; tests installed /usr/bin/gsa
bash -n packages/<cat>/<pkg>/PKGBUILD                      # recipe syntax
GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<pkg> > packages/<cat>/<pkg>/.SRCINFO
gsa -Sl @git && gsa -Ma && gsa -S --dry-run @git           # listing, report-only audit (always rc 0 — read it), plan
gsa --qa-check <declared-deps|abi-closure|abi-exposure|provides-versioning|purged-tools|stale-ignorepkg|swap-drift>
sudo gsa -S --leaf <pkg>                                   # one recipe, no consumer expansion
sudo gsa -S @core                                          # the ABI-coupled core batch, install as you go
GIT_CONFIG_COUNT=0 makepkg -f --dir packages/core/gsa-pm   # engine bootstrap
```

Never use a real rebuild as a syntax check. Tests stay `$TMPDIR`-scoped, non-mutating and parallel-safe (`tests/assets/` is the frozen oracle and never runs standalone); a new fixture needs no runner edit.

## 3 · Rules

Rule numbers are preserved forever: recipe comments, `CONTRIBUTING.md` and `gentoo-style-arch/AGENTS.md` cite them by number, so they are never renumbered, reused or invented. Bodies live in the maintainer's private warehouse.

- **1, 2 — Shell and git hardening**: Wrap fish/cross-shell commands in `bash -c` (`find -name`, no `export`/`[[ ]]`); prefix makepkg and bare-repo git work with `GIT_CONFIG_COUNT=0`.
- **3 — Validate `PKGBUILD` + `.SRCINFO`**: Run `bash -n` and `makepkg --printsrcinfo > .SRCINFO` together (`!check`/`autodeps` are invalid options).
- **4 — Provides discipline**: `-git` toolchains carry versioned provides after `pkgver=`; libraries use bare sonames (`libfoo.so`); request virtual capabilities, never a concrete provider.
- **6 — Stale configure caches**: Clean mismatched `meson-info.json`/`*.la`; edit `CMakeCache.txt` in place (`touch CMakeLists.txt`).
- **7 — Never disturb in-flight builds**: Check running `makepkg` and log mtimes; never run two heavy builds concurrently.
- **8 — Purged tools stay purged**: Never re-add `po4a`, `python-sphinx`, `lvm2`, `cuda`, `gcc15`, etc. (`gsa -Ma` `purged-tools`).
- **10 — Journal & action exports**: One dense line per action and a per-action note in the private warehouse; reset its scratchpad.
- **13, 14 — Coupled ABI batches**: `llvm-git` moves with `rust-git`, `mesa-git`, `spirv-llvm-translator-git` and `openshadinglanguage` (`--skip`); every Qt private-API consumer rebuilds together on a `qt{5,6}-base-git` bump (`nm -D --undefined-only | grep QtPrivate_`, `MESON_FORCE_BACKTRACE=1`).
- **15 — Never bypass source verification**: Never `--skippgpcheck`; pin the `validpgpkeys` signer and import it into the build user's keyring.
- **16 — Batch bulk `prepare()` work**: Cut inputs once, use shell builtins and `mv -t`, assert consumed counts.
- **17, 58 — Public surface and living docs**: Comments explain code, kernel options and trims (name the AMD target behind a trim) — never machine specs, thread counts or incident history; probe live versions with `gsa -Sl`/`pacman -Q`, and keep retired spellings only in the engine contract §B.9.
- **18, 28 — Pinned inputs**: Put git-absent inputs in `source=()` with checksums and fail-closed `prepare()` verification; never `SKIP` a pinned `#commit=`, and verify a moved source against the official `.SRCINFO` through a staged `updpkgsums`.
- **20 — Packaged venvs use runtime paths**: Rewrite launcher/finder/`.pth` paths from `$pkgdir` to the final prefix; strip `__pycache__`.
- **21 — Group membership is topology data**: `>= 2` consumers => `core` (unless `app-cluster`); compilers carry `core,build-tools`; cargo/rustc recipes declare a `rust-git` edge; group edits preserve `abi=`/`app-cluster=`.
- **22, 65 — Artifact-based reconciliation**: One writer per mutable tree; hash inputs first (`sha256sum`, `ls --time-style=full-iso`); reconcile by regenerated `.SRCINFO`/files, never by agent self-reports; edge-union divergent record writes.
- **23 — Swap/ABI install contract**: `--ask 4` consents to removal only; Class A providers declare `provides=(<stock>=$pkgver)` plus `conflicts=(<stock>)`.
- **24 — Source-merge & topology identity**: Merge same-upstream clusters into one record; keep split siblings pkgname-addressable; supersede via `X -> X-git` edges; trim unreferenced splits (`# trim:`).
- **25 — ABI closure (recipe half)**: Bare sonames only `(a)`; review `config/abi-exclusions.conf` before `review-by` `(f)`; promote `>= 2` consumer records to `core` `(i)`.
- **26, 27 — Latency and pins**: Re-time `gsa -Sl` on roster jumps and never pin wall-times in fixtures; avoid strict `=` pins on rolling `-git` sets and rebuild `lib32` `.1` pinners with multilib bumps.
- **29, 30 — Swap waves**: Retire exact-pin stock split leftovers (`expac`) first; rebuild *every* direct NEEDED consumer on a soname bump, never symlinking old→new.
- **31 — Signable `?signed` refs & meson options**: Keep `?signed` on pinned `#tag=`/`#commit=` refs whose upstream signs tags; validate `-D` flags against `meson.options`.
- **32, 33 — Patch and warm-tree audits**: Diff `nm -D` across a multi-patch set as a whole, and across double builds after cleaning untracked `$srcdir` state.
- **34 — Materialized generators**: Keep generators in `makedepends` and delete stale stamps before retrying.
- **36 — Sweep stock ELF consumers**: Audit `readelf -d` across `/usr/{bin,lib,libexec}` + `/opt` on soname bumps.
- **37 — Toolchain transitions**: Patch C++ includes across whole vendored trees in one patch; drop `-Werror` on generated flex/bison.
- **39 — Linker opt-outs**: Strip `-fuse-ld=mold` for `-b binary` (`libxdp`) alongside `!lto`.
- **40, 41, 42 — Toolchain knobs**: Never double-wrap `ccache` (`CMAKE_*_COMPILER_LAUNCHER`, run `ccache -C` after a toolchain bump); pass `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` when `cmake_minimum_required` is older; pass `/usr/bin/python3` to CMake so `~/.local/bin` shims cannot shadow it.
- **43 — Cargo vendor checksums**: Update `.cargo-checksum.json` per patched file in `prepare()`.
- **45 — Parallel archive races**: Fix `ar`/`ranlib` target ordering in `make` instead of forcing `-j1`.
- **46 — Isolated `git apply`**: Pin `GIT_DIR`/`GIT_WORK_TREE` with `GIT_CONFIG_COUNT=0` so outer repos do not skip hunks.
- **47 — Trimmed split features**: Disable trimmed features in configure, not only in `makedepends`/`package()`.
- **48 — Qualify `$srcdir` in `package()`**: `package()` starts in `$srcdir` (`cd` or qualify `$srcdir/...`).
- **49 — Vendor meson subprojects**: Wire wrap subprojects via `source=()`, `prepare()` symlinks and `packagefiles/`.
- **50 — Compat shims**: Match upstream stdout/newline shapes (`lib/cups-config`).
- **51 — Separate conflicting variants**: Keep mutually exclusive variants as separate recipes with `provides` + `conflicts`.
- **52 — Justified topology edges**: Add edges only from fresh-host `pacman -T` proof.
- **53 — Probe `ccache` wrapper**: `gsa-pm` drops a broken `ccache` from `PATH` instead of symlinking sonames.
- **54 — Linked libraries in `depends`**: Gate via `gsa --qa-check declared-deps` after `.SRCINFO` regeneration.
- **55, 56 — Rebuild order and non-interactive children**: Detect broken links with `ldd | grep 'not found'` and rebuild direct consumers first; always pass `--noconfirm` to `makepkg -s` chains.
- **60 — Store boundary**: Never write `/var/lib/gsa` from a recipe.
- **61 — Installed `/usr/bin/gsa`**: Keep `gsa-pm` self-tracking (no `_commit` pin); deploy via `sudo gsa -Sy && sudo gsa -S gsa-pm`, then run the battery.
- **63 — Volatile `-Sy` store**: Copy uncommitted `-Sy` rewrites to the dev tree and preserve the authored `pkgver`/`pkgrel`.
- **64 — Monday snapshot pins**: Pin `@core`/`@build-tools` moving VCS refs to the last commit ≤ Monday 00:00 UTC; `<id>-snapshot` is an input alias only, so keep the `-git` id and its provides.
- **70 — Clean build dir**: Wipe meson `build/` on flag edits and force rebuilds.
- **75 — `SRCDEST` authority**: A single `SRCDEST` authority in `/etc/gsa/gsa.conf`; keep the environment empty.

## 4 · Optimization

The engine owns the compiler line: generated `makepkg --config` composites over `/etc/gsa/{gcc,clang}-makepkg.conf` (bodies produced by `gsa --print-conf`, shipped by `gsa-pm`). `makepkg.conf` is never sourced, so a recipe keeps only a reasoned delta.

- **Never append a baseline flag** (`-O3`, `-march`, `-mtune`, `-pipe`, `-fno-plt`, `-fuse-ld=mold`, LTO/RELRO). Removing a shipped flag is a substitution — `CFLAGS=${CFLAGS/-fno-math-errno/}` — never a re-assignment; the one level change is `${CFLAGS/-Ofast/-O3}` for a fast-math victim.
- **LTO per family**: meson `-Db_lto=true`; PGO phase 1 `false` → phase 2 `true`; `options=(!lto)` where the link breaks; `!lto` on `llvm-git`/`rust-git` only to neutralize makepkg's `LTOFLAGS` while upstream keeps its own.
- **PGO is one shared gate**: `source "$startdir/../../../lib/pgo.sh"` at top level and `verify_no_profile_instrumentation "$pkgdir"` LAST in every `package*()` (fatal `exit 1`); thresholds are per-recipe `local`s (`pgo_min_gcda`/`pgo_min_profraw`/`pgo_min_samples`), never a module knob.
- **Named exceptions**: `rust-git`, Zen (`--enable-optimize=-O3`), `gcc-snapshot` (`STAGE*_CFLAGS=-O2`), `qt5-base-git`, Electron/JavaScript (`!strip !debug !lto`), `texlive-texmf` (`arch=(any)`, optimized by trimming).

## 5 · Pitfalls

One line per mechanism; bodies and probe commands live in the maintainer's private warehouse.

- **Recipe files, patches, sources** — host facts stay out of comments; `provides=` goes after `pkgver=`; `b2sums` stays flat with a parse guard; prove a patch stack in order; verify the post-`make prepare` kernel `.config`; parse every `source=()` shape in a scanner; a `?signed` failure is usually injected `GIT_CONFIG_*`.
- **Swap providers, provides and sonames** — match the stock `pkg-config`/provides/API; verify with `tools/provides-audit.sh` + `pacman -T`; `pkgrel` must strictly beat `pacman -Qi`; tolerate a missing soname only when its provider cannot exist here; pin `/usr/bin/python` and reinstall the dual-owned survivor.
- **Build systems and toolchains** — house LLVM targets are `X86;AMDGPU;BPF` only; `-ffat-lto-objects` for static archives; explicit `--enable`/`--disable` for auto-features; audit `USE_SYSTEM_*` against `makedepends`; guard upstream header and ABI drifts; wipe warm build dirs on compiler drift.
- **PGO, sandboxing and packaging traps** — fatal tail gate with a clean fallback; short `mktemp -d` socket paths; serialize doc builds; wipe polluted `$srcdir`; wire tool shims in `build()`; export `/usr/bin/core_perl` on `PATH`.
- **Host safety and forensics** — three deterministic host freezes retire a recipe (`--jobs 2` + pstore forensics required to re-add); `go mod verify` after a crash; guard mkinitcpio hook changes; drop dead deps and outputs together.

## 6 · Queued

Delete a finished item. Dated rulings, blockers and per-campaign detail live in the maintainer's private warehouse.

- **Snapshot-pin waves**: W1 pinned (64 recipes, nothing installed yet); W2–W4 and the `-Sy` provider wait behind the owner's full rebuild.
- **Parks**: `libdisplay-info-git`, `libpng-git` (the so.18 consumer batch), `libseccomp-git`, `libgit2-git`, `logseq-desktop-git` and `vencord-git` stay in `packages/deprecated/` and are revived only by a dated decision.
- **Topology debt**: the flag-revision validation rebuild, missing prereq and epoch `provides` sweeps, `abi=` tags, and the `icu-git` soname skew before the next `-Syu`.

## 7 · How to work here

1. Read this file, then the section of `docs/` the task touches; check the private warehouse's action index and the matching lesson note for prior judgment.
2. Keep dense tool output and milestones in the private warehouse's scratchpad, not in the model context, and not in tracked files.
3. After each action write one note (symptom → root cause → fix → validation → durable rule) and append exactly ONE dense line to the action index, naming the affected recipe ids and the command that proved the change.
4. Any re-cut of this file or `docs/` is verified by citation grep (`AGENTS.md §N`); the §-numbers are cited from recipe comments, so sections are never renumbered or deleted.
5. Never commit or push unprompted: a green battery is evidence, not consent. Every commit ends with `Assisted-by: LLM (human-reviewed)` then `Signed-off-by` matching the configured git identity; no `Co-authored-by`.
6. `rm` is a trash wrapper in the interactive fish shell and ignores `-r`; tool-call shells are bash, so hand user commands to `bash -c '...'`. Prefix makepkg and bare-repo git work with `GIT_CONFIG_COUNT=0`, or the injected `safe.bareRepository=explicit` breaks tag verification and LFS.
7. Never run two heavy builds at once and check for an in-flight `makepkg` first (rule 7). Build from the store or a copy — a repo-cwd build rewrites `pkgver=` in place.
