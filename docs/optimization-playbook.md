---
permalink: gsa-recipe/docs/optimization-playbook
title: optimization-playbook
type: note
---

# gsa-recipe Optimization Playbook

Detailed compiler, linker, LTO, PGO, and package-family conventions indexed in [AGENTS.md](../AGENTS.md).

## Baseline Compiler, Linker & LTO Conventions

- **Engine-owned flags (`/etc/gsa/{gcc,clang}-makepkg.conf`)**: Engine injects `-march=native -mtune=native -O3` plus per-family passes via generated `makepkg --config` composites (host/user `makepkg.conf` is never sourced). Never duplicate baseline flags in recipes; keep only reasoned package deltas or substitutions (`CFLAGS=${CFLAGS/-fno-math-errno/}`).
- **`mold` linker**: `-fuse-ld=mold` ships in both engine `LDFLAGS` bodies. Keep explicit `-fuse-ld=mold` only where builds ignore `LDFLAGS` (`QMAKE_LFLAGS`, meson linker args, or PGO `${_ldflags_orig} ${_mold}`); `mold-git` provides `mold=${pkgver}` (no `command -v mold` guard needed).
- **Meson & Rust**: Meson uses `arch-meson` (`buildtype=release`); tracked raw-meson exceptions (`dbus-broker-git`, `flatpak-git`, `mesa-git`, `pixman-git`, `zbar`) convert only with dated evidence. `RUSTFLAGS` ships `-C opt-level=3 -C target-cpu=native` globally; re-append only if a recipe overwrites `RUSTFLAGS`.
- **Per-family tuning & Graphite**: GCC-only `-fipa-pta` and `-fprefetch-loop-arrays` live in `gcc-makepkg.conf`; Graphite (`-fgraphite-identity -floop-nest-to-graphite`) stays deferred (GCC loop-vectorizer miscompiles).
- **LTO patterns**: Meson `-Db_lto=true` (`mesa` +allow-broken-lto, `libadwaita`, `util-linux`, `systemd`, `dbus-broker`, `noctalia`); PGO phase-1 `-Db_lto=false` -> phase-2 `true` (`glib2`, `gtk3`, `gtk4`, `wayland`, `cairo`, `xwayland`, `libinput`, `pixman`, `noctalia`); manual make/CMake (`jemalloc`, `zlib-ng-compat`); `zstd` phase-2 only; `options=(!lto)` where LTO breaks (`rocm-llvm`, `hip-runtime`, `gcc-snapshot`, `niri-spicy-git`, `blender-git`); `llvm-git`/`rust-git` use `!lto` to block makepkg's `LTOFLAGS` while keeping upstream LTO; Zen uses mozconfig thin LTO.

## PGO Conventions

- **Phase-2 reconfigure**: Purge `build/` before phase 1 (`meson setup` no-ops on configured dirs) and run `meson setup --reconfigure` for phase 2 (clearing both compiler and linker caches). For CMake (`cmake-git`), rewrite flags *inside* `CMakeCache.txt` and `touch CMakeLists.txt` (deleting the cache loses prefix, `CMAKE_USE_SYSTEM_*`, and `mold`); never re-run `./bootstrap` in phase 2 (`-Werror=coverage-mismatch`).
- **Training workloads & thresholds**: Per-recipe `local` threshold (`pgo_min_gcda`, `pgo_min_profraw`, `pgo_min_samples`—not a `lib/pgo.sh` knob) gates phase 2; below threshold, fall back cleanly to plain (LTO-only / `-pgo=off`), never half-trained. Changes to thresholds require a `docs/JOURNAL.md` entry.
  - Examples: `mesa` (`vkcube` on lavapipe + `glxinfo`/`eglinfo`, on by default), `glib2`/`gtk`/`cairo` (`meson test`), `bash`/`zsh` (`make check` 900s timeout), `easyeffects` (sandboxed `dbus-run-session` + `--quit`, PID-scoped cleanup only), `wayland`/`libinput`/`util-linux`/`systemd` (opt-in env), `noctalia` (headless sway), `lz4`/`zstd` (external profiles), `mimalloc` (`-fprofile-update=atomic`), `mold` (self-link), `rust`/`niri` (`LLVM_PROFILE_FILE` + `llvm-profdata`, unset `sccache`).
- **C-autotools PGO (`jq`, `file`, `rsync`)**: Re-run `./configure` every phase (`make clean` keeps `CFLAGS`); phase 1 strips `-flto*` and matches `-fprofile-generate=<dir>` symmetrically with phase-2 `-fprofile-use=<dir> -Wno-error=missing-profile -Wno-error=coverage-mismatch` + restored LTO (`rsync` builds LTO+PGO cleanly on GCC 17).
- **Go PGO (`fzf`)**: Upstream bench + `--profile-cpu` merged with `go tool pprof -proto` -> `GOFLAGS+=-pgo=$srcdir/cpu.pprof` (`pgo_min_samples=500`, falls back to `-pgo=off`; note benchmark skew in comments; covered by `tests/fzf-pgo.sh`).

## Package-Family Special Cases

- **`rust-git`**: `bootstrap.toml` flags, 5 patches, `!lto` (lld cannot link GCC-LTO llvm-wrapper), explicit `x.py install rust-src`, wipe `dest-rust`/`dest-src` at top of `build()`.
- **Other notable overrides**: Zen browser (fortify 3->2, unset `HOST_CFLAGS`, 3-tier mozconfig PGO, `--enable-optimize=-O3`), `gcc-snapshot` (-O2 stage2–4, strip format-security), `qt5-base-git` (`cflags` + `nostrip`), `libadwaita`/`xdg-portal-gnome` (`--wrap-mode=default`), `dbus-broker` (units patch), `glib2` (schema/terminals patches), `staticlibs` (`lz4`/`pixman`/`mimalloc`/`libunwind`), `libreoffice-fresh` / `blender-git` (upstream flags/no-ops).
- **Electron/JS (`vscodium-insiders-git`)**: `!strip !debug !lto`, ccache + mold probe for native Node addons only; un-moldable recipes park in `packages/deprecated/` (`gsa -Ma` `package-drift`).
- **TeX Live (`texlive-texmf`)**: `arch=(any)` `!strip`, optimized by trimming whole splits; only SVN recipe (`gsa -Mccc` in `crates/gsa-maint/src/prune.rs` cleans `svn://`/`svn+` and `*.whl`, `tests/cleanup-extensions.sh`).
