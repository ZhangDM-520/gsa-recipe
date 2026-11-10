# AGENTS.md — memory management & entry point

`AGENTS.md` (this file) is the global memory — overview, long-term rules, one
line per pitfall MECHANISM, queued work; `docs/JOURNAL.md` is the historical
log (incidents, dates, measurements), one dense line per action; `.logs/scratchpad.md` is the active buffer (a tracked stub,
reset after every action) and `.logs/action-<ISO>-<task>.md` the per-action
exports, never tracked. A
finished queue item is **deleted**, never ticked.

## 0 · What this repository is

The recipe half of the `gsa` system: `packages/<category>/<id>/` recipe
modules and the declarative topology that orders them.

- `packages/<category>/<id>/` — `PKGBUILD` is the source of truth; the
  generated `.SRCINFO` is committed beside it. Local patches, hooks, install
  scripts, desktop files, config snippets, and upstream licence material
  (`LICENSE`, `LICENSES/`, `REUSE.toml`) ship with the recipe. A generated
  `PKGBUILD` commits its generator pair (`PKGBUILD.in` + `update.PKGBUILD`).
  Physical categories are `git`, `stable`, `core`, `misc` plus the reserved
  `deprecated` tier (parked, in no build list) — logical groups overlap them
  deliberately, so never infer group membership or build order from a path.
- `config/` — exactly three files. `topology.conf` holds one record per
  package, `id|path|groups|edges[|tags]`, and is **the only place** that binds
  an id to a recipe path; `build-defaults.conf` holds lanes/jobs/intensity and
  the memory budgets; `abi-exclusions.conf` holds `id|reason|review-by` rows.
  Anything else under `config/` is unreachable state and `tests/project.sh`
  fails on it.
- `lib/` — shared build helpers sourced from recipes: `pgo.sh` (the one PGO
  payload gate, `source "$startdir/../../../lib/pgo.sh"`) and `cups-config`
  (the CUPS compatibility shim).
- `tools/` — host-side diagnostics, deliberately outside the fixture battery:
  `nvcheck.sh`, `provides-audit.sh`, `go-modcache-check.sh`,
  `abi-need-check.sh` + `abi-need-check.hook`.
- `tests/` — the fixture battery (`tests/run-all.sh`) that validates this
  repository through the **installed** `gsa`. `tests/assets/` is frozen oracle
  material and is never discovered; `tests/lib/` holds shared synthesis
  helpers (`.bash`, never executed standalone).

**Boundary.** The engine lives in the `gentoo-style-arch` repository and is
consumed here as the installed binary `/usr/bin/gsa`. Never vendor, patch, or
rebuild the engine in this repository; engine defects and engine rules belong
there. `packages/core/gsa-pm` packages that binary and is git self-tracking —
it carries no `_commit` pin.

### Durable stack shape

Durable shape of the stack, re-verified 2026-10-17 against the committed
recipes and, where the claim is about installed names, against the installed
database. Deliberately no version numbers: they rot within days and `pacman -Q <pkg>` is authoritative. Dated
install history lives in `docs/JOURNAL.md`.

- **llvm-git is DELIBERATELY MINIMAL**: `-D LLVM_TARGETS_TO_BUILD="X86;AMDGPU;BPF"`
  — the BPF backend exists so `scx-scheds-git` can build its BPF skeletons with
  `clang -target bpf`. `rust-git` is built against this llvm-git, so both move
  together (rule 13, §5).
- **Qt dev stack**: every Qt6/Qt5 private-API-coupled module is house-built;
  `qt5-base-git` carries `-ffat-lto-objects` for the LTO-strip hazard (§5).
  `pyside6-git` is scoped with `-DMODULES='Core;Gui;Widgets'` because the rest
  of Qt is still stock. Stock-only by design: `qt6-translations` — the claim
  no longer covers `qt5ct`/`qt6ct`: both are release-tracked house recipes
  (`packages/core/qt5ct`, `packages/core/qt6ct`), `app` members carrying
  `abi=must` against house Qt.
- **Toolchain `-git` packages carry VERSIONED provides** (`meson-git` →
  `meson=<ver>`, likewise ninja-git, cmake-git, doxygen-git) — unversioned
  provides cannot satisfy `>=N` makedepends (rule 4).
- **GIMP/Krita chain**: `gimp-git` ships upstream's dev naming — the binary is
  `gimp-3.3`, there is no `/usr/bin/gimp` — and declares only a bare `gimp`
  provide. `krita-git` and `cairo-git` declare versioned provides
  (`krita=…`, `cairo=…`) plus bare soname provides; `babl-git`/`gegl-git`
  ship soname provides. `pacman -Dk` must stay free of chain errors and `ldd`
  must resolve babl/gegl from the house packages.
- **util-linux**: built with `-Dbuild-python=disabled` and
  `-Dtranslate-docs=disabled` (po4a was purged; the feature HARD-FAILS rather
  than skipping, §5). Its `libuuid`/`libblkid` verdefs need mold's
  `-Wl,--undefined-version` (§5).
- **linux-firmware** is trimmed to the maintained hardware set (`amd-ucode`,
  `linux-firmware-amdgpu`, `linux-firmware-mediatek`,
  `linux-firmware-cirrus`). In `pipewire`, the `pipewire-jack` split is
  NOT built because it conflicts with the system's `jack2`, while
  `pipewire-jack-client` is kept. `easyeffects-git` replaced `jamesdsp-git`.
- **blender-git** pairs with house `openshadinglanguage` (same LLVM coupling as
  §5 describes).
- **gcc-snapshot carries a house compiler patch in `prepare()`** (2026-10-09):
  `verify_ctor_sanity` is made a no-op for PR c++/127395 (a r17-4199
  regression false-positiving on abseil/protobuf headers, §5). It is a
  heredoc patch, NOT a `source=()` entry, because the recipe is
  version-sync-anchored (rule 18). Drop-condition is recorded in the
  patch comment: remove the block once the upstream fix lands in a snapshot
  we build.
- **Auto-nice daemon**: `packages/stable/aranicy` (clean-room MIT rewrite of
  `ananicy-cpp`; eBPF exec events, ananicy-compatible JSONL rules) holds the
  role and `/etc/ananicy.d`. Owner fact: it provides NO name — the record
  carries `conflicts=(ananicy-cpp)` only, because both daemons own the
  auto-nice role and the rule dir; the installed `cachyos-ananicy-rules` data
  stays and stays compatible. Live swap state and cutover: `docs/CURRENT.md`;
  gate numbers and the owner's rewrite decision: `docs/JOURNAL.md` 2026-10-22.

### Key dependency edges

glib2 -> pango -> cairo -> gtk3/gtk4 -> libadwaita; liburing -> libdex ->
xdg-desktop-portal; qt6-base -> pyside6 and the Qt6 modules; qt5-base ->
the Qt5 modules; ninja -> meson; rocm-core -> rocm-llvm -> hsa-rocr ->
hip-runtime; llvm -> SPIR-V/libclc/rust; rust -> rust-bindgen; babl -> gegl
-> gimp; openssl -> openssh/openvpn/git/LibreOffice; LLVM ->
OpenShadingLanguage -> blender.

### Landmines / one-offs

- `libisl-git` tracks a package whose repository name differs; do not let
  automatic stable synchronization rewrite it blindly.
- Qt private APIs and LLVM snapshots require consumer rebuild batches.
- Shared mirrors must have the exact origin URL and a usable fetch refspec.
- A populated non-Git source path is never replaced automatically.
- Build in the runtime clone, never in this repository. A run started here left
  24 GB of SVN checkout, split tree and packaging state inside the published
  repository's directory (recovered by `rm -rf` on the four ignored paths). The
  recipes are ignored-safe, but nothing about a build belongs here — and
  engine logs live under the state root (contract §J), outside the clone by
  default since the 2026-10-14 cutover (`--state-dir PATH`/`GSA_STATE_DIR`
  choose where).
- `texlive-texmf`'s `prepare()` MOVES ~150k files out of `$srcdir/texmf-dist`,
  so that tree is single-use: a resume over an already-split checkout fails on
  purpose (13,870 of 150,746 runfiles were gone in this one) and needs
  `rm -rf src`. It also needs ~38 GB on disk, not the ~3.5 GB of data, because
  each SVN working copy keeps a 9.1 GB `.svn/pristine` shadow.

## 1 · Read before changing anything

