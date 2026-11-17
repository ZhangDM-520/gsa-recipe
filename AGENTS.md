---
permalink: gsa-recipe/agents
title: AGENTS
type: note
---

# AGENTS.md — memory management & entry point

Last reviewed: 2026-11-17. Holds overview, doc map, commands, rule index, pitfall index, and active queue; full bodies live in `docs/{rules,optimization-playbook,pitfalls,queue}.md`. Incident dates/measurements belong in `docs/JOURNAL.md`. `.logs/scratchpad.md` is the tracked active buffer (reset after each action); `.logs/action-<ISO>-<task>.md` are untracked exports. Delete finished §6 items rather than ticking them.

## 0 · What this repository is

The recipe half of the `gsa` system (`packages/<category>/<id>/` + `config/{topology,build-defaults,abi-exclusions}.conf` + `lib/` + `tools/` diagnostics + `$TMPDIR` `tests/`).

- **Boundary**: `gentoo-style-arch` owns `/usr/bin/gsa` (`packages/core/gsa-pm` packages it, self-tracking); never vendor/patch the engine here. `tests/gsa-pm-shipped-files.sh` runs the real `package()` against the installed engine and requires every rostered `--print-*` seam to land a non-empty file byte-identical to the engine's own output, so **a new seam fails that fixture by name until its seam→path row and its `install` line are added**: `--print-conf {gcc,clang}` → `/etc/gsa/*-makepkg.conf`, `--print-completion {fish,bash,zsh}` → the three completion dirs. Printing is not shipping.
- **Durable toolchain & Qt shape (probe `pacman -Q`)**: Minimal `llvm-git` (`X86;AMDGPU;BPF` for BPF/scx, paired with `rust-git`); versioned `-git` toolchain provides (`meson`, `ninja`, `cmake`, `doxygen`).
- **Qt private-API stack**: `qt5-base-git` (`-ffat-lto-objects`), scoped `pyside6-git`, `qt{5,6}ct` (`abi=must`), stock `qt6-translations`.
- **Notable package shapes**: `gimp-3.3` (`babl`/`gegl` sonames), `util-linux` (`build-python`/`translate-docs` off, `--undefined-version`), trimmed `linux-firmware`, `pipewire-jack-client` (no `pipewire-jack`), `easyeffects-git`, `blender-git` + `openshadinglanguage`, `gcc-snapshot` (`verify_ctor_sanity` workaround until PR c++/127395), `aranicy` (`conflicts=(ananicy-cpp)`).
- **Key dependency chains**: `glib2 -> pango -> cairo -> gtk3/4 -> libadwaita`; `liburing -> libdex -> xdg-desktop-portal`; `qt{5,6}-base -> modules`; `ninja -> meson`; `rocm-core -> rocm-llvm -> hsa-rocr -> hip-runtime`; `llvm -> SPIR-V/libclc/rust -> rust-bindgen`; `babl -> gegl -> gimp`; `openssl -> openssh/openvpn/git/LibreOffice`; `LLVM -> OpenShadingLanguage -> blender`.
- **Landmines**: Keep `libisl-git` repo mapping intact, rebuild Qt/LLVM consumers in batches, keep mirror origins/refspecs exact, build only in store/clone (never in checkout), and reserve ~38 GB (`rm -rf src` on resume) for `texlive-texmf`.

## 1 · Read before changing anything

| File | Role |
|---|---|
| `README.md`, `CONTEXT.md`, `CONTRIBUTING.md`, `SECURITY.md` | Purpose, vocabulary, recipe checklist/trimming/ABI discipline, trust model |
| `docs/maintainer-guide.md` & `docs/package-policy.md` | Maintenance manual, groups, coupled updates, `.SRCINFO`/asset policy |
| `docs/source-sharing.md` & `docs/snapshot-expansion.md` | Shared-source mirror contract (`gsa -Mm`) and Monday snapshot pins |
| `docs/CURRENT.md` | Live umbriel snapshot (overwrite, never append; owned by separate session lane) |
| `docs/adr/` (`0001-pgo-shared-gate`, `0002-topology-one-record`) | Why PGO verification is one shared gate and topology is one record per package |
| `docs/{rules,optimization-playbook,pitfalls,queue}.md` & `docs/JOURNAL.md` | Disclosed rules, PGO/LTO playbook, pitfalls, active queue, and history |
| `../gentoo-style-arch/docs/{gsa-contract,build-guide,architecture,portability}.md` | Authoritative engine interface and build/portability specs |

