# Copilot instructions — Gentoo_Style_Arch (recipe repository)

A curated Arch Linux package set for **AMD laptops** (AMD CPU, amdgpu/radeon),
plus the declarative topology that orders it. `gsa` resolves the build order
from `config/topology.conf`, builds each package and installs it before its
consumers compile, and accounts for the whole run as one machine-readable
record. Everything is tuned to the building machine; the output is not a
redistributable binary.

**This repository is the data, not the engine.** `gsa` itself — `crates/`, the
`format: 2` run record, the contract — lives in
[`ZhangDM-520/gentoo-style-arch`](https://github.com/ZhangDM-520/gentoo-style-arch)
and is consumed here as the installed `/usr/bin/gsa`. Never vendor, patch or
rebuild the engine here; engine defects and engine rules belong there.
`packages/core/gsa-pm` is the one recipe that builds it, git self-tracking with
no `_commit` pin, so a broken engine is always recoverable with plain `makepkg`.

`AGENTS.md` at the repo root is this repository's memory — stack shape, edges,
landmines, rules, pitfalls, queue, shell hazards. Read it first, then the tail
of `docs/JOURNAL.md` and `.logs/scratchpad.md` for what just changed and what
is in flight. Rules and pitfalls are not restated here; a rule copied into a
second file drifts in one of them.

## Commands

All of these are `bash`; the checkout is the working directory.

### Inspect (read-only, unprivileged — safe to run anywhere)

```sh
gsa --help                    # authoritative command roster; everything else is deferred
gsa -Qg                       # group roster with member counts
gsa -Qt                       # resolved topology records: id|path|groups|edges|tags
gsa -Qi <ref>                 # merged info: pacman fields, side-car, recipe metadata, topology record
gsa -Sl @git                  # ordered listing (re-validates map, graph, sort)
gsa -Qa <ref>                 # ABI token and recorded subscriptions
gsa -Qr                       # revdep report: unresolved DT_NEEDED, exact-pin leftovers
gsa -Qp <archive>             # probe an archive: .PKGINFO vs its index row, hash/size
gsa -Qu                       # stale set: tracked version moved past the newest built instance
gsa -Qb [ref…]                # retained built archives: the side-car's hash-bound index rows
gsa -Sw @core                 # fetch + verify sources (makepkg --verifysource); builds nothing
gsa -Ma                       # audit lints: report-only, ALWAYS exits 0 — read it
```

`gsa -Qi` and `gsa -Qt` are the fastest way to learn what a recipe is wired to
without opening three files. `gsa -Sw` is the cheap source/signature check:
prefer it over a rebuild when only `source=()`/`b2sums=()` moved.

### Validate a recipe change

```sh
bash -n packages/<cat>/<pkg>/PKGBUILD    # recipe parse
GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<pkg> \
  > packages/<cat>/<pkg>/.SRCINFO        # regenerate the COMMITTED .SRCINFO
gsa -Ma                                  # read the report, not the exit status
gsa -Sl                                  # listing re-validates map, graph and sort
gsa -S --dry-run @git                    # repeat for @stable, @core
bash tests/run-all.sh                    # whole battery
```

The `.SRCINFO` step is not optional and not a formality: the engine and the
fixtures read the committed metadata, so a fresh `PKGBUILD` with a stale
`.SRCINFO` is a real defect. The fixtures that own a recipe regenerate it and
`diff` the result against the committed file (see the tail of
`tests/onlyoffice-recipe.sh`), so a stale one fails the battery rather than
passing review. `GIT_CONFIG_COUNT=0` is required in agent shells — see the
shell boundary note below.

Run the **whole** battery, not only the fixture whose name matches the recipe
you touched: a map-format change was once caught by two unrelated recipe
fixtures. Never use a real rebuild as a syntax check.

### Tests

```sh
bash tests/run-all.sh                    # whole battery, parallel by default
bash tests/run-all.sh recipe             # substring filter (a typo exits 2)
bash tests/run-all.sh --serial           # one at a time, for a flaky fixture
bash tests/run-all.sh -j 4               # cap concurrency
RUN_ALL_JOBS=2 bash tests/run-all.sh     # same cap, env spelling
bash tests/<name>.sh                     # one fixture, standalone
GSA_TEST_GSA_BIN=$PWD/../gentoo-style-arch/target/release/gsa bash tests/run-all.sh
```

The battery validates this repository **through the installed engine**, which
is the contract's rule: it prints the binary and its owning package, and a
`GSA_TEST_GSA_BIN` run is a pre-install deviation to be reported as such. A
stale `/usr/bin/gsa` makes the battery test old code:

```sh
pacman -Qo "$(command -v gsa)"    # which package owns the binary under test
pacman -Q gsa-pm                  # its version
```

If the engine itself is stale, refresh it before trusting a green run:

```sh
sudo gsa -Sy && sudo gsa -S gsa-pm
```

There is no CI workflow in this repository — `bash tests/run-all.sh` plus the
validation block above are the gate, run locally.

### Build / install

```sh
gsa -S --dry-run @git            # plan + decision rows, no mutation
gsa -B --leaf glib2-git          # build ONE recipe to archives; installs nothing
gsa -S glib2-git                 # build + install it AND its consumer closure
gsa -S @core                     # ABI-coupled core update
sudo gsa -S @git                 # write-side verbs need root; makepkg still runs as you
gsa -Sy                          # version sync only — leaves rewrites UNCOMMITTED
```

On a machine with no `gsa` yet, or to recover a broken engine, `gsa-pm` is an
ordinary bootstrap recipe that must build with plain `makepkg`:

```sh
GIT_CONFIG_COUNT=0 makepkg -f --dir packages/core/gsa-pm
sudo pacman -U packages/core/gsa-pm/gsa-pm-*.pkg.tar.zst
```

Never use a real rebuild as a syntax check, and never run two heavy builds at
once (check for in-flight `makepkg` first; the failure mode is an OOM, not a
queue). Build in the runtime clone or the store, never in this checkout.

## Selection semantics (the part that bites)

- **A selection expands to its transitive consumers.** `gsa -S mesa-git` also
  rebuilds everything that must build after mesa-git. Rebuilding exactly what
  you named requires `--leaf`.
- **Selectors**: recipe id, recipe path, case-variant id (matched and
  announced), pacman pkgname (split outputs included), a `@group` / `@user-set`,
  a `22..38` index range over `-Sl`, or a standalone `PKGBUILD`/directory/URL.
- **Exact lookup only** — a typo is never auto-corrected; it exits 2 with
  nearest candidates.
- `<id>-snapshot` is an **input alias** accepted for a recipe whose primary
  source carries `#commit=`. The recipe keeps its `-git` id, `pkgname`s and
  `provides=`; a floating recipe is refused.
- `--skip` (verified-fresh claim) and `--skip-built` (any complete built set)
  are different claims and cannot combine.

Exit codes are the assertion surface (`CONTRIBUTING.md` says assert decision
rows, never rendered prose):

| code | meaning |
| --- | --- |
| 0 | success |
| 1 | build failure under `--fail-fast` |
| 2 | usage error (bad flag, unknown reference, invalid range, malformed config record, deferred spelling) |
| 3 | refusal — the run refused to start or aborted at a fail-closed gate |
| 4 | cone-stop run with >=1 failure (the parked cone is in the run record) |
| 5 | deferral-only (>=1 deferred/parked row, no failure) |
| 130 | interrupted — the full run record is emitted first |

Install behaviour has a dedicated entry point: `gsa --install-decide
<checked|force> <archive…>` prints the install rows
(`install`/`skip`/`refuse`/`noop`/`parked`) and exits 0 plan / 1 refusal / 2
bad usage.

## Structure and mental model

- `packages/<category>/<id>/` — `PKGBUILD` is the source of truth with the
  generated `.SRCINFO` committed beside it, plus local patches, hooks, install
  files, desktop assets and upstream licence material. A generated `PKGBUILD`
  commits its generator pair (`PKGBUILD.in` + `update.PKGBUILD`, kept in
  lockstep: every manual edit is mirrored into the template). Physical
  categories (`git`, `stable`, `core`, `misc`, and the parked `deprecated`
  tier) are a filing system, **not** the build order. `misc` is currently an
  empty roster slot (`packages/misc/` is where a standalone-staged recipe
  goes), and a `packages/deprecated/` recipe has its topology record commented
  out, so it appears in no build list.
- `config/` — exactly three files. Anything else under `config/` is
  unreachable state and fails a fixture.
  - `topology.conf` — one record per package, `id|path|groups|edges[|tags]`,
    and the only place that binds an id to a recipe path. `id` is unique
    `[A-Za-z0-9._+-]+`; `path` is relative, contains no `..`, and must hold a
    `PKGBUILD`; `groups` is a comma list over the roster; `edges` is the
    comma list of packages this one consumes (a record ending in a bare `|` is
    a deliberate **no-edge** record). `tags` carries policy: `abi=must` /
    `abi=should`, `app-cluster=<name>`, `version-sync=nvchecker`,
    `toolchain=gcc|clang`.
  - `build-defaults.conf` — `lanes`, `jobs`, `intensity`, the memory budgets
    (`memory_per_job_gib`, `core_memory_per_job_gib`, `reserved_memory_gib`)
    and `store_format` (bump only with a schema change an older engine cannot
    parse).
  - `abi-exclusions.conf` — `id|reason|review-by` rows; these are **documented**
    Tier-2 exceptions the ABI guard consults, never silent gaps, and a row must
    be reviewed before its `review-by`.
- `lib/` — shared helpers sourced from recipes: `pgo.sh` (the one PGO payload
  gate) and `cups-config`.
- `tools/` — host diagnostics, deliberately outside the battery: `nvcheck.sh`,
  `provides-audit.sh`, `go-modcache-check.sh`.
- `tests/` — the fixture battery; `tests/assets/` is frozen oracle material and
  is never discovered, `tests/lib/` holds `.bash` synthesis helpers.
- `.logs/` — the active working buffer (`scratchpad.md`, a tracked stub) and
  untracked per-action exports.

The mental model: **topology, not directory names** — identity, group
membership and build-order edges are one declarative record, re-validated on
every invocation. **Consumers, not dependencies** — a selection expands to
everything that must rebuild after it, because the ABI risk lives downstream.
Group roster is exactly `git`, `stable`, `core`, `misc`, `app`,
`build-tools`; `build-tools` is the dispatch-first scheduling class and is
dual with `core`.

## Key conventions

- **One topology record per package** (ADR 0002). Adding or relocating a recipe
  means updating `config/topology.conf` in the same change; the loader rejects
  any other record shape, and one malformed record breaks every command. Never
  add a second file that maps ids to paths.
- **`.SRCINFO` is committed metadata.** Regenerate it after every `PKGBUILD`
  edit and commit both; a stale `.SRCINFO` is what the engine and the fixtures
  actually read.
- **A new local asset must survive two ignore layers**: the recipe's own
  default-deny `*` plus `!` negations, and the root `.gitignore`, which denies
  every new subdirectory under a recipe and negates only `LICENSES/`. Verify
  with `git check-ignore -v <asset>` — no output means it is visible. Never let
  a recipe `.gitignore` match itself. A name fetched at build time goes in the
  recipe's `FETCHED-ONLY` file instead of being committed.
- **`b2sums` is a flat list, one entry per source**, so it can serve exactly
  one combination of a recipe's knobs. Keep the source set knob-independent; a
  recipe that cannot must refuse the unservable combinations **and** keep
  `updpkgsums` runnable. Never grow it with per-knob `b2sums+=(…)` appends —
  `updpkgsums` rewrites the whole literal on the first bump and they
  double-count.
- **Provides discipline.** Toolchain `-git` packages carry *versioned*
  provides (`meson=${pkgver}`), because an unversioned provide cannot satisfy a
  `>=N` makedepend and pacman silently falls back to the repo package.
  Library-shipping packages declare *bare* soname provides (`libfoo.so`) that
  makepkg auto-versions from the packaged ELF. Request a capability through its
  virtual (`java-runtime`, `libgl`), never a concrete provider. Provides live in
  `.PKGINFO`, so a provides change needs a real rebuild — `makepkg -Rf` only
  repackages.
- **ABI coupling lives in the record's `tags`** (`abi=must` / `abi=should`);
  the batch itself is derived from the edge graph. LLVM consumers, Rust, Qt
  private-API modules, ROCm and the system replacement packages are not
  independent leaf updates.
- **Version sync is one opt-in tag.** `version-sync=nvchecker` is the only
  switch that routes a build-time version update through the recipe's
  `.nvchecker.toml`; every other config is report-only, and `--no-sync`
  bypasses all provider lookups. An AUR provider may supply pkgrel/epoch or
  checksum anchors only when its fetched `.SRCINFO` matches `pkgbase`,
  `pkgver` and the expanded source array; a GitHub release digest anchors only
  its configured repo/tag/asset, and an absent digest is fetch-only. A provider
  outage defers the package; a checksum mismatch refuses the run and restores
  the recipe. `gsa -Qt` is the way to see which records opted in. A `-Sy`
  rewrite is volatile: it is left uncommitted for review and destroyed by the
  next store refresh, so commit it (and re-verify fetch-only sums with an
  independent download) instead of re-running the sync.
- **Optimization is the ENGINE's, not `makepkg.conf`'s.** The compiler line and
  the per-family passes live in `/etc/gsa/{gcc,clang}-makepkg.conf` and are
  injected as a generated `makepkg --config`; the host and user `makepkg.conf`
  are never sourced. No baseline flag in a recipe (`-O3`, `-march`, `-mtune`,
  `-pipe`, `-fno-plt`, `-fipa-pta`, `-fuse-ld=mold`, …); a package delta needs
  its reason in the file, and dropping a shipped flag is a substitution
  (`CFLAGS=${CFLAGS/-fno-math-errno/}`, never a re-assignment). Name the
  compiler when the delta is compiler-specific (`toolchain=` tag or a
  `CC=clang` driver marker); the engine refuses an ambiguous family. Per-package
  exceptions are documented one at a time in `AGENTS.md` §4. Trims follow the
  AMD target, must name what they no longer cover, and trim dead packaging
  paths together; keep whatever trains PGO or protects a maintained capability.
- **PGO recipes call the shared gate** (`lib/pgo.sh`) as the last statement of
  their package function — never copy its implementation. The seam is exactly:

  ```sh
  source "$startdir/../../../lib/pgo.sh"          # top level, before the functions
  verify_no_profile_instrumentation "$pkgdir"     # last line of each package*()
  ```

  The gate is fatal by design (`exit 1`, not `|| return 1`), and it inspects
  readelf symbols *and* strings because a stripped binary hides the symbols but
  keeps the baked `.gcda`/`.profraw` paths. The engine's
  fail-closed payload check at the install seam does not make the call
  optional. The training threshold is a **per-recipe `local`**
  (`pgo_min_gcda`, `pgo_min_profraw`, `pgo_min_samples`), deliberately not a
  `lib/pgo.sh` knob; below it the recipe falls back to a plain build. Changing
  a threshold is a behavioural change and belongs in a journal entry.
- **Verification is never weakened.** Never `--skippgpcheck`, never drop
  `?signed`, never trust a fingerprint that cannot be confirmed against
  published maintainer material. Checksums, signatures and the PGO/ABI gates
  are fail-closed; a green run that skipped the check is not a green run. A
  `b2sums` count error names nothing useful — add a parse-time guard naming
  both counts and the knob values, exempt `GENINTEG=1`, and prefer
  `makepkg --verifysource` as the cheap red/green.
- **Recipe code never writes engine state.** The recipe store resolves from
  `GSA_RECIPES_DIR` > `recipe_dir` > the build user's
  `~/.local/share/gsa/recipes` and is never `--state-dir`; never write
  `/var/lib/gsa` from a recipe.
- **Recipe text is public surface.** A comment explains the code, the kernel
  option or the trim — never the machine it was written on. Versions, thread
  counts, bootloader lines and incident narratives go in `docs/JOURNAL.md`.
- **Shell boundary.** The login shell is fish, but agent tool calls run in
  bash: hand any command to the user as `bash -c '…'`. Prefix makepkg and
  bare-repo git work with `GIT_CONFIG_COUNT=0` — agent shells inject
  `safe.bareRepository=explicit`, which breaks tag verification and LFS
  fetches. `rm` is a trash wrapper in fish; use `command rm`.
- **Never commit or push unprompted.** A green battery is evidence, not
  consent. Do not commit sources, archives, signatures, build trees or logs.
- **Every commit ends with two trailers**, in this order:
  `Assisted-by: LLM (human-reviewed)` then `Signed-off-by` matching the
  committer's configured git identity. `Assisted-by` discloses that an LLM
  drafted the change and a human reviewed it; `Signed-off-by` names who takes
  responsibility for it. No `Co-authored-by: Copilot` line — the assistant is
  already disclosed, and a second trailer duplicates one fact.

## Fixture authoring

A new fixture needs no runner edit — `tests/run-all.sh` discovers
`**/*.sh` recursively, excluding `tests/assets/` (frozen oracle) and
`tests/lib/`.

- **Non-negotiable properties**: non-mutating, `$TMPDIR`-scoped, and safe to
  run **concurrently** — the parallel default rests on it, so a fixture that
  breaks it is a fixture bug, not a reason to drop `-j`. The runner gives each
  fixture its own `GSA_BUILD_DIR="$work/build-cache/<fixture>"`; never share a
  build cache between fixtures.
- **Helpers are `.bash`, not `.sh`**, so discovery can never match them.
  Source them from a fixture rather than copying:

  ```sh
  source "$(dirname "${BASH_SOURCE[0]}")/lib/fixture-lib.bash"
  ```

  `tests/lib/fixture-lib.bash` builds the workspace skeleton and writes the
  trivial byte-identical stubs; its common entry points are `make_workspace`,
  `add_package`, `set_topology_record`, the `stub_*` writers, `run_builder`
  and `makepkg_printsrcinfo`. `tests/lib/rr-v2.bash` owns `format: 2` run-record
  parsing and the privileged `run_engine`/`run_engine_user` wrappers. Anything
  oracle-shaped (a fake `pacman`, a ticking `makepkg`, a signal logger) stays
  inline in the fixture that gives it meaning. Stub knobs are named
  `GSA_FAKE_*`; the builder's own inputs keep their names.
- Fixtures stub `sudo`/`pacman`/`date` through `PATH` and assert on the
  builder's own output and the decision rows — never on rendered prose.
- A new PGO family earns a fixture when its profile-leak shape is new; the
  existing C-autotools and Go families needed no `lib/pgo.sh` change.

## Working conventions for a Copilot session

The repository mandates a three-layer memory discipline (`AGENTS.md` §0, §7);
follow it or the next session starts blind:

- `.logs/scratchpad.md` — the **active buffer**, a tracked stub. Put dense tool
  output and intermediate state here, not in the conversation, and reset it to
  the stub after each action.
- `.logs/action-<ISO-date>-<task>.md` — the per-action export, never tracked.
  Anything that outgrows one journal line lives here.
- `docs/JOURNAL.md` — exactly **one dense line per action**: symptom → root
  cause → fix → validation → durable rule, naming the affected recipe ids and
  the command that proved it. A bare "fixed X" is not an entry.
- `docs/CURRENT.md` — the live stack snapshot. **Overwrite, never append**, and
  it is owned by another session lane: never edit it from a rebuild-campaign
  lane.
- Finished queue items in `AGENTS.md` §6 are **deleted**, never ticked.
- A living doc teaches how to *check* a fact (`gsa -Sl`, `pacman -Q`), never the
  shape of a retired era; retired spellings survive only in the engine
  contract's migration table.

## Common tasks

**Add a recipe** — the order matters, and one change does all of it:

1. Create `packages/<category>/<id>/PKGBUILD`; put local assets beside it and
   add the `!` negations plus the root `.gitignore` negation.
2. Add exactly one `config/topology.conf` record
   (`id|path|groups|edges[|tags]`); derive `groups` from `gsa -Qg`, and add an
   edge only with a build-order reason.
3. Regenerate the committed `.SRCINFO`.
4. `bash -n` the recipe, `gsa -Sl`, `gsa -Ma` (read it), then
   `gsa -S --dry-run @<group>`.

**Bump a version-synced recipe** — check the record carries
`version-sync=nvchecker` and the recipe has its `.nvchecker.toml`; run
`gsa -Sy`, review the uncommitted rewrite with `git diff`, verify fetch-only
sums independently, then commit the rewrite (the store refresh destroys it
otherwise). Bump `pkgrel` only *after* the first post-sync build.

**Investigate a break** — `gsa -Qi <ref>` for the wiring, `gsa -Qa <ref>` for
the ABI token, `gsa -Qr` for unresolved `DT_NEEDED` and exact-pin leftovers,
`gsa -Qp <archive>` for a hash/size disagreement, `gsa -Ml` for the per-package
build log. `ldd` on the shipped ELF is still the ground truth for a soname gap,
and a dependency edit is verified with `pacman -T` over the regenerated
metadata plus `readelf -d | grep NEEDED` — makepkg exiting 0 proves neither.

## Where the truth lives

| Document | Answers |
| --- | --- |
| `AGENTS.md` | Stack shape, dependency edges, landmines, rules, pitfalls, queue, shell hazards |
| `docs/maintainer-guide.md` | Adding and updating recipes, version-synced releases, coupled stacks, groups |
| `docs/package-policy.md` | What a recipe directory may hold versus what is fetched at build time; the `.SRCINFO` contract |
| `docs/source-sharing.md` | The shared-source mirror contract (`gsa -Mm`) |
| `docs/snapshot-expansion.md` | The Monday-boundary snapshot-pin programme, reconciled state and waves |
| `docs/CURRENT.md` | The live umbriel stack snapshot — overwrite, never append; owned by another lane |
| `docs/adr/` | The shared PGO gate (`0001`), the one-record topology (`0002`) |
| `CONTRIBUTING.md` | The recipe-change checklist, trimming standard, source verification, validation block |
| `SECURITY.md` | Trust model: a recipe is arbitrary shell at makepkg privilege |
| `CONTEXT.md` | Vocabulary: recipe, topology record, build-order edge, consumer expansion, coupled batch, lane, run record, deferral |
| `docs/JOURNAL.md` | The chronological log — one dense line per action |
| The engine repository | `docs/gsa-contract.md` (authoritative interface), `docs/build-guide.md`, `docs/architecture.md`, `docs/portability.md` |