| File | Role |
| --- | --- |
| `README.md` | What the set is for: rebuild a coupled desktop and toolchain stack from recipes as one coherent, locally tuned system. |
| `docs/maintainer-guide.md` | The recipe-maintenance manual: groups, recipe registration, version-synced external releases, the `app` group, coupled-stack updates, the journal-entry format. |
| `docs/package-policy.md` | What a recipe directory may hold versus what is fetched at build time; the generator pair, the `.SRCINFO` contract. |
| `docs/source-sharing.md` | The shared-source mirror contract (`gsa -Mm`) and what qualifies as a valid canonical mirror. |
| `docs/snapshot-expansion.md` | The Monday-boundary snapshot-pin programme: reconciled state, exclusions, waves, engine work (names stay `-git`; `<id>-snapshot` is a `gsa` frontend alias) |
| `docs/CURRENT.md` | The umbriel stack live snapshot — overwrite, never append; owned by a parallel session lane, so never edit it from a rebuild-campaign lane. |
| `docs/adr/0001-pgo-shared-gate.md` | Why PGO verification is one shared module with per-recipe calls and fatal semantics; read before touching `lib/pgo.sh` or any `package*` tail. |
| `docs/adr/0002-topology-one-record.md` | Why one topology record per package replaced four syntaxes; read before adding, merging, or splitting records. |
| `CONTEXT.md` | The vocabulary: recipe, topology record, build-order edge, consumer expansion, coupled batch, lane, run record, deferral — with the terms to avoid. |
| `CONTRIBUTING.md` | The recipe-change checklist, the trimming standard, source-verification rules, the validation block, ABI-batch discipline. |
| `SECURITY.md` | The trust model: a recipe is arbitrary shell at makepkg privilege; review before building, and never commit secrets, sources, archives or build output. |

Engine documents stay in the engine repository (`ZhangDM-520/gentoo-style-arch`),
because this half ships no engine source: `docs/gsa-contract.md` is the
authoritative `gsa` interface, `docs/build-guide.md` the inspect/dry-run/build
and PGO-reconfigure procedure, `docs/architecture.md` the crate split, and
`docs/portability.md` the intensity profiles. A rule body that names one of
those paths means "read it in the engine repo"; everything else in this file is
local.

## 2 · Commands

```sh
bash tests/run-all.sh                    # whole battery, parallel by default
bash tests/run-all.sh recipe             # substring filter; a typo exits 2
bash tests/run-all.sh --serial           # one at a time, debugging a flaky fixture
GSA_TEST_GSA_BIN=/path/to/gsa bash tests/run-all.sh   # a dev build (pre-install deviation)
bash -n packages/<cat>/<pkg>/PKGBUILD    # recipe parse
GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<pkg> \
  > packages/<cat>/<pkg>/.SRCINFO        # regenerate committed metadata
gsa -Sl @git                             # ordered listing (re-validates map, graph, sort)
gsa -Ma                                  # audit lints — report-only, exit 0; READ the report
gsa -S --dry-run @git                    # plan + decision rows, no mutation (repeat @stable, @core)
gsa -S @core                             # ABI-coupled core update: build each, install before its consumers
```

- `tests/run-all.sh` discovers fixtures recursively, so a new fixture needs no
  runner edit. It defaults to the installed engine on `PATH`, prints the
  binary and its owning package, and reports `GSA_TEST_GSA_BIN` as an explicit
  pre-install deviation from the smoke-the-installed-engine contract.
- Fixtures are non-mutating and `$TMPDIR`-scoped: they synthesize workspaces
  and PATH stubs, never touch this checkout, and must stay safe to run
  concurrently. A new fixture that breaks that is a fixture bug.
- `gsa -Ma` is report-only by design — the exit status stays 0, so a green run
  is not a clean audit. Read the report.
- Never use a real rebuild as a syntax check.

## 3 · Rules

**Rule map.** Numbers are preserved from the pre-split `MEMORY.md` so that
existing recipe comments and journal lines still resolve here; superseded and
renumbered entries are called out in place: **5 → 14** (folded into the Qt
rule), **20** is the venv rule (the install-seam 20 stays engine-side),
**64** is the weekly snapshot-pin rule (the second 64, `SRCDEST`, is **75**),
**38** is superseded by the engine's sync phase and its surviving half lives in
rule 63, **62** is superseded by engine rule 73.

1. **Fish is not bash** — hand any cross-shell command to `bash -c '...'`:
   fish has no `export`, no `[[ ]]`, 1-indexed arrays, and an unmatched glob is
   fatal (`2>/dev/null` cannot suppress it) — use `find -name`. Aliases rewrite
   bare `ls`/`grep`/`rm`. `script -qec` parses with `$SHELL`, so stage bash-only
   quoting in a script file.