## 2 · Commands

```sh
bash tests/run-all.sh [filter|--serial]                    # tests installed /usr/bin/gsa (GSA_TEST_GSA_BIN=... overrides)
bash -n packages/<cat>/<pkg>/PKGBUILD                      # recipe syntax
GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<pkg> > packages/<cat>/<pkg>/.SRCINFO
gsa -Sl @git && gsa -Ma && gsa -S --dry-run @git           # ordered list, report-only audit (always rc 0—read it), dry-run plan
sudo gsa -S @core                                          # ABI-coupled core build + immediate install
```

Never use real rebuilds as syntax checks; tests must stay parallel-safe and `$TMPDIR`-scoped (`tests/assets/` excluded).

## 3 · Rules

Preserved rule numbers match recipe comments and `gentoo-style-arch/AGENTS.md` (where engine halves live). Full bodies live in `docs/rules.md#numbered-recipe-rules`:

- **1 — Cross-shell `bash -c`**: Wrap fish/cross-shell commands in `bash -c` (`find -name`, no `export`/`[[ ]]`).
- **2 — Agent git hardening**: Prefix makepkg and bare-repo git work with `GIT_CONFIG_COUNT=0`.
- **3 — Validate `PKGBUILD` + `.SRCINFO`**: Run `bash -n` and `makepkg --printsrcinfo > .SRCINFO` together (`!check`/`autodeps` invalid).
- **4 — Provides discipline**: `-git` toolchains carry versioned provides after `pkgver=`; libs use bare sonames (`libfoo.so`); request virtual capabilities.
- **6 — Stale configure caches**: Clean mismatched `meson-info.json`/`*.la`; edit `CMakeCache.txt` in place (`touch CMakeLists.txt`).
- **7 — Never disturb in-flight builds**: Check running `makepkg` and log mtimes; never run two heavy builds concurrently.
- **8 — Purged tools stay purged**: Never re-add `po4a`, `python-sphinx`, `lvm2`, `cuda`, `gcc15`, etc. (`gsa -Ma` `purged-tools`).
- **10 — Journal & action exports**: Append 1 dense line to `docs/JOURNAL.md` + export `.logs/action-*`; reset scratchpad.
- **13 — LLVM never moves alone**: Bump `llvm-git` with `rust-git`, `mesa-git`, `spirv-llvm-translator-git`, `openshadinglanguage` (`--skip`).
- **14 — Qt private-API coupling**: Rebuild all private-API consumers together on `qt{5,6}-base-git` bumps (`MESON_FORCE_BACKTRACE=1`).
- **15 — Never bypass source verification**: Never `--skippgpcheck`; pin `validpgpkeys` primary key in build user keyring.
- **16 — Batch bulk `prepare()` work**: Cut inputs once and batch file moves (`mv -t`) with asserted counts.
- **17 — Recipes are public surface**: Never embed host specs, thread counts, or incident history in tracked comments.
- **20 — Packaged venvs**: Rewrite `$pkgdir` paths to final runtime prefix and strip `__pycache__`.
- **21 — Topology group membership**: `>= 2` consumers => `core`; compilers carry `core,build-tools`; cargo recipes edge `rust-git`.
- **22 — Artifact-based fleet reconciliation**: One writer per mutable tree; verify parallel cuts via regenerated `.SRCINFO`.
- **23 — Swap/ABI install contract**: `--ask 4` consents to removal only; Class A providers declare `provides=(<stock>=$pkgver)` + `conflicts=(<stock>)`.
- **24 — Source-merge & topology identity**: Merge same-upstream clusters into one record; supersede via `X -> X-git` edges; trim splits (`# trim:`).
- **25 — ABI closure (recipe half)**: Bare sonames only `(a)`; review `config/abi-exclusions.conf` before `review-by` `(f)`; promote `>= 2` consumers to `core` `(i)`.
- **26 — Roster latency**: Re-time `gsa -Sl` on roster jumps (never pin wall-times).
- **27 — Multilib & `=` pins**: Avoid strict `=` pins and rebuild `lib32` `.1` pinners with multilib bumps.
- **28 — Pin non-git build data**: Put git-absent inputs in `source=()` with checksums and fail-closed `prepare()` verification.
- **29 — Stock leftovers**: Retire exact-pin stock split leftovers (`expac`) before swap waves.
- **30 — Soname waves**: Rebuild *every* direct NEEDED consumer on soname bumps (never symlink old->new).
- **31 — Signable `?signed` refs & meson options**: Keep `?signed` only on pinned `#tag=`/`#commit=` refs; validate `-D` flags against `meson.options`.
- **32 — Audit dropped patches**: Diff `nm -D` across multi-patch sets as a whole.
- **33 — Warm `$srcdir` hygiene**: Clean untracked `$srcdir` state and diff `nm -D` across double builds.
- **34 — Materialized generators**: Keep generators in `makedepends` and delete stale stamps before retrying.
- **36 — Sweep stock ELF consumers**: Audit `readelf -d` across `/usr/{bin,lib,libexec}` + `/opt` on soname bumps.
- **37 — Toolchain transitions**: Patch C++17 includes across whole vendored trees in one patch; drop `-Werror` on generated flex/bison.
- **39 — Linker opt-outs**: Strip `-fuse-ld=mold` for `-b binary` (`libxdp`) alongside `!lto`.
- **40 — Never double-wrap `ccache`**: Never set `CMAKE_*_COMPILER_LAUNCHER=ccache`; run `ccache -C` after toolchain bumps.
- **41 — CMake 4 policy floor**: Pass `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` when `cmake_minimum_required` `< 3.5`.
- **42 — Pin system Python**: Pass `/usr/bin/python3` to CMake so `~/.local/bin` shims do not shadow it.
- **43 — Cargo vendor checksums**: Update `.cargo-checksum.json` per patched file in `prepare()`.
- **45 — Parallel archive races**: Fix `ar`/`ranlib` target ordering in `make` instead of forcing `-j1`.
- **46 — Isolated `git apply`**: Pin `GIT_DIR`/`GIT_WORK_TREE` with `GIT_CONFIG_COUNT=0` so outer repos do not skip hunks.
- **47 — Trimmed split features**: Disable trimmed features in configure, not only in `makedepends`/`package()`.
- **48 — Qualify `$srcdir` in `package()`**: `package()` starts in `$srcdir` (`cd` or qualify `$srcdir/...`).
- **49 — Vendor meson subprojects**: Wire wrap subprojects via `source=()`, `prepare()` symlinks, and `packagefiles/`.
- **50 — Compat shims**: Match upstream stdout/newline shapes (`lib/cups-config`).
- **51 — Separate conflicting variants**: Keep mutually exclusive variants as separate recipes with `provides` + `conflicts`.
- **52 — Justified topology edges**: Add edges only from fresh-host `pacman -T` proof.
- **53 — Probe `ccache` wrapper**: `gsa-pm` drops broken `ccache` from `PATH` instead of symlinking sonames.
- **54 — Linked libraries in `depends`**: Gate via `gsa --qa-check declared-deps` after `.SRCINFO` regen.
- **55 — Direct NEEDED rebuild order**: Detect with `ldd | grep 'not found'` and rebuild direct consumers first.
- **56 — Non-interactive `--noconfirm`**: Always pass `--noconfirm` to `makepkg -s` chains.
- **58 — Living docs**: Probe live versions via `gsa -Sl`/`pacman -Q`; keep retired spellings only in engine contract §B.9.
- **60 — Store boundary**: Never write `/var/lib/gsa` from recipes.
- **61 — Installed `/usr/bin/gsa`**: Keep `gsa-pm` self-tracking and test against installed `/usr/bin/gsa`.
- **63 — Volatile `-Sy` store**: Copy uncommitted `-Sy` rewrites to dev tree and preserve authored `pkgver`/`pkgrel`.
- **64 — Monday snapshot pins**: Pin `@core`/`@build-tools` moving VCS refs to Monday `00:00 UTC` (`<id>-snapshot` alias).
- **65 — Hash inputs first**: `sha256sum` + `ls --time-style=full-iso`; one writer per mutable tree.
- **70 — Clean build dir**: Wipe meson `build/` on flag edits and force rebuilds.
- **75 — `SRCDEST` authority**: Single `SRCDEST` authority in `/etc/gsa/gsa.conf` (keep env empty).
- **Optimization playbook (`docs/optimization-playbook.md`)**: Engine injects `-march=native -mtune=native -O3`, `-fuse-ld=mold`, and `RUSTFLAGS`; use `lib/pgo.sh` (`verify_no_profile_instrumentation "$pkgdir"` last) with per-recipe `pgo_min_*` thresholds and phase-2 reconfigure.

