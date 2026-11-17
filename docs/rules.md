---
permalink: gsa-recipe/docs/rules
title: rules
type: note
---

# gsa-recipe Rules & Boundaries

Full recipe-side rules indexed in [AGENTS.md](../AGENTS.md). Numbers preserve the retired shared numbering (`../gentoo-style-arch/docs/gsa-contract.md` and `../gentoo-style-arch/AGENTS.md` hold the engine half).

## Numbered Recipe Rules

1. **Cross-shell commands go through `bash -c '…'`**: `fish` lacks `export`/`[[ ]]`, uses 1-indexed arrays, fails on unmatched globs (`use find -name`), and aliases `ls`/`grep`/`rm`; stage `script -qec` bash quoting in a script file.
2. **Agent-shell git hardening (`GIT_CONFIG_COUNT=0`)**: Prefix every makepkg or bare-repo git command with `GIT_CONFIG_COUNT=0` (agent shells inject `safe.bareRepository=explicit`, breaking `?signed` checks and git-lfs fetches).
3. **Validate every `PKGBUILD` edit**: Run `bash -n PKGBUILD`, `GIT_CONFIG_COUNT=0 makepkg --printsrcinfo > .SRCINFO`, and commit `.SRCINFO` alongside `PKGBUILD`. `!check` and `autodeps` are invalid `options` under pacman 7.x.
4. **Provides discipline**: `-git` toolchains carry versioned double-quoted provides (`provides=("meson=${pkgver}")`, placed *after* `pkgver=`). Libraries declare bare sonames (`libfoo.so`); makepkg auto-versions them from ELFs. Request virtual capabilities (`java-runtime`, `libgl`), never concrete providers. Dynamic `provides+=()` inside `package()` extracts empty into `.SRCINFO`; rebuild to update `.PKGINFO` (`gsa -Ma` `provides-versioning`).
6. **Stale configure caches**: Purge build dirs with mismatched `meson-info.json` versions; rewrite flags *inside* `CMakeCache.txt` and `touch CMakeLists.txt` (never delete cache—prefix/`CMAKE_USE_SYSTEM_*`/`mold` vanish); purge stale `*.la` in `prepare()`.
7. **Never disturb an in-flight build**: Check running `makepkg` and log mtimes first; never run two heavy builds concurrently (OOM risk).
8. **Purged tools stay purged**: Never re-add `po4a`, `python-sphinx`, `python-myst-parser`, `lvm2`, `libblockdev-lvm`, `systemd-tests`, `cuda`, `gcc15` (`gsa -Ma` `purged-tools` enforces). Trim feature + output together with `# trim:` comments (disable explicitly against `arch-meson --auto-features enabled`).
10. **Journal & action exports**: Append one dense line (`symptom -> root cause -> fix -> validation -> rule`) to `docs/JOURNAL.md`, export detail to `.logs/action-<ISO>-<task>.md`, reset `.logs/scratchpad.md`, and delete finished §6 items.
13. **LLVM never moves alone**: Bump `llvm-git`/`llvm-libs-git` together with `rust-git`, `mesa-git`, `spirv-llvm-translator-git`, and `openshadinglanguage` (`abi=must`); recover corrupted `rust-git` using official stage0; resume with `--skip`, never `--skip-built`.
14. **Qt private-API coupling**: Rebuild all private-API consumers together on `qt{5,6}-base-git` bumps (`nm -D --undefined-only | grep QtPrivate_`); patch upstream lag in `prepare()`; set `MESON_FORCE_BACKTRACE=1` inside failing context.
15. **Never bypass source verification**: Never `--skippgpcheck` or drop `?signed`/`#signed`; verify primary fingerprint in `validpgpkeys` (with role comment) and import into build user's keyring (pin every multi-sig co-signer).
16. **Batch bulk `prepare()` work**: Cut inputs once, use shell builtins and `mv -t` (~500 files/call), and assert consumed counts.
17. **Recipes are public surface**: Comments explain code/kernel options/trims (note AMD target or personal absence)—never machine specs, thread counts, or incident history.
20. **Packaged venvs use runtime paths**: Rewrite launcher/finder/`.pth` paths from `$pkgdir` to final prefix and strip `__pycache__` before rewriting.
21. **Group membership is topology data**: `>= 2` consumers => `core` (unless `app-cluster`); compilers carry `core,build-tools`; cargo/rustc recipes declare a `rust-git` edge (`gsa -Ma` checks it); group edits preserve `abi=`/`app-cluster=`.
22. **Artifact-based fleet reconciliation**: Mirror scratch artifacts to session logs; reconcile by regenerated `.SRCINFO`/files, never agent self-reports; edge-union divergent record writes.
23. **Swap/ABI install contract**: `--ask 4` consents to removal only; Class A providers declare `provides=(<stock>=$pkgver)` and `conflicts=(<stock>)`.
24. **Source-merge & topology identity**: Merge same-upstream clusters into one recipe/record; keep split siblings pkgname-addressable (`=$pkgver-$pkgrel`); supersede via `X -> X-git` edges; trim unreferenced splits (`# trim:`); demote commit-pin tests to `SHARED-SRCDEST`.
25. **ABI closure (recipe half)**: `(a)` bare soname provides only; `(f)` review `config/abi-exclusions.conf` before `review-by`; `(i)` promote `>= 2` consumer records to `core` directly.
26. **Re-time `gsa -Sl` after roster jumps**: Never pin wall-times in fixtures.
27. **Strict `=` pins & multilib**: Avoid strict `=` pins on rolling `-git` sets; rebuild pinning `lib32` counterparts in the same wave with unversioned dep (`.1` pkgrel).
28. **Pin non-git build inputs**: Put git-absent data in `source=()` with checksums and fail-closed `prepare()` verification; never `SKIP` pinned `#commit=` (`GIT_CONFIG_COUNT=0`).
29. **Retire exact-pin stock leftovers before swap waves**: Sweep `expac -Q '%n\t%D' | grep '<pkgbase>='` and remove obsolete stock splits instead of rebuilding them.
30. **Soname beats pkgver**: Heal *every* direct NEEDED linker (`readelf -d`); remember running procs hold deleted inodes while new execs fail `127`; park incompatible upstreams (`#branch=`/`#tag=`), never symlink old->new.
31. **Signable `?signed` refs & meson options**: `#tag=...?signed` verifies tags, while floating `git+URL?signed` verifies unsigned HEAD (`b2sums=('SKIP')` without `?signed` for tag-only floating `-git`); `validpgpkeys` checks primary keys; validate `-D` options against `meson_options.txt`/`meson.options`.
32. **Audit dropped patches**: Check `nm -D` on `.so`s and diff multi-patch sets as a whole.
33. **Warm `$srcdir` hygiene**: Clean untracked state (`make clean` or `makepkg -c`), build twice without cleaning, and diff `nm -D`.
34. **Tool-materialized files & generators**: Accept generator copy layouts, keep generators in `makedepends`, and delete stamps before retrying (`Error 1 (ignored)`).
36. **Sweep stock ELF consumers**: `readelf -d` across `/usr/{bin,lib,libexec}` and `/opt` on soname-bumping replacements; land restorations with `gsa -S --leaf <provider> <consumers>`.
37. **Toolchain bumps**: Patch missing C++ includes across the whole vendored tree in one patch; drop `-Werror` on generated flex/bison; verify `install()` sets.
39. **Opt-out `mold` for GNU-ld-only embeds**: Strip `-fuse-ld=mold` in `build()` where `-b binary` is required (`libxdp`) alongside `!lto`.
40. **Never double-wrap `ccache`**: Drop `CMAKE_*_COMPILER_LAUNCHER=ccache` (`BUILDENV=ccache` already prepends `/usr/lib/ccache/bin`); run `ccache -C` after toolchain updates.
41. **CMake 4 policy floor**: Pass `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` only where `cmake_minimum_required` `< 3.5`.
42. **Pin system Python in CMake**: `-DPython_EXECUTABLE=/usr/bin/python3` / `-DPython3_EXECUTABLE=/usr/bin/python3` to bypass `~/.local/bin` uv/pyenv shims.
43. **Vendored Rust `.cargo-checksum.json`**: Update only the patched file's sha256 entry in `prepare()` (never touch package checksum).
45. **Parallel archive races (`lto1: file too short`)**: Fix ranlib/ar target ordering in the `make` invocation instead of `-j1`.
46. **`git apply` outside a repo**: Isolate with `GIT_CONFIG_COUNT=0 GIT_DIR="$PWD/.gsa-nogit" GIT_WORK_TREE="$PWD" git apply -p1` so outer repos do not skip hunks silently.
47. **Trimming split packages**: Disable features in configure (`--without-python*`), not only `makedepends`/`package()`.
48. **`package()` starts in `$srcdir`**: Qualify `$srcdir/$pkgname-$pkgver/LICENSE` or `cd` first.
49. **Vendor meson subprojects**: Wire wrap subprojects via `source=()` + `prepare()` symlinks (`realpath --relative-to`) + `packagefiles/` overlay + makedepends.
50. **Compat shims match upstream shape**: Replicate stdout/newline behavior (`lib/cups-config`, `tests/cups-config-shim.sh`).
51. **Co-installable recipe outputs**: Mutually exclusive variants are separate recipes with `provides` + `conflicts`.
52. **Justified topology edges**: Edge consumers when fresh hosts lack house providers (`pacman -T` audit; never mass-add).
53. **Probe `ccache` wrapper**: `gsa-pm` runs `cc --version` and drops broken `ccache` from `PATH` rather than symlinking soname gaps.
54. **Linked libraries in `depends`**: Gate via `gsa --qa-check declared-deps` after `.SRCINFO` regen; spell `.so` only when provider stamps its provide.
55. **Direct NEEDED consumers on soname bumps**: Detect with `ldd | grep 'not found'` and rebuild direct consumers first.
56. **Non-interactive `--noconfirm`**: Pass `--noconfirm` to all `makepkg -s` chains (`makepkg -sfC --noconfirm`).
58. **Living docs teach how to check**: Probe via `gsa -Sl`/`pacman -Q`; keep retired spellings only in engine contract §B.9.
60. **Build-domain isolation**: Never write `/var/lib/gsa` from recipes; store resolves via `GSA_RECIPES_DIR` > `recipe_dir` > `~/.local/share/gsa/recipes`.
61. **Validate installed `/usr/bin/gsa`**: `gsa-pm` stays git self-tracking (no `_commit` pin); deploy via `sudo gsa -Sy && sudo gsa -S gsa-pm` then `tests/run-all.sh`.
63. **Volatile `-Sy` store**: Copy uncommitted `-Sy` rewrites into dev tree, verify fetch-only sums independently, and preserve authored `pkgver`/`pkgrel`.
64. **Monday-boundary `#commit=` pins**: Pin `@core`/`@build-tools` moving VCS sources to last commit <= Monday 00:00 UTC (`<id>-snapshot` is input alias only; keep `-git` id/provides; `docs/snapshot-expansion.md`).
65. **Hash inputs first**: `sha256sum` + `ls --time-style=full-iso`; one writer per mutable tree.
70. **Clean build tree on flag edits**: Wipe meson `build/` and force rebuilds when flags change.
75. **`SRCDEST` authority**: `/etc/gsa/gsa.conf` `srcdest` (`~/.gsa-src`) only; keep `env | grep SRCDEST` empty (`env -u SRCDEST`).

## Working & Git Discipline

- Login shell `fish` wraps `rm` as trash; pass user commands via `bash -c '...'` and prefix makepkg/bare-repo git with `GIT_CONFIG_COUNT=0`.
- Commit trailers (in order): `Assisted-by: LLM (human-reviewed)` then `Signed-off-by` matching git identity (no `Co-authored-by`). Never commit/push unprompted.