2. **Agent-shell git hardening** — agent shells inject
   `safe.bareRepository=explicit`, so every makepkg or bare-repo git operation
   needs `GIT_CONFIG_COUNT=0` (the user's own fish shell does not). Without it,
   `?signed` tag checks report `SIGNATURE NOT FOUND` and git-lfs fetches exit
   128, leaving an empty LFS store that extracts as `remote missing object`.
3. **Validate every PKGBUILD edit** — `bash -n PKGBUILD` and
   `makepkg --printsrcinfo >/dev/null` before calling it done, then regenerate
   the committed `.SRCINFO`. `!check` and `autodeps` are invalid `options`
   entries; pacman 7.x lint rejects them.
4. **Provides discipline** — `-git` toolchains carry *versioned*, double-quoted
   provides (`provides=("meson=${pkgver}")`; single quotes fail) and the
   assignment must come after `pkgver=`, or it expands empty and makepkg
   rejects the parse. Library packages declare *bare* sonames (`libfoo.so`) and
   let makepkg auto-version from the packaged ELF; never hand-version a soname,
   never spell `X.so.N`; a mapped name stays versioned. Dynamic provides must
   come from a helper — an inline
   `provides+=()` in `package()` extracts empty into `.SRCINFO`. Request
   capabilities through their virtual (`java-runtime`, `java-environment`,
   `libgl`), never through one concrete provider. Provides live in `.PKGINFO`:
   a provides change needs a real rebuild, and `gsa -Ma`'s `provides-versioning`
   lint is the enforcement.
6. **Stale configure caches** — purge every build dir whose `meson-info.json`
   version differs (`find`, any depth); rewrite flags *inside* `CMakeCache.txt`
   and `touch CMakeLists.txt`, never delete the cache (prefix,
   `CMAKE_USE_SYSTEM_*` and `-fuse-ld=mold` vanish); `make clean` fixes
   neither. Purge stale `*.la` in `prepare()`. Engine side: gentoo-style-arch
   AGENTS.md rule 6 (the GCC-LTO `toolchains/` marker).
7. **Never disturb an in-flight build** — check for running `makepkg`
   processes and for runtime-log mtime changes before rebuilding a package
   that may be in flight, and never run two heavy builds at once: the failure
   mode is an OOM, not a queue.
8. **Purged tools stay purged** — `po4a`, `python-sphinx`,
   `python-myst-parser`, `lvm2`, `libblockdev-lvm`, `systemd-tests`, `cuda`,
   `gcc15` must never re-enter `makedepends`; makepkg silently reinstalls them.
   The engine's denylist is authoritative — `gsa -Ma`'s purged-tools lint
   enforces it.
   Trim a feature and its output together, with a `# trim:` note at each site;
   disabling it in `build()` is not enough when the build system defaults the
   feature on (`arch-meson` runs `--auto-features enabled`).
10. **Logs** — every non-trivial recipe change lands one dated line in
    `docs/JOURNAL.md`; a bare "fixed X" is not an entry, and the detail never
    goes into a recipe comment (rule 17). Anything that outgrows a line lives
    in that action's `.logs/action-<ISO>-<task>.md` export.
13. **LLVM never moves alone** — LLVM snapshots have no stable C++ ABI: after
    any `llvm-git`/`llvm-libs-git` bump, rebuild `rust-git`, `mesa-git`,
    `spirv-llvm-translator-git` and `openshadinglanguage` in the same pass, or
    rustc corrupts its heap. Recover by rebuilding `rust-git` — its bootstrap
    uses the downloaded official stage0, so no working system rustc is needed.
    Resume with `--skip`, never `--skip-built`. Engine side: the `abi=must`
    gate adds omitted members.
14. **Qt private-API coupling** — a `qt6-base-git`/`qt5-base-git` bump, or any
    Qt module that regenerates headers, breaks consumers built against the old
    headers: rebuild every coupled module in the same pass and verify private
    tags with `nm -D --undefined-only | grep QtPrivate_`. Never `-Syu` a fresh
    base-git while stock modules remain installed. When upstream lags, adapt in
    `prepare()` with `sed`. Meson's "unhandled python OSError" is masked — set
    `MESON_FORCE_BACKTRACE=1` inside the failing context, not interactively.
15. **Never bypass source verification** — never `--skippgpcheck`, never drop
    `#signed`, and `?signed` makes a signature mandatory: an unsigned upstream
    then fails, which is the point. `git verify-tag`/`gpg --verify` names the
    signer; confirm a subkey's fingerprint against the published primary key,
    pin it in `validpgpkeys` with a comment naming its role, and import it into
    the **build user's** keyring (an unimported pin fails `unknown public key`).
    Pin every co-signer of a multi-signature `.sig`.
16. **Batch bulk `prepare()` work** — per-file shelling costs spawns, not
    bytes: cut the input once, prefer builtins, batch syscalls (`mv -t`, ~500
    files per call). A loop that moves its inputs must count consumed files and
    stop, or the package silently lacks files.
17. **Recipes are public surface** — a recipe comment explains code, a kernel
    option or a trim; never the machine it was written on. Versions, thread
    counts, bootloader lines and incident history go in the journal. Name
    platform-driven trims (AMD laptop, amdgpu/radeon) and say when a trim is a
    personal capability absence.
20. **Packaged venvs use runtime paths** — a venv shipped by `package()`
    references the final prefix, never `$pkgdir` or a staging path: rewrite
    launcher and metadata references and fail the package if any build-source
    reference remains. Editable installs also need the finder and `.pth`
    rewritten, with `__pycache__` stripped first.
21. **Group membership is topology data** — ≥2 build-order consumers ⇒ `core`
    (exception: `app-cluster` members); compile toolchains carry
    `core,build-tools`, and `build-tools` is dispatch priority only — it never
    overrides an edge or the topological order. Group moves never touch
    `abi=`/`app-cluster=` tags. Any recipe invoking cargo/rustc declares a
    `rust-git` edge; `gsa -Ma` lints that edge.
22. **Fleet work is reconciled by artifacts** — mirror scratch artifacts to
    session storage as they are written; reconcile by verified deliverables,
    never by result order, `idle` status, or a cap rejection; edge-union
    divergent record writes after re-checking; resume partial state first.
    Reject self-reported validation: a clean `.SRCINFO` regeneration is the
    evidence, not a claim.
23. **Swap/ABI install contract** — `--ask 4` auto-confirms the conflict
    question: that is removal *consent*, not safety; the safety argument lives
    in the plan rows. A Class A provider declares
    `provides=(<stock>=$pkgver)` **and** `conflicts=(<stock>)`. Engine side:
    gentoo-style-arch AGENTS.md rule 23 (provide-drift refusal before the force
    branch, tier-1 exposure never excludable).
24. **Source-merge and topology identity** — same-upstream clusters merge into
    ONE recipe and ONE topology record; old split names stay
    pkgname-addressable only. Supersession is X→X-git edges, never record
    deletion. Merged split siblings pin `=$pkgver-$pkgrel`; unreferenced stock
    splits are trimmed with a `# trim:` note; commit-pinning tests demote to
    `SHARED-SRCDEST`.
25. **ABI closure — the recipe half** — (a) bare soname provides only, makepkg
    auto-versions; hand-versioned is forbidden. (f) `config/abi-exclusions.conf`
    rows are `id|reason|review-by` and must be reviewed before `review-by`.
    (i) any record with ≥2 edge-consumers carries `core`, by promotion, with no
    debt register. Engine side: gentoo-style-arch AGENTS.md rule 25 for the
    closure/exposure QA, link truth and the wave direction.
26. **Re-measure after a roster jump** — after adding a batch of records,
    re-time `gsa -Sl`; never pin a wall-time in a fixture expectation — a
    timing assertion blocks the performance work that removes the latency. The
    loader re-validates every record, edge and full sort on every invocation.
27. **Two version surfaces, two rules** — (b) strict `=` pins defeat a rolling
    `-git` set; on a multilib rebuild, rebuild the pinning lib32 counterpart
    with an unversioned dep in the same wave (local `.1` pkgrel). Never fake a
    version. Engine side: gentoo-style-arch AGENTS.md rule 27(a) — archive
    matching uses the full `epoch:pkgver`.
28. **Pin build inputs git does not carry** — git-absent build data (e.g.
    opus `dnn/*_data`) goes in `source=()` as checksummed entries, never as an
    out-of-band `prepare()` download, with a fail-closed `prepare()` guard that
    prints both digests. Sources must clone at the pinned ref; a rotten ref is
    mirrored by identical commit ids with provenance. Never `SKIP`; a real
    `#commit=` checksum needs `GIT_CONFIG_COUNT=0`.
29. **A swap wave retires exact-pin leftovers, never rebuilds them** — a
    soname-bumping swap rebuilds every installed pinner in one
    `pacman -U --ask 4` transaction; FIRST retire the stock leftovers that
    exact-pin the swap set — one `gst-plugin-pipewire`'s
    `pipewire=1:1.6.9-1` blocked every pkgrel bump, and rebuilding it re-adds a
    trimmed output plus a lockstep pin. Sweep with
    `expac -Q '%n	%D' | grep '<pkgbase>='`.
30. **Soname beats pkgver** — (a) a soname-healing wave covers EVERY direct
    linker (content scan plus `readelf -d | grep NEEDED`); victims' consumers
    heal transitively, victims never — the icu79 wave rebuilt 3 of ~10 and
    stranded Qt6Core. (b) Old processes survive deleted inodes while every NEW
    exec dies rc=127: check `ldd`/loader errors before touching config.
    (c) Installability is decided by EXACT pinners of the OLD provide in the
    local DB; park at the last compatible generation (`#branch=` while post-tag
    fixes flow, verified `#tag=` when finished) and never symlink old→new.
31. **A `?signed` source must pin a signed ref, and pins name the ACTUAL
    signer** — makepkg verifies the RESOLVED ref: `#tag=…?signed` verifies the
    tag, while a floating `git+URL?signed` verifies the unsigned tip and fails
    `SIGNATURE NOT FOUND`. Tag-only-signing upstreams: a floating `-git` uses
    plain `git+URL` with `b2sums=('SKIP')`, while every pinned artifact and
    `#tag=` keeps `#signed`/`?signed`. `validpgpkeys` names the actual signer
    from `git verify-tag`/`gpg --verify`; makepkg matches the PRIMARY
    fingerprint, so subkeys are documentation and `unknown public key` is a
    keyring gap. Also validate every `-D` option against
    `meson_options.txt`/`meson.options` types: `arch-meson` passes
    `--auto-features enabled`, `-D tests=false` is invalid for a feature
    option, and `Unknown option` means upstream renamed it.
32. **A dropped patch must be checked for what it replaced** — after build-flag
    surgery, `nm -D` the shipped `.so` for symbols the removed code defined;
    when taking one patch from a multi-patch set, diff the set whole and carry
    its dependencies. makepkg exit 0 is not evidence.
33. **A clean-tree fix is not a run-path fix** — makepkg re-extraction keeps
    untracked in-tree outputs, and make without header deps never rebuilds `.o`
    when only a patched header changed. Treat an existing `src/` as poison: the
    recipe cleans it (`make clean` after configure) or you rebuild with `-c`,
    and you validate by building twice without cleaning and diffing `nm -D`
    both times.
34. **Installed files may be tooling-materialized** — `bootstrap`/`autogen`/
    gnulib `COPYING` follow the *tool's* copy list: accept every layout or
    re-derive the path, and re-check after a tooling bump (`git status` proves
    nothing for gitignored files). Generator-installed output needs its
    generator in `makedepends`; delete stamps before re-testing, since
    `Error 1 (ignored)` retries stick.
36. **An in-set library that replaces stock with a soname bump breaks every
    stock binary** — sweep installed ELF consumers (`readelf -d` over
    `/usr/bin`, `/usr/lib`, `/usr/libexec`, `/opt`) and rebuild each in-set
    replacement in the same wave. A tool dying at launch with
    `error while loading shared libraries` is this class. A restoration park is
    still a move: land it with `gsa -S --leaf <provider> <consumers>`, never
    `-Ua`.
37. **A toolchain bump is a compile-compatibility transition** — it replaces
    `/usr/bin/g++`, and later builds compile against new libstdc++ headers
    whose include cleanup breaks vendored C++ (`std::ostringstream` without
    `<sstream>`). Patch explicit includes against the pinned source, scanning
    the whole vendored tree in ONE patch (ninja stops at the first failure);
    never pin an older toolchain. In generated flex/bison output drop the build
    system's `-Werror` promotion at the recipe seam but keep the warning, and
    verify `install()` file sets before disabling a feature mode.
39. **Strip `-fuse-ld=mold` when the build needs a GNU-ld-only feature** —
    `libxdp` embeds BPF blobs via `gcc -r -Wl,--format=binary`, which mold
    refuses (`-b binary` unsupported). Strip it in `build()` at the same seam
    as `options=(!lto)`; never patch the build system around the embed. Scan
    build-rule files only — linker sources merely mention the flag.
40. **Never double-wrap ccache** — `BUILDENV=ccache` already puts
    `/usr/lib/ccache/bin` first on `PATH`; a CMake recipe that also sets
    `CMAKE_*_COMPILER_LAUNCHER=ccache` compiles as
    `ccache /usr/lib/ccache/bin/cc …`, so the cache key pins the farm symlink's
    frozen mtime, `compiler_check = mtime` misses toolchain changes, and stale
    slim-LTO objects die at link. Drop the launcher; run `ccache -C` after
    every toolchain update.
41. **Sub-3.5 `cmake_minimum_required` gets the policy floor** — pass
    `-DCMAKE_POLICY_VERSION_MINIMUM=3.5`, because CMake 4 dropped pre-3.5
    compatibility and configure dies about one second in. Confirm the upstream
    floor before adding the flag; on a modern project it is no-op churn.
42. **Pin the interpreter a build finds** — a build that runs a python module
    through `find_package(Python3)` must pin
    `-D<Var>_EXECUTABLE=/usr/bin/python3`: `~/.local/bin` leads `PATH` with
    uv/pyenv shims that lack the makedepend's module. Diagnose from the failing
    command line or `CMakeCache.txt`'s `_Python3_EXECUTABLE`. Applies to
    `Python_EXECUTABLE` too.
43. **A checksum-pinned vendored tree is not freely editable** — `sed` the
    file, then rewrite only that file's `.cargo-checksum.json` entry from
    `sha256sum` in the same `prepare()` step; never touch other entries or the
    package checksum, or cargo refuses with
    `the listed checksum … has changed`. Treat build.rs nightly-only cfg behind
    `version_check`/`autocfg` gates as a `rust-git` landmine.
45. **A parallel-make failure naming a static archive is a writer/reader
    overlap** — a phony target that ranlibs an archive its links reach only via
    the `ar` rule races `-j` (`lto1: file too short`). Fix it at a seam that
    survives Makefile regeneration (the phase's `make` invocation), never by
    serializing the build.
46. **`git apply` outside a repo is repository-context sensitive** — on a
    non-repo tree it resolves against the enclosing repo root and silently
    skips out-of-subdir hunks (`Skipped patch` is `--verbose`-only, exit 0).
    Pin `GIT_CONFIG_COUNT=0 GIT_DIR="$PWD/.gsa-nogit" GIT_WORK_TREE="$PWD" git
    apply -p1 …`. Applying inside the recipe's own clone is fine.
47. **Trimming a split package must disable its build** — not just its
    `makedepends` and packaging paths: probes find `PATH` substitutes (a Python
    2 probe matched 3.14; SWIG compiled with empty `PYTHON_INCLUDES` and failed
    on `Python.h`). Use the build system's switch
    (`--without-python --without-python3` → `HAVE_PYTHON`/`HAVE_PYTHON3`); an
    incomplete trim still compiles.
48. **`package()` starts in `$srcdir`, not the source root** — a bare
    `install -Dm644 LICENSE` reads `$srcdir/LICENSE` while the tarball sits in
    `$srcdir/$pkgname-$pkgver/` (or a clone subdir), killing `package()` after
    the compile. Qualify the path or `cd` first. Sweep with
    `grep -rnE '(install|cp) .*(LICENSE|COPYING)' packages/*/*/PKGBUILD`.
49. **A `-git` recipe entering a build-system subproject vendors it like the
    seeded set** — a meson wrap that fetches at build time is the defect. Add
    named `source=()` entries and `prepare()` symlinks
    (`realpath --relative-to`) into `subprojects/`, copy `patch_directory`
    overlay files from `subprojects/packagefiles/`, and add the subproject's
    makedepends.
50. **A compatibility shim replicates upstream's output *shape*** — not just
    per-flag values: `lib/cups-config` echoed `1` for `--image` while
    `cups-config.in` treats it as a no-op, so a combined call captured
    `"1\n-lcups"` and died as make's `missing separator`. Read the real script
    and pin the shape with a mutation-probed fixture (`tests/cups-config-shim.sh`).
51. **Recipe outputs are co-installable by construction** — the builder
    installs all outputs in one `pacman -U`, so mutually exclusive variants
    that ship the same path cannot be split outputs. A variant is a separate
    recipe carrying `provides=(<stock>)` **and** `conflicts=(<stock>)`; that
    `conflicts` is load-bearing, never a trim leftover.
52. **Edge a consumer when a fresh host would not have the member installed** —
    otherwise the sort builds it first and the provider that links is stock.
    Audit `.SRCINFO` with `pacman -T` after any dep change; a cyclic pair is the
    assumed-prerequisites boundary. Each new edge needs a build-order reason —
    never mass-add edges.
53. **Probe an injected compiler wrapper before trusting it** — `BUILDENV=ccache`
    prepends `/usr/lib/ccache/bin`, so a broken ccache (IgnorePkg-pinned,
    hiredis soname skew) shadows `cc` and every compile exits 127, cargo
    included. `gsa-pm`'s `build()` runs `cc --version` and drops the farm from
    `PATH` with a warning. Never symlink a soname gap; repair the host.
54. **An auto-detected, linked library is a `depends` entry** — diff the
    shipped DT_NEEDED closure against the declared one; never trim such a dep.
    Spell a stem `.so` only when the provider's provide is stamped — never
    `X.so.N`, a no-`.so.N` soname, or an owner name. Gate with
    `gsa --qa-check declared-deps` after regenerating `.SRCINFO`; it is
    report-only, so assert the `clean` tail. Engine side: gentoo-style-arch
    AGENTS.md rule 54.
55. **A provider SONAME bump needs its direct NEEDED consumers in the same
    pass** — pacman keeps them installed while they are load-broken (jbigkit
    2.2's `libjbig.so.2.2` against `.2.1` consumers). Detect with
    `ldd | grep 'not found'` after any leaf library update; repair the direct
    consumers first, then their users.
56. **Every non-interactive makepkg chain passes `--noconfirm`** — `-s`
    (syncdeps) otherwise prompts `Proceed with installation? [Y/n]` and aborts
    rc 8 on a missing makedepend. Use `makepkg -sfC --noconfirm` or preinstall
    them; the engine's own spawns already carry the flag.
58. **A living doc teaches how to CHECK** — never the shape of a retired era.
    When a change moves a home or renames a spelling, update the doc; retired
    spellings survive only in the engine contract's migration table. Volatile
    facts are dated or printed (`gsa -Sl`), never asserted in prose.
60. **Build-domain work never writes engine-owned state** — makepkg runs as the
    build user, and the recipe store is `GSA_RECIPES_DIR` > `recipe_dir` >
    `<build-user-home>/.local/share/gsa/recipes`, never `--state-dir`. Never
    write `/var/lib/gsa` from recipe code. Engine side: gentoo-style-arch
    AGENTS.md rule 60 (`ensure_store`, ownership gate).
61. **Smoke tests run the INSTALLED engine** — the battery runs the packaged
    `/usr/bin/gsa`, never a nested crate build; a green battery against a
    private build has already shipped a stale engine once. `gsa-pm` stays git
    self-tracking with no `_commit` pin. Deploy loop: `sudo gsa -Sy` →
    `sudo gsa -S gsa-pm` → validate the installed binary.
63. **A version-sync rewrite is volatile store state** — the store refresh is
    `git fetch origin HEAD` plus `reset --hard`, so it destroys the sync pass's
    UNCOMMITTED `PKGBUILD`/`.SRCINFO` rewrites. Run one sync at a time, copy
    the rewrites into the dev tree and commit them, and verify fetch-only sums
    with an independent download before review. Corollary (superseded rule 38):
    the committed `pkgver`/`pkgrel` are authored, never sync-rewritten — a mass
    revert before a pull resets the marks and forces full redundant rebuilds.
64. **Weekly Monday-boundary snapshot pins for the toolchain family** —
    `llvm-git`, `rust-git`, `mesa-git`, `libclc-git`,
    `spirv-llvm-translator-git`, `gcc-snapshot` and the ABI providers
    `qt6-tools`, `pyside6-git`, `rust-bindgen-git` pin the LAST commit at or
    before Monday 00:00 UTC via `#commit=`/`_commit`, with `pkgver` moved in the
    same change. Never free-track. Advance all pins together on the Monday
    cadence; `gcc-snapshot`'s AUR snapshot-tarball + `version-synced` route
    stays retired. The scope widens to every moving-ref tracker in
    `@core`/`@build-tools` (`docs/snapshot-expansion.md`), and **a pin is the
    only requirement for the snapshot name**: `gsa` accepts `<id>-snapshot` as
    an INPUT alias for a recipe whose primary source carries `#commit=`, while
    the recipe keeps its `-git` id, `pkgname`s and `provides=` — never rename a
    recipe to `-snapshot` to make the alias work, and never add topology
    vocabulary for it.
65. **A parallel writer turns measurement into noise** — when two identical
    runs disagree, suspect the inputs: `sha256sum` plus
    `ls --time-style=full-iso` before theorizing, and record content hashes in
    every tree reconciliation. Exactly one writer per mutable tree; a pause
    means zero writes; a concurrent job's notes are self-reports.
70. **A recipe FLAG edit needs a clean build tree** — meson `setup` no-ops over
    a configured directory and make does not track `CFLAGS`, so a warm tree
    yields a MIXED-flag build. Wipe meson's configured `build/` and force the
    rebuild even when a later run reports Succeeded.
75. **`SRCDEST` has exactly one authority** *(renumbered from the second 64;
    owner moved 2026-11-10)* — the engine's `srcdest` key in
    `/etc/gsa/gsa.conf` (default `~/.gsa-src`). The environment rung and both
    `makepkg.conf` rungs are retired with the config rework, so neither
    `~/.makepkg.conf` nor an exported `SRCDEST` decides anything. Never export
    it in a shell: `sudo` carries the export into the build and the cache
    bounces. Probe with `env | grep SRCDEST` (empty) and one store; a stale
    shell uses `env -u SRCDEST`. Engine side: gentoo-style-arch AGENTS.md
    rule 73 owns the resolution ladder, contract §B.11 the key.

## 4 · Optimization playbook


- **mold linker**: `-fuse-ld=mold` ships in BOTH engine LDFLAGS bodies
  (2026-11-10), so a normal autotools/cmake/meson build needs nothing in the
  recipe; keep an explicit `-fuse-ld=mold` only where the build ignores
  `LDFLAGS` (QMAKE_LFLAGS, meson linker args) or where a PGO phase re-assigns
  LDFLAGS from `${_ldflags_orig} ${_mold}`. mold-git carries the versioned
  provide `mold=${pkgver}`
  (`provides=("$_reponame=$pkgver")` in `packages/core/mold-git/PKGBUILD`), so
  a `mold` makedepends resolves to it; the runtime `command -v mold` guard
  idiom is retired (optional belt). (last reviewed 2026-11-10)
- **The engine ships the optimization flags** (2026-11-10 rework): the compiler
  line is `-march=native -mtune=native -O3` plus the per-family passes, in
  `/etc/gsa/{gcc,clang}-makepkg.conf`, and every lane gets it as a generated
  `makepkg --config` composite. `makepkg.conf` (host or user) is NEVER sourced
  — do not write a recipe that assumes one, and do not append a baseline flag.
  Meson packages still use `arch-meson` (buildtype=release — upstream
  `if buildtype=='release'` blocks DO apply); the known raw-`meson setup`
  deviations (dbus-broker-git, flatpak-git, mesa-git, pixman-git with
  `--buildtype=plain`, zbar) are tracked exceptions, converted to
  `arch-meson` only with build evidence, dated. Rust: `RUSTFLAGS` ships
  UNIVERSAL (`-C opt-level=3 -C target-cpu=native`) and the composite exports
  it, so a recipe appends `-C target-cpu=native` only if it replaces
  `RUSTFLAGS` outright (PGO phases). ISA tuning is the engine's or explicitly
  configured. (last reviewed 2026-11-10)
- **Per-family tuning belongs to the engine, never to a recipe append
  (superseded 2026-11-10).** The 2026-11-01 "universal host config" gate
  rejected `-fstack-reuse=all`, `-fivopts`, `-fipa-pta` and
  `-fmerge-all-constants` from the ONE universal config (clang rejects three of
  them) and restored the GCC-only passes per recipe as the `# flag-audit
  2026-11-01` appends. Two shipped configs exist now, so the workaround is
  retired with its cause: `-fipa-pta` and `-fprefetch-loop-arrays` live in the
  gcc body, `-fira-hoist-pressure`/`-fstack-reuse=all` are gcc defaults and are
  shipped by neither body, and the 200 append lines across 133 recipes were
  deleted (2026-11-10). A recipe keeps only a delta whose reason is in the
  file, or a substitution when it must drop a shipped flag
  (`CFLAGS=${CFLAGS/-fno-math-errno/}`). Graphite
  (`-fgraphite-identity -floop-nest-to-graphite`) stays deferred (GCC snapshot
  loop-vectorizer miscompile class, JOURNAL 2026-10-21). (last reviewed
  2026-11-10)
- **LTO**: meson-controlled `-Db_lto=true` (mesa +allow-broken-lto,
  libadwaita, util-linux, systemd, dbus-broker, noctalia); PGO phase-1 always
  `-Db_lto=false` → flip true in phase 2 (glib2, gtk3, gtk4, wayland, cairo,
  xwayland, libinput, pixman, noctalia); manual via make/CMake (jemalloc,
  zlib-ng-compat); zstd phase-2 only; `options=(!lto)` where LTO breaks
  (rocm-llvm, hip-runtime, gcc-snapshot, niri-spicy-git, blender-git);
  llvm-git's (and rust-git's) `!lto` is NOT a "LTO breaks" case — it only
  neutralizes makepkg's LTOFLAGS while upstream LTO stays intentional
  (docs/JOURNAL.md 2026-10-18); Zen uses mozconfig thin LTO instead.
- **PGO phase-2 reconfigure**: a phase-2 pass must re-run the *configure* step,
  not only the build — the argument cache survives `make clean`. Meson:
  `meson setup --reconfigure` with both compiler and linker caches replaced
  (rule 6, `docs/build-guide.md`), and phase 1 must start from a purged
  build dir: `meson setup` on a configured dir only prints "Directory already
  configured." and exits 0, so a reused srcdir (a plain `makepkg -f` retry)
  re-compiles with the previous phase-2 options, produces no gcda, and the
  floor guard falls back to a plain build (umbriel-git, 2026-11-06). CMake: `cmake-git` reads
  `CFLAGS`/`CXXFLAGS`/`LDFLAGS` only while initialising `CMakeCache.txt`, so
  phase 2 rewrites the flag strings **inside** that file and touches a tracked
  input (`CMakeLists.txt`) so the generated `Makefile` regenerates — without it
  the link line keeps `-fprofile-generate` and `package()`'s instrumentation
  guard aborts (2026-09-20). Rewrite the cache rather than delete it: it also
  holds the install prefix, `--mandir`/`--docdir`/`--datadir`,
  `CMAKE_USE_SYSTEM_*` and mold's `-fuse-ld=mold`, so a deletion re-prefixes the
  payload to `pkg/usr/local` and swaps system libraries back to bundled ones.
  Never re-run `./bootstrap` either: that is a *build of a compiler*, and its
  objects are compiled from the same sources as phase 1, so `-fprofile-use`
  there hits the phase-1 generate-mode profiles and make dies on
  `-Werror=coverage-mismatch`.
- **PGO training workloads**: mesa (vkcube on lavapipe + glxinfo/eglinfo,
  gcda in srcdir/mesa-pgo-profile, ON by default); glib2/gtk/cairo (`meson
  test`, timeouts + `|| true`); bash/zsh (`make check` timeout 900 + `|| true`
  - binary smoke test); easyeffects (private pipewire+wireplumber in
  dbus-run-session, sandboxed XDG dirs, quits via `easyeffects --quit` —
  never terminate daemon processes by name, PID-scoped cleanup only);
  wayland/libinput/util-linux/systemd OPT-IN via env vars; noctalia (headless
  sway); lz4/zstd CLI (profiles OUTSIDE build dir); mimalloc (test suite +
  `-fprofile-update=atomic`); mold (links itself); rust/niri LLVM-style
  (LLVM_PROFILE_FILE + llvm-profdata, unset sccache). Verify:
  `find <profile-dir> -name '*.gcda'` count > threshold. The threshold is a
  per-recipe `local` — `pgo_min_gcda`, or `pgo_min_profraw` for mold-git's
  Rust `.profraw` profiles (and ripgrep's), or `pgo_min_samples` for the Go
  flavor's pprof sample count; it is NOT a `lib/pgo.sh` knob — and its comment
  contract is "≈ the minimum distinct translation units the training must
  touch before a profile is worth trusting": at or below it the profile is too
  thin and the recipe falls back to a plain (non-PGO) build rather than
  shipping one. Values (as of 2026-09-26; the per-recipe `local` is the
  check, never this list) — `pgo_min_gcda`: 0 (`cmake-git`, `mold-git` —
  any profile data at
  all suffices; zero files means training never ran and phase 2 is skipped),
  50 (`glib2-git`, `cairo-git`, `xorg-xwayland-git`), 100 (`gtk3-git`,
  `gtk4-git`), 15 (`jq`, `file`), 20 (`rsync`); `pgo_min_profraw`: 0
  (`ripgrep`); `pgo_min_samples`: 500 (`fzf`). The fallback is family-shaped —
  LTO-only for the meson/CMake recipes, fat-LTO plain for ripgrep,
  LTO-restored-without-use for the C-autotools trio, `-pgo=off` for fzf — and
  always plain, never half-trained. A threshold change is a behavioural change — it decides whether
  the recipe ships a profile-used build at all — and belongs in a JOURNAL
  entry with the reason; if the thresholds are ever lifted into `lib/pgo.sh`,
  a change there is a behavioural change to every consuming recipe at once.
- **C-autotools PGO family** (jq/file/rsync, 2026-09-28): CFLAGS bake at
  ./configure time — every phase must re-run ./configure; `make clean` is NOT
  enough. Phase 1 strips `-flto*` and instruments with
  `-fprofile-generate=<dir>`; the `=<dir>` spelling must be SYMMETRIC with
  `-fprofile-use=<dir>` on both sides — a bare `-fprofile-generate` plus
  `-fprofile-use=<dir>` silently misses every profile (GCC probe: the counters
  land where the use phase never looks). Training is `make check` plus
  workload loops (filter/sweep/tree-copy; gcda counts 23/25/119). Phase 2
  restores LTO plus `-fprofile-use=<dir> -Wno-error=missing-profile
  -Wno-error=coverage-mismatch`. rsync keeps Fedora's rhbz#1898912 LTO
  history as the escape-hatch comment (LTO+PGO builds fine on GCC 17).
- **Go-PGO flavor** (fzf, 2026-09-28, first Go member): training = upstream
  bench suite + `fzf --profile-cpu` filter runs, merged via
  `go tool pprof -proto` into `$srcdir/cpu.pprof`, wired as
  `GOFLAGS+=-pgo=$srcdir/cpu.pprof`; the floor `pgo_min_samples=500` is
  parsed from `go tool pprof -top` "Total samples" and below it the release
  build sets `-pgo=off`. The recipe keeps the honesty caveat: the profile
  over-represents micro-benchmarks versus interactive TUI use — it represents
  the batch-matching hot path. `lib/pgo.sh` is deliberately unchanged: Go
  leaks none of the `.gcda`/`.profraw` literals its predicates cover, so the
  gate trivially passes; the family still earns `tests/fzf-pgo.sh`.
- **Special cases**: rust-git (bootstrap.toml flags, 5 patches, and
  `options` must keep `!lto`: makepkg's `-flto=auto` makes the C++
  llvm-wrapper GCC-LTO, which lld — rustc's `gnu-lld-cc` default linker —
  cannot link; see §5. Also: `build()` must invoke
  `x.py install rust-src` explicitly — upstream abcb9780d6d4 renamed the
  step `src`→`rust-src` and its default run needs `[build] extended`,
  which we never set; also `build()` must wipe dest-rust/dest-src first —
  a failed run's half-mutated DESTDIR makes the next install.sh die on a
  dangling-symlink `cp`; see §5); Zen browser
  (fortify 3→2, HOST_CFLAGS unset — cc-rs re-export hazard, 3-tier mozconfig
  PGO, explicit `--enable-optimize=-O3` (documented exception, 2026-10-28));
  gcc-snapshot (-O2 stage2–4, format-security stripped); qt5-base-git
  (cflags + nostrip patches — qmake consumes system CFLAGS); libadwaita/
  xdg-portal-gnome `--wrap-mode=default`; dbus-broker units patch; glib2
  schema/terminals patches; `options=(staticlibs)` on lz4/pixman/mimalloc/
  libunwind. Deliberate no-ops: libreoffice-fresh (already `!lto` +
  `--enable-lto` + fortify 3→2 + -g1); blender-git (mold + ccache + !lto).
- **Electron/JavaScript packages** (vscodium-insiders-git, logseq-desktop-git,
  vencord-git):
  nothing is compiler-built except the native Node addons, so the recipes are
  `!strip !debug !lto` and apply only ccache + the mold probe to those addons.
  vencord-git carries an extra operational contract: the `/usr/lib/vencord`
  payload is **inert until injected**, so the recipe also ships
  `discord-vencord` (re-asserts the patch on every launch — the only thing
  that survives Discord self-updates), `vencord-inject` (official-compatible
  asar shim; the official installer cannot be repointed at a pacman payload)
  and a libalpm hook re-wrapping the stock `discord.desktop` — and its
  scriptlets define `post_upgrade` because pacman has **no fallback** to
  `post_install` on upgrades.
  logseq-desktop-git additionally bundles `master` (2.x) which embeds an
  OCaml/Melange CLI runtime — the opam switch lives under `$srcdir` and pins
  OCaml 5.1.1 to match upstream CI.
  Its `cli/` and `static/` installs MUST pass `--ignore-workspace`: the tree's
  root `pnpm-workspace.yaml` has no `packages:` field, so a bare `pnpm install`
  from a subdirectory resolves the ROOT project, exits 0 and creates no
  `node_modules` — `static/` then failed with
  `Command "electron-builder" not found` (2026-09-18, JOURNAL). Related: with
  the flag, pnpm also skips the allowlisted dependency build scripts and
  `shamefully-hoist`, which is harmless here only because electron-builder
  fetches the Electron distribution itself and the static `postinstall`
  rebuilds `keytar`.
  Its opam switch is created only when absent: `build()` restarts from the top
  while `$srcdir` persists, and `opam switch create` exits 2 on an installed
  switch, which errexit turns into an abort before the first bundle (same date,
  JOURNAL).
- **TeX Live data packages** (texlive-texmf): `arch=(any)`, so there is no
  compiler and no ISA/LTO/PGO phase at all. The recipe keeps upstream's
  `!strip`, which also skips the strip/debug tidy pass, and optimises by scope
  only (whole splits dropped with their depends/provides/paths). It is the only
  recipe using SVN sources; the prune-strength-3 surface (`gsa -Mccc`,
  `crates/gsa-maint/src/prune.rs`) must keep treating `svn://`/`svn+` like
  `git+` and removing downloaded `*.whl` files (the retired fish
  `nuclear_cleanup` did; the extension set is pinned by
  `tests/cleanup-extensions.sh`).

## 5 · Pitfalls

One line per MECHANISM: the claim, then the tell or the fix. Dates, measurements
and incident narratives belong in `docs/JOURNAL.md`; an entry that only restates
a numbered rule belongs there instead. The engine-side half of a mechanism lives
in the engine repository's `AGENTS.md`.

### Recipe files, patches and sources

- **A tracked comment is public surface**: a claim grounded in this machine is
  not a recipe fact.
- **Everything derived from the recipe must be REGENERATED, in order**: a
  version bump owes `.SRCINFO` (`tests/srcinfo-freshness.sh` is the gate),
  `provides=` must sit AFTER `pkgver=` (`"name=${pkgver}"` above it expands
  empty and makepkg rejects the parse, rc 12), and `--printsrcinfo` resolves
  only top-level vars — a computed `provides+=` inside `package()` extracts
  empty or `.so`, so soname lists stay STATIC. A version-sync `pkgrel` row is
  adopted into the recipe on review: the writing is engine-side.
- **A `b2sums` literal serves one knob combination and makepkg's error names
  nothing**: add a parse-time guard naming both counts and the knob values,
  exempt `GENINTEG=1` so `updpkgsums` can run, never append per knob. Digests
  have lengths (sha256=64, sha512=128); `makepkg --verifysource` is the cheap
  red/green, and a reused autotools tree lies through its stamps.
- **A patch is only as pinnable as its source, and three shapes are traps**: a
  pinned GitHub `.patch` re-renders its preamble (vendor the verified body and
  anchor its hash), an all-zero `index` old SHA reads as a new-file diff (drop
  the line or use real hashes), and `git apply -3 --check` exits 0 even on a
  conflict (validate by CONTENT on a fresh clone).
- **Patches and sums are version-scoped, in more places than one**: a
  version-sync bump of a tag-pinned recipe invalidates every version-pinned
  patch and checksum (re-validate, adopt the tag's sum); the kernel patch set is
  `${_major}`-scoped and `updpkgsums` prefers a cached local copy because
  `startdir` IS `SRCDEST`; and `scripts/config` writes are not evidence —
  `!SYM` ≠ `SYM=n`, so assert a post-`make prepare` `.config` per knob.
- **A bridge patch on a floating-HEAD recipe needs its drop condition in the
  header and a `prepare()` assertion**: when upstream lands the fix,
  `git log -S <API symbol>` and delete the patch — never re-roll it.
- **An upgrade that moves version-spelled sums re-pins them against the
  publisher's own digest**: anchor server-side asset digests, and check a
  benchmark swap's root-path requirement (a deletion-only patch cannot carry a
  relative entry).
- **Implicit install sets drift**: `_pick` lists pin upstream paths, so
  enumerate the whole shipped tree against them (`var/run` belongs to
  `filesystem`), and invoke a component's install step explicitly — an upstream
  rename (`x.py` `src` → `rust-src`) breaks the implicit set and the checksum.
- **A `source=()` scanner must accept every spelling**: `url`, `git+url`,
  `name::git+url` and bare `git://…`, with fragments stripped.
- **`SIGNATURE NOT FOUND` on a `?signed` git source is usually the environment**
  (engine rule 2): the recipe rule is never to touch `?signed`/`validpgpkeys` on
  that message.
- **An expired maintainer key whose signature predates the expiry verifies,
  with a warning**: keep `#signed`/`validpgpkeys`, never `--skippgpcheck`;
  record the expiry and the re-key contingency.
- **A `pkgver()` that parses upstream build metadata is a silent-drift hazard**
  (empty version, zero errors): prefer an upstream version FILE and check a
  rebuilt archive's name. Qt is the exception with a rule — grep
  `QT_REPO_MODULE_VERSION` from `.cmake.conf`, since git describe is unusable on
  its dev branches.

### Swap providers, provides and sonames

- **A Stock→house swap must reproduce the whole stock surface**: every stock
  pkg-config NAME (`pkg-config --exists`; a `Require`d pc file is ABI-adjacent),
  a versioned provide for EVERY stock output (a missing one is a pacman file
  conflict), and the API generation its consumers probe — a versioned provide
  hides a generation mismatch, so retarget to the maintenance line they use.
- **Soname provides are bare names and must match the measured soname**: declare
  `libfoo.so` and let makepkg auto-version it from the packaged ELF soname
  (verify in `.PKGINFO`); a depend name like `libxerces-c.so` matches nothing
  when the measured soname is `libxerces-c-3.3.so` — check every name with
  `pacman -T`.
- **`provides` is hand-maintained and drifts when a dependency newly enables a
  module**: run `tools/provides-audit.sh` on built archives; the fix is a
  provides entry plus a `pkgrel` bump (a same-version skip keeps old metadata).
- **A `stock+.1` pkgrel delta collides with a broken vendor stamp**: the delta
  must strictly beat `pacman -Qi`, not merely differ.
- **Python-embedding recipes must pin the system interpreter**: `FindPython`/
  `FindPython3` follow `PATH` into uv/pyenv/user-local shims — set
  `-DPython_EXECUTABLE=/usr/bin/python` (and `Python3_EXECUTABLE`), and watch
  snapshot-version sentinels and flattened SWIG genexes.
- **Trimming one package's copy of a dual-owned file deletes it for every
  owner** (ghostty's terminfo is also `ncurses-git`'s): expect the loss and
  schedule the surviving owner's reinstall.
- **Never pin a tcl-versioned install path in `package()`**: tcl 9's
  `TCL_LIBRARY` is `zipfs:/…` — derive from `tclConfig.sh`/`TCL_PACKAGE_PATH` or
  match a `tcl*/` glob.
- **A packaging loop's branches must each create their own destination**:
  `install -D` hides a missing parent — `install -d` before `cp -a` in a licence
  loop.
- **`DESTDIR` survives a failed `build()`, and the next install will not forgive
  it**: wipe `dest-*` at the top of `build()`; dangling symlinks break `cp` and
  leak `.old` backups.

### Build systems and toolchains

- **House toolchains move under the consumer's detection logic**: a `-git`
  toolchain that grows or drops target names breaks it (house LLVM builds
  `X86;AMDGPU;BPF`, no NVPTX — read a foreign-target flag's expansion and drop
  it with its dead makedep), and an API rename with a stale version number
  breaks every version-gated shim. Probe the installed headers and red/green one
  object before writing a consumer patch.
- **LLVM coupling has two failure modes**: TARGET-SET skew bricks rustc (diff
  `readelf -W --dyn-syms` sets); VERSION-NODE skew needs every `libLLVM`
  consumer rebuilt per major.
- **lld runs no GCC LTO plugin, and makepkg's LTO-strip hook hollows slim-LTO
  static archives**: a recipe linking C/C++ through rustc/`ld.lld` carries
  `!lto`, and static archives force `-ffat-lto-objects` — verify with
  `ar p … && gcc-nm <real file>` (stdin silently returns nothing).
- **Mold cannot build glibc and false-negatives
  `has_link_argument(-Wl,--version-script=…)`**: append `-fuse-ld=bfd` last in
  glibc's `build()`; fix a version-script probe with `LDFLAGS+=-fuse-ld=mold
  -Wl,--undefined-version` and re-verify `readelf -V | grep -c VER_` after any
  linker flip.
- **Meson options are typed and `auto` is not neutral**: `--auto-features
  enabled` makes a missing auto fatal, `Unknown option` means upstream renamed
  it, `b_pgo` has no `none` (use `-Db_pgo=off`), and a `feature` is not a
  `string`. Spell every optional component `--enable-`/`--disable-`: ambient
  probes make package content a function of installed state, and a doc tool that
  is default-on runs whenever it is installed.
- **A dead `makedepends` is not harmless, and a docs-only removal has blast
  radius**: `autogen.sh`, `.require(tool.found())` chains and hard `install`s
  abort, and makepkg silently reinstalls a residual makedep — trim the makedep
  and the dead path together.
- **A `USE_SYSTEM_<X>=ON` flag is a dependency declaration**: audit it against
  `makedepends`, never against `depends`.
- **A bare `cmake --build build` ignores `GSA_BUILD_JOBS`**: ninja then runs
  `ncpu+2` — pass `--parallel "${GSA_BUILD_JOBS:-$(nproc)}"`
  (`CMAKE_BUILD_PARALLEL_LEVEL=N` is the no-code cap).
- **A compat shim is only as good as the macro's promise**: a shim answering a
  retired API turns an optional probe into a false positive and an API rename
  with a stale version breaks every gate. Gate on a version comparison plus
  `dep.found()`, scan compat blocks rather than call sites.
- **cups 2.5 moved headers to `/usr/include/libcups2`**: feed flags through the
  variable the build reads (`CFLAGS`/`CXXFLAGS` for qmake, `CPPFLAGS` for
  autoconf), export `CPPFLAGS+=" $(pkg-config --cflags cups)"` when upstream
  also deleted its legacy `#define`s, and declare `libcups` when linking.
- **ICU 76+ headers need C++17, and `set(CMAKE_CXX_STANDARD 14)` cannot be
  overridden**: raise the standard at the declaration site in `prepare()`;
  red/green with `g++ -std=c++14` versus `-std=c++17`.
- **`openexr` ≥ 3.5 resolves zstd via `find_dependency(zstd CONFIG)`**: keep
  `zstd-git`'s hand-written `/usr/lib/cmake/zstd/` config.
- **Toolchain drift moves libtool's uninstalled-convenience layout** (`_libs`
  versus `.libs`): `ln -s .libs <lib>/_libs` per bundled subdir; a link error
  surviving that is stale-tree residue.
- **A downstream version floor rejects git-snapshot version strings**: patch the
  probe to a measured-correct parse and verify the arithmetic with `cmake -P`
  before a two-hour build.
- **A nested aggregate's NSDMIs are unavailable in a default argument inside the
  enclosing class**: experimental toolchains prove nothing — use an inline
  overload whose BODY constructs the default, validated with mingw g++.
- **A snapshot compiler is allowed to be the wall**: reproduce the ICE with a
  standalone probe and fix the compiler recipe, not the consumer. A tolerant
  word scan miscompiled into aligned `vmovdqa64` loads is a per-recipe
  `-fno-tree-vectorize` (`-mno-avx512*` is NOT a fix).
- **A compiler or flag change needs a clean build tree**: meson `setup` no-ops
  on a warm dir and make ignores `CFLAGS` — wipe and force the rebuild
  (rule 70).
- **`glog`/`gflags` double registration**: a system static init plus a vendored
  copy define the same flags — find the puller with `readelf -d`/`ldd` and
  prefer `WITH_SYSTEM_*`.
- **Bundled-Chromium code against system libs breaks two ways**: gn `.rsp` files
  embed the build path (keep a short `_build_dir`), and the fix belongs in the
  consumer, never in the `abi=must` provider.
- **`cargo test` integration suites mis-resolve binaries on the rust-git
  toolchain**: irrelevant to packaging (`BUILDENV=(!check)`) — never chase a
  scratch failure as a recipe bug.
- **A GHC package-set way flip fails vanilla compiles with a misleading "files
  missing in 'base'"**: compile the way base was built (`cabal.project` stanza,
  a `ghc` shim for a custom Setup, no mold for prebuilt haskell `.so`) and check
  a `source` constraint is not satisfied vacuously.
- **A `checkdepends`-only dep that upstream CONFIGURES against walls `build()`**,
  while a suite that only *runs* the tool is upstream brittleness to keep with a
  documented skew — never delete tests to make `check()` green.

### PGO, sandboxing and packaging traps

- **PGO is two commitments**: `verify_no_profile_instrumentation "$pkgdir"` is
  the LAST statement of every `package*` function (fatal by design — never
  soften it with `|| return 1`), and a fallback must `rm -rf build` and rebuild
  clean with the trainer linking the library it trains
  (`-L "$srcdir/build/lib"`). Bump `pkgrel` AFTER the first post-sync build and
  regenerate `.SRCINFO` last.
- **A sandbox path has a length budget**: the 108-byte `sun_path` needs sockets
  in a short `mktemp -d`; tear the training tree down as a group and unset
  `WAYLAND_DISPLAY`.
- **Never run concurrent inkscape/ImageMagick SVG conversions**: GApplication
  single-instance registration races under `make -j` — serialize with
  `make -C doc -j1` or drop the delegate.
- **A `[[ -f ]] && cmd` guard as a function's LAST command fails the function
  when the file is absent**: guards at a function tail use `if … fi`.
- **`$srcdir` persists, and patch-CREATED files survive re-extraction**: recipe
  state creation must be idempotent (`rm -rf` before recreating staging dirs)
  and a file-creating patch requires `prepare()` to wipe the source root,
  re-extract, then patch — validate against a POLLUTED work dir.
- **A `clone -s` worktree dies when its shared `SRCDEST` mirror is rebuilt under
  it** (no recipe lever: `rm -rf src/<repo>` or `--cleanbuild`, detect via
  `git show-ref`), and **a VCS-source husk left by a failed fetch is
  self-perpetuating**: `prepare()` must detect the husk, wipe `$srcdir`,
  `$SRCDEST` and the legacy path, then re-fetch the pinned revision.
- **The four makepkg packaging traps**: a stale `$srcdir/<dir>` with a parent
  mirror `.git`, split staging under `$srcdir`, `_pick` dirs AND globs, and
  package()-scoped provides overriding globals.
- **A mandatory validation fetch inside a cached build needs a bounded
  step-level retry** (a generated retry shim for transient signatures only) —
  and a new instance earns its own fixture rather than inheriting a dead pin.
- **`pod2man` and `prove` live in `/usr/bin/core_perl`, absent from makepkg's
  `secure_path`**: export `PATH="/usr/bin/core_perl:$PATH"` in the phase that
  runs the Perl rule.
- **A recipe asset satisfying an external tool probe must be wired by the
  recipe**: `install -Dm755` the shim under the probed name, prepend it on
  `PATH` in `build()`, and pin it in `source=()`.
- **A bundled consumer broken by a house `-git` API removal gets a consumer
  patch**: genbuild patches carry per-tarball levels, and `source=`/`sha256sums=`
  align by position.
- **Topology edges must cover consumed TOOL providers, and a recipe invoking
  cargo/rustc declares `rust-git`**: the `edges` field is `config/topology.conf`
  data, and a preflight cannot substitute for it.

### Host safety and forensics

- **A recipe whose build hard-freezes the host is retired**: three deterministic
  freezes = quarantine — delete the recipe and its record, and require a bounded
  rehearsal (`--jobs 2`, single lane) plus kernel forensics to re-add.
- **Freeze forensics use pstore, not the journal**: `_capture_chain=yes` and
  config-only `WQ_WATCHDOG`/`PSTORE_CONSOLE`, re-armed under a backup dir.
- **An unclean shutdown zeroes freshly written files**: XFS log recovery
  preserves size and mtime, so the red signal is `go mod verify` and the repair
  `go clean -modcache`.
- **A systemd bump that drops a hook input is guarded in the mkinitcpio
  recipe**, never by re-enabling systemd's bootloader integration or deleting
  host files.
- **`target not found` means the name left the repos**: solve the feature the
  way current packaging does — remove output, optprovides, `package_*` and
  makedeps together, and disable the dead build path explicitly.
- **A "silent exit N" from a build tool means its reporter swallowed the failure
  text** (`ENOSPC` filtered out by an `/error \w+:/` pattern) — wrap the binary
  with a tee and read the raw capture.


## 6 · Queued

- **Snapshot-pin waves (QUEUED for the owner's weekend full rebuild,
  2026-11-09).** W1 — the 64 fan-out ≤ 4 trackers — is PINNED: every primary
  `source=()` carries `#commit=` at the last commit at or before Monday
  2026-11-09 00:00Z, 12 branch-pinned recipes also record `_snapshot_ref`, and
  `.SRCINFO` is regenerated for all 64 (the engine's `srcinfo-freshness`
  fixture is clean over the whole tree). **Nothing is built or installed** — the
  owner deferred every real build ("do not do real build test"), so any archive
  from the discarded validation pass is stale. The weekend pass: build + install
  W1, then pin W2 (59 mid-fan-out), W3 (5 build tools), W4 (8 incl. `git-git`
  and the `icu-git` ABI nucleus) and verify each wave. Engine half W0 (the
  `<id>-snapshot` frontend alias) landed 2026-11-09; the `-Sy` pin-advance
  provider is the engine repository's last step. Procedure, the two environment
  blocks (`libidn2-git` gnulib URL, `libmypaint-git` `gegl.pc`) and the
  wave-free build recipe: `docs/snapshot-expansion.md` §8.
- **Flag-revision validation rebuild** (2026-11-03): edit-only T1→T2→T3 flag appends over 133 recipes still need a validating rebuild; blocked on the owner's ~2-week campaign. Separate decision: `libldacdec`'s own `-O3 -march=native`.
- **Topology missing-prereq edges, systemic** (2026-11-01): `config/topology.conf` only; 1825 gap pairs, representative rows named. Each edge needs a build-order reason — never mass-add — so this advances one verified edge at a time.
- **Edge verification debt** (2026-11-01): three rows (fluidsynth-git→libsndfile-git/readline-git, gdb→zlib-ng-compat-git) lack metadata justification; verify in a build or drop them.
- **Versioned-provides epoch under-claim** (2026-11-01): 15+ epoch recipes spell `provides` without `${epoch}`; normalize like gcc-snapshot — needs real rebuilds, not an edit.
- **Warm-`$srcdir` `prepare()` idempotence sweep** (2026-11-01): remaining tarball-source recipes need unguarded `ln`/`cp`/`patch` guards (python and libxml2-legacy are done).
- **Queued pin-fix candidates** (2026-10-28): four `validpgpkeys` rows (nautilus, gobject-introspection, bind, fish); blocked on confirming the publisher's material.
- **sqlite doc-zip checksum mismatch** (2026-10-18): blocks only the 3.54.0 move — at that bump, drop the dead `sqlite-doc-*` source or verify the artifact; never blind re-anchor.
- **ROCm is half-removed**: `hsa-rocr`/`rocm-llvm`/`comgr` reinstalled while `hip-runtime` is absent — rebuild HIP in the same `-S @core` pass, or prune the dirs and the group membership.
- **dbus-broker redundancy**: `stable/dbus-broker` and `git/dbus-broker-git` build the same packages — pick one (a topology/group call).
- **doxygen-git purge**: user decision — no consumer left and `xapian-core` is already gone.
- **gtk4-git demo trim**: `_package_gtk4-demos` plus `_pick demo` still ship four demo binaries.
- **libadwaita-git**: keep the optional `check()` with `checkdepends=(weston)`, or drop both.
- **linux-firmware**: the 2026-09-04 deferred `rm` line's intent is unrecoverable — re-specify it or declare it redundant.
- **Build freezes: CVE-2026-90432** (2026-09-19): the kernel recipe moved to the CachyOS RC channel; "identified", not proven. Live state is `uname -r`/`/usr/lib/modules`, never a doc.
- **linux-cachyos AutoFDO + Propeller at the next rebuild** (2026-09-19): owner decision — ship `afdo.prof` and propeller profiles, or accept a plain kernel (a real optimisation loss that warns nowhere).
- **systemd is a separately coupled effort**: any `systemd` recipe change drags a coupled rebuild pass, so schedule it as its own pass.
- **Stretch backlog: ghostscript / tesseract**: leaf-utility recipes claimed only to keep the print/OCR gap visible — drop them if the gap stops mattering.
- **`keys/*.asc` gitignore gap** (2026-10-04): offline-verification key material — track it (add the negation) or keep it ignored with keys sourced elsewhere.
- **gst-libav `gst-ffmpeg=$pkgver` deviation** (2026-10-04): confirm the merged recipe's stock-name mapping against stock, or align it.
- **gnulib unpinned HEAD** (2026-10-04): the 7-recipe `SHARED-SRCDEST` cluster links a moving HEAD — pin a commit or keep the reproducibility caveat deliberately.
- **spandsp sign-off** (2026-10-03→04): it resolves to the FreeSWITCH fork; an explicit owner sign-off is wanted before it becomes the house provider.
- **Residual ingestion debts** (2026-10-04): two stale `.SRCINFO`s (hermes-agent-git, zen-browser-pgo) await their owner — no self-reported validation.
- **LLVM-ABI consumers outside the coupled-batch tags** (2026-10-31): `postgresql-libs` and `linux-tools` carry no `abi=` tag — add `abi=should` plus edges, or document why they are safe.
- **libdisplay-info-git parked at 0.3.0** (2026-10-07): owner decision — heal-set with wlroots 0.20 (accepting repeated re-walls) or keep the park.
- **libpng-git parked on `#branch=libpng16`** (2026-10-07): so.18 is a coordinated `pacman -U` batch across every `libpng16.so` pinner; schedule it with the owner.
- **libseccomp-git parked on `#branch=release-2.6`** (2026-10-07): master is a placeholder 0:0:0 build — revisit only when upstream stamps master or a 3.x ABI lands.
- **libgit2-git parked at `#tag=v1.9.7`** (2026-10-08): `main` declares 1.9.0 and cannot satisfy `-sys` pkg-config floors; unpin when both bounds clear.
- **llvm-git ↔ rust-git coupled-batch procedure** (2026-10-07): manual today — sweep exact pinners, stage `llvm-git`, build `rust-git` while the old rustc runs, then one `pacman -U`; a later candidate for engine automation.

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
6. `rm` is a trash wrapper in the fish login shell: it moves targets to
   `~/.local/share/Trash` and ignores `-r`/`-R`. Tool-call shells are bash, so
   hand any command you give the user to `bash -c '...'`.
7. Prefix makepkg and bare-repo git work with `GIT_CONFIG_COUNT=0`; without it
   the agent shell's injected `safe.bareRepository=explicit` breaks tag
   verification and LFS fetches.
8. Never run two heavy builds at once, and check for in-flight `makepkg`
   before rebuilding (rule 7).