## 4 · Optimization playbook

Full bodies live in `docs/optimization-playbook.md`. Four commitments, each with its own section there:

- **Flags are the engine's** — the compiler line, `-fuse-ld=mold` and `RUSTFLAGS` come from `/etc/gsa/{gcc,clang}-makepkg.conf`; a recipe keeps only a delta with its reason in the file, or a substitution when it must drop a shipped flag (`CFLAGS=${CFLAGS/-fno-math-errno/}`). The one level-drop — `${CFLAGS/-Ofast/-O3}` for a fast-math victim — is a substitution, never an added `-O3`.
- **LTO is chosen per family** — meson `-Db_lto=true`, PGO phase 1 `false` → phase 2 `true`, `options=(!lto)` where the link breaks, and `!lto` on `llvm-git`/`rust-git` purely to neutralize makepkg's `LTOFLAGS`.
- **PGO is a shared gate with per-recipe thresholds** — `source lib/pgo.sh` at top level, `verify_no_profile_instrumentation "$pkgdir"` last in every `package*()`, and `pgo_min_gcda`/`pgo_min_profraw`/`pgo_min_samples` as a `local` (never a `lib/pgo.sh` knob). Phase 2 re-runs the *configure*, not only the build.
- **Package families keep their documented overrides** — `rust-git`, Zen, `gcc-snapshot`, `qt5-base-git`, Electron/JS, and the `arch=(any)` TeX Live data split.

