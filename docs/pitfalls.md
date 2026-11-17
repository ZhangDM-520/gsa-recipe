---
permalink: gsa-recipe/docs/pitfalls
title: pitfalls
type: note
---

# gsa-recipe Pitfalls & Mechanisms

Detailed pitfall mechanisms indexed in [AGENTS.md](../AGENTS.md). Engine-side halves live in `gentoo-style-arch/AGENTS.md` / `gentoo-style-arch/docs/pitfalls.md`.

## Recipe Files, Patches and Sources

- **Public comments**: Never embed host-specific facts in tracked recipe comments.
- **Metadata generation order**: Regenerate `.SRCINFO` after any `PKGBUILD` edit (`tests/srcinfo-freshness.sh`); place `provides=` *after* `pkgver=`; keep `provides` static at top level (inline `package()` `provides+=` extracts empty/bare `.so`).
- **`b2sums` knob counts**: Add parse-time guard printing both counts and knob values (exempt `GENINTEG=1`); verify quickly with `makepkg --verifysource`.
- **Patch traps**: Vendor pinned GitHub `.patch` bodies (GitHub re-renders headers); drop all-zero `index` old-SHA lines; validate `git apply -3` by content on fresh clones (`--check` false-passes). Keep bridge-patch drop conditions in headers + `prepare()` assertions (`git log -S <symbol>` to retire).
- **Version-scoped patches & kernel `.config`**: Tag-pinned bumps invalidate patches/sums; kernel patches scope by `${_major}` (`updpkgsums` uses `startdir` cache); verify kernel options on post-`make prepare` `.config` (`!SYM != SYM=n`).
- **Implicit install sets, `source=()` parsers & `pkgver()`**: Enumerate shipped trees against `_pick` lists (`var/run` belongs to `filesystem`) and invoke explicit install steps (`x.py install rust-src`); source scanners must parse `url`, `git+url`, `name::git+url`, bare `git://`; prefer version files over build metadata in `pkgver()` (Qt uses `QT_REPO_MODULE_VERSION` in `.cmake.conf`).
- **PGP & `?signed`**: `?signed` errors are usually missing `GIT_CONFIG_COUNT=0` (never drop `?signed`); expired keys whose signatures predate expiry verify with a warning—keep `#signed`/`validpgpkeys` and record re-key contingency.

## Swap Providers, Provides and Sonames

- **Full stock swap surface**: Match every stock `pkg-config` name, versioned `provides` for every split output, and consumer API generation.
- **Bare sonames & `provides-audit.sh`**: Declare `libfoo.so` (matching measured ELF soname, e.g. `libxerces-c-3.3.so`); verify with `pacman -T` and `tools/provides-audit.sh`; bump `pkgrel` strictly past `pacman -Qi` (`stock+.1` can collide).
- **Python, dual-owned files, Tcl, licences & `DESTDIR`**: Pin `-DPython_EXECUTABLE=/usr/bin/python` (`Python3_EXECUTABLE`); expect dual-owned file loss (`terminfo` between `ghostty` and `ncurses-git`) and reinstall survivor; glob `tcl*/` (`TCL_LIBRARY` is `zipfs:/` on Tcl 9); `install -d` before `cp -a` in loops; `rm -rf dest-*` at top of `build()`.

## Build Systems and Toolchains

- **House toolchain target/version skew**: House LLVM builds `X86;AMDGPU;BPF` (no NVPTX); probe headers and `readelf -W --dyn-syms` before patching. `ld.lld` rejects GCC-LTO objects (`!lto` for rustc-linked recipes; `-ffat-lto-objects` for static archives, inspect with `ar p ... && gcc-nm <file>`).
- **Linker & configure probes**: Use `-fuse-ld=bfd` last in `glibc`; pass `-Wl,--undefined-version` for mold version-script checks (`readelf -V`). Meson `--auto-features enabled` fails on missing `auto` deps; use `--enable-`/`--disable-` explicitly; `-Db_pgo=off` (not `none`).
- **Dead `makedepends`, `USE_SYSTEM_*` & CMake jobs**: Trim dead `makedepends` and build paths together; audit `USE_SYSTEM_<X>=ON` against `makedepends`; pass `cmake --build build --parallel "${GSA_BUILD_JOBS:-$(nproc)}"` (`CMAKE_BUILD_PARALLEL_LEVEL`).
- **Upstream header/ABI drifts**: Guard compat shims with version checks + `dep.found()`; feed `cups 2.5` flags via `CPPFLAGS` (`$(pkg-config --cflags cups)`); patch `CMAKE_CXX_STANDARD` >= 17 in `prepare()` for ICU 76+; preserve `/usr/lib/cmake/zstd/`; symlink `_libs -> .libs` when libtool shifts; patch git-snapshot version checks (`cmake -P`); replace nested-aggregate NSDMIs in default args with inline overloads; `-fno-tree-vectorize` (not `-mno-avx512*`) for miscompiled tolerant word scans; wipe warm build trees on flag changes (rule 70).
- **Static flags, Chromium `.rsp`, `cargo test` & GHC**: Resolve `glog`/`gflags` double-registration via `WITH_SYSTEM_*`; keep short `_build_dir` for Chromium; skip `cargo test` integration mismatches (`BUILDENV=(!check)`); match GHC package-set way (`cabal.project`, no mold on prebuilt `.so`); preserve upstream `checkdepends` tests with documented skew rather than deleting tests.

## PGO, Sandboxing and Packaging Traps

- **PGO gate & sandboxes**: `verify_no_profile_instrumentation "$pkgdir"` must be the fatal last line of every `package*` (never `|| return 1`); fallbacks wipe `build/` and rebuild clean; bump `pkgrel` after first post-sync build and regen `.SRCINFO` last. Keep sockets in short `mktemp -d` (`sun_path` 108 bytes), tear down as group, unset `WAYLAND_DISPLAY`.
- **Concurrency, tail guards & polluted `$srcdir`**: Serialize SVG doc builds (`make -C doc -j1`); write function-tail guards as `if ... fi` (never `[[ -f ]] && cmd`); make staging dirs idempotent and re-extract clean trees for file-creating patches; detect dead `clone -s` mirrors (`git show-ref`) and failed-fetch VCS husks (wipe `$srcdir`/`$SRCDEST` and re-fetch).
- **Perl paths, shims, consumer patches & edges**: Export `PATH="/usr/bin/core_perl:$PATH"` for `pod2man`/`prove`; `install -Dm755` tool shims into `build()` `PATH`; align consumer `source=`/`sha256sums=` positionally; record tool/cargo `rust-git` edges in `config/topology.conf`.

## Host Safety and Forensics

- **Freeze quarantine**: Three deterministic host freezes retire a recipe (`--jobs 2`, single lane + kernel pstore forensics required to re-add; `_capture_chain=yes`, `WQ_WATCHDOG`/`PSTORE_CONSOLE`).
- **Unclean shutdowns, mkinitcpio, removed deps & silent failures**: Verify Go caches (`go mod verify` / `go clean -modcache`); guard systemd hook changes in `mkinitcpio` recipe; on `target not found`, drop output/provides/makedeps and disable feature together; wrap silent `ENOSPC`/filtered build tools with `tee`.