## 5 · Pitfalls

One line per mechanism (full explanations in `docs/pitfalls.md`):

- **Public comments & `.SRCINFO` order**: Keep host facts out of recipes; put `provides=` after `pkgver=` and keep static → `docs/pitfalls.md#recipe-files-patches-and-sources`.
- **Knobbed `b2sums` & patch validation**: Add parse guards (`GENINTEG=1` exempt); vendor GitHub patches and test `git apply -3` on fresh clones → `docs/pitfalls.md#recipe-files-patches-and-sources`.
- **Kernel `.config` & `_pick` completeness**: Verify post-`make prepare` `.config`; enumerate `_pick` vs tree (`var/run` belongs to `filesystem`) → `docs/pitfalls.md#recipe-files-patches-and-sources`.
- **`source=()` scanners & `pkgver()`**: Parse `url`, `git+url`, `name::git+url`, `git://`; use version files (`QT_REPO_MODULE_VERSION`) → `docs/pitfalls.md#recipe-files-patches-and-sources`.
- **PGP & `?signed` failures**: Check `GIT_CONFIG_COUNT=0` before touching `?signed` (expired keys pre-dating expiry verify with warning) → `docs/pitfalls.md#recipe-files-patches-and-sources`.
- **Stock swap surface & bare sonames**: Match stock `pkg-config`/provides/API; verify via `tools/provides-audit.sh` + `pacman -T` and beat `pacman -Qi` pkgrels → `docs/pitfalls.md#swap-providers-provides-and-sonames`.
- **Python pin & dual-owned files**: Pin `/usr/bin/python`; reinstall survivor after dual-owned file loss (`terminfo`) → `docs/pitfalls.md#swap-providers-provides-and-sonames`.
- **Tcl 9, licences & `DESTDIR`**: Glob `tcl*/`, call `install -d` before `cp -a`, and `rm -rf dest-*` in `build()` → `docs/pitfalls.md#swap-providers-provides-and-sonames`.
- **House LLVM targets**: House LLVM builds `X86;AMDGPU;BPF` only (no NVPTX) → `docs/pitfalls.md#build-systems-and-toolchains`.
- **LTO & mold link traps**: Use `!lto` for lld-linked Rust, `-ffat-lto-objects` for static libs, `-fuse-ld=bfd` in glibc, and `--undefined-version` for mold → `docs/pitfalls.md#build-systems-and-toolchains`.
- **Meson `--auto-features` & trimming**: Pass explicit `--enable`/`--disable` (`-Db_pgo=off`) and trim dead `makedepends` + paths together → `docs/pitfalls.md#build-systems-and-toolchains`.
- **CMake jobs & `USE_SYSTEM_*`**: Pass `--parallel` to `cmake --build` and audit `USE_SYSTEM_*` against `makedepends` → `docs/pitfalls.md#build-systems-and-toolchains`.
- **Upstream header & ABI drifts**: Guard compat shims, pass `cups 2.5` `CPPFLAGS`, set C++17 for ICU, preserve `zstd` cmake, symlink libtool `_libs` → `docs/pitfalls.md#build-systems-and-toolchains`.
- **Compiler & snapshot drifts**: Fix snapshot `cmake -P` probes, aggregate NSDMIs, and miscompiled tolerant scans (`-fno-tree-vectorize`); wipe warm build dirs → `docs/pitfalls.md#build-systems-and-toolchains`.
- **Static flags & Chromium `.rsp`**: Use `WITH_SYSTEM_*` for `glog`/`gflags` and keep short `_build_dir` for Chromium → `docs/pitfalls.md#build-systems-and-toolchains`.
- **Rust `cargo test`, GHC & `checkdepends`**: Skip mismatched `cargo test` (`BUILDENV=(!check)`), match GHC ways, and preserve `checkdepends` tests → `docs/pitfalls.md#build-systems-and-toolchains`.
- **PGO gates & sandboxes**: Fatal tail `verify_no_profile_instrumentation` + clean fallback; short `mktemp -d` sockets (`108B`) → `docs/pitfalls.md#pgo-sandboxing-and-packaging-traps`.
- **SVG concurrency & tail guards**: Serialize `make -C doc -j1` and write function-tail checks as `if ... fi` → `docs/pitfalls.md#pgo-sandboxing-and-packaging-traps`.
- **Polluted `$srcdir` & `core_perl`**: Wipe dead `clone -s` / VCS husks and export `/usr/bin/core_perl` `PATH` → `docs/pitfalls.md#pgo-sandboxing-and-packaging-traps`.
- **Tool shims & consumer alignment**: Wire `install -Dm755` shims in `build()`, align consumer patch arrays, and edge cargo/tool `rust-git` prereqs → `docs/pitfalls.md#pgo-sandboxing-and-packaging-traps`.
- **Freeze quarantine**: Three deterministic host freezes retire a recipe (`--jobs 2` + pstore forensics required to re-add) → `docs/pitfalls.md#host-safety-and-forensics`.
- **Post-crash caches, mkinitcpio & silent fails**: Run `go mod verify`, guard mkinitcpio hook changes, drop dead deps/outputs together, and `tee` silent exits → `docs/pitfalls.md#host-safety-and-forensics`.

## 6 · Queued

Full details and blockers live in `docs/queue.md` (delete finished items):

- **Snapshot-pin waves (`docs/snapshot-expansion.md` §8)**: W1 pinned; W2 (59), W3 (5), W4 (8) queued behind owner W1 rebuild (`libidn2-git`, `libmypaint-git` blocks) → `docs/queue.md#high-priority-campaigns--topology-debt`.
- **Flag-revision validation rebuild**: 133-recipe T1–T3 appends await ~2-week owner rebuild (`libldacdec` `-O3 -march=native` pending) → `docs/queue.md#high-priority-campaigns--topology-debt`.
- **Topology edges & epoch/warm-`$srcdir` sweeps**: ~1,825 missing prereq edges + 3 unverified edges; 15+ epoch `provides` + tarball `prepare()` guards → `docs/queue.md#high-priority-campaigns--topology-debt`.
- **LLVM-ABI tags & `icu-git` skew**: Add `abi=should`/edges for `postgresql-libs`/`linux-tools`; resolve `icu-git` `.so.80` vs distro `78.3` (`nuspell`, `vte3`, `qt6-webengine`) → `docs/queue.md#high-priority-campaigns--topology-debt`.
- **`validpgpkeys` & `sqlite` doc-zip**: Confirm `nautilus`/`gobject-introspection`/`bind`/`fish` keys; handle `sqlite` 3.54 doc-zip → `docs/queue.md#package-specific-decisions--parks`.
- **Stack cleanups & kernel/PGO decisions**: ROCm/`dbus-broker`/`doxygen-git`/`libadwaita-git`/`linux-firmware`/`systemd`; `linux-cachyos` CVE + AutoFDO/Propeller profiles → `docs/queue.md#package-specific-decisions--parks`.
- **Backlog & verification debts**: `ghostscript`/`tesseract`, `keys/*.asc`, `gst-libav`, `gnulib`, `spandsp`, stale `.SRCINFO` (`hermes-agent-git`, `zen-browser-pgo`) → `docs/queue.md#package-specific-decisions--parks`.
- **Parked packages & `llvm-git <-> rust-git`**: Parked (`libdisplay-info-git`, `libpng-git`, `libseccomp-git`, `libgit2-git`); automate `llvm-git <-> rust-git` bootstrap → `docs/queue.md#package-specific-decisions--parks`.

## 7 · Working here

1. Read this file and `docs/JOURNAL.md` before acting, then the section of
   `docs/` the task touches. Claim queued work by editing §6; delete an item
   when it is finished — never tick it.
2. Keep dense tool output and milestones in `.logs/scratchpad.md`, not in the
   model context and not in `docs/`.
3. After each action: write `.logs/action-<ISO>-<task>.md`, append exactly ONE
   dense line to `docs/JOURNAL.md`, and reset `.logs/scratchpad.md` to its stub.
   `.logs/` is never tracked.
4. A non-trivial recipe change records symptom → root cause → fix → validation
   → durable rule in its journal line, naming the affected recipe ids and the
   command that proved it.
5. Never commit or push unprompted. A green battery is evidence, not consent.
   Every commit ends with two trailers, in this order: `Assisted-by: LLM
   (human-reviewed)` then `Signed-off-by` matching the committer's configured
   git identity. No `Co-authored-by: Copilot` line — the assistant is already
   disclosed by `Assisted-by`, and a second trailer duplicates one fact.
6. `rm` is a trash wrapper in the fish login shell: it moves targets to
   `~/.local/share/Trash` and ignores `-r`/`-R`. Tool-call shells are bash, so
   hand any command you give the user to `bash -c '...'`.
7. Prefix makepkg and bare-repo git work with `GIT_CONFIG_COUNT=0`; without it
   the agent shell's injected `safe.bareRepository=explicit` breaks tag
   verification and LFS fetches.
8. Never run two heavy builds at once, and check for in-flight `makepkg`
   before rebuilding (rule 7).
