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
of `docs/JOURNAL.md` for what just changed. Rules and pitfalls are not restated
here; a rule copied into a second file drifts in one of them.

## Commands

```sh
bash tests/run-all.sh                    # whole battery, parallel by default
bash tests/run-all.sh recipe             # substring filter (a typo exits 2)
bash tests/run-all.sh --serial           # one at a time, for a flaky fixture
bash tests/run-all.sh -j 4               # cap concurrency
bash tests/<name>.sh                     # one fixture, standalone
GSA_TEST_GSA_BIN=$PWD/../gentoo-style-arch/target/release/gsa bash tests/run-all.sh

bash -n packages/<cat>/<pkg>/PKGBUILD    # recipe parse
GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<pkg> \
  > packages/<cat>/<pkg>/.SRCINFO        # regenerate the COMMITTED .SRCINFO

gsa -Qg                                  # group roster and members
gsa -Sl @git                             # ordered listing (re-validates map, graph, sort)
gsa -Ma                                  # audit lints: report-only, ALWAYS exits 0 — read it
gsa -S --dry-run @git                    # plan + decision rows, no mutation
gsa -S @core                             # ABI-coupled core update
```

The battery validates this repository **through the installed engine**, which
is the contract's rule: it prints the binary and its owning package, and a
`GSA_TEST_GSA_BIN` run is a pre-install deviation to be reported as such. A
stale `/usr/bin/gsa` makes the battery test old code. Fixtures are
non-mutating, `$TMPDIR`-scoped and must stay parallel-safe; they are discovered
recursively, so a new one needs no runner edit. `gsa -Ma`'s exit status says
nothing about the audit — a green run is not a clean report.

Never use a real rebuild as a syntax check, and never run two heavy builds at
once (check for in-flight `makepkg` first).

## Structure and mental model

- `packages/<category>/<id>/` — `PKGBUILD` is the source of truth with the
  generated `.SRCINFO` committed beside it, plus local patches, hooks, install
  files, desktop assets and upstream licence material. A generated `PKGBUILD`
  commits its generator pair (`PKGBUILD.in` + `update.PKGBUILD`). Physical
  categories (`git`, `stable`, `core`, `misc`, and the parked `deprecated`
  tier) are a filing system, **not** the build order.
- `config/` — exactly three files. `topology.conf` is one record per package,
  `id|path|groups|edges[|tags]`, and is the only place that binds an id to a
  recipe path. `build-defaults.conf` holds lanes/jobs/intensity and memory
  budgets. `abi-exclusions.conf` holds `id|reason|review-by` rows. Anything
  else under `config/` is unreachable state and fails a fixture.
- `lib/` — shared helpers sourced from recipes: `pgo.sh` (the one PGO payload
  gate) and `cups-config`.
- `tools/` — host diagnostics, deliberately outside the battery: `nvcheck.sh`,
  `provides-audit.sh`, `go-modcache-check.sh`.
- `tests/` — the fixture battery; `tests/assets/` is frozen oracle material and
  is never discovered, `tests/lib/` holds `.bash` synthesis helpers.

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
  any other record shape. Never add a second file that maps ids to paths.
- **`.SRCINFO` is committed metadata.** Regenerate it after every `PKGBUILD`
  edit and commit both; a stale `.SRCINFO` is what the engine and the fixtures
  actually read.
- **A new local asset must survive two ignore layers**: the recipe's own
  default-deny `*` plus `!` negations, and the root `.gitignore`, which denies
  every new subdirectory under a recipe and negates only `LICENSES/`. Verify
  with `git check-ignore -v <asset>` — no output means it is visible. Never let
  a recipe `.gitignore` match itself.
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
  the recipe.
- **Optimization is the ENGINE's, not `makepkg.conf`'s.** The compiler line and
  the per-family passes live in `/etc/gsa/{gcc,clang}-makepkg.conf` and are
  injected as a generated `makepkg --config`; the host and user `makepkg.conf`
  are never sourced. No baseline flag in a recipe (`-O3`, `-march`, `-mtune`,
  `-pipe`, `-fno-plt`, `-fipa-pta`, `-fuse-ld=mold`, …); a package delta needs
  its reason in the file, and dropping a shipped flag is a substitution
  (`CFLAGS=${CFLAGS/-fno-math-errno/}`). Per-package exceptions are documented
  one at a time in `AGENTS.md` §4. Trims follow the AMD target and must name
  what they no longer cover. Trim dead packaging paths together, and keep
  whatever trains PGO or protects a maintained capability.
- **PGO recipes call the shared gate** (`lib/pgo.sh`) as the last statement of
  their package function — never copy its implementation. The engine's
  fail-closed payload check at the install seam does not make the call
  optional.
- **Verification is never weakened.** Never `--skippgpcheck`, never drop
  `?signed`, never trust a fingerprint that cannot be confirmed against
  published maintainer material. Checksums, signatures and the PGO/ABI gates
  are fail-closed; a green run that skipped the check is not a green run.
- **Assert on decision rows, not prose.** `gsa --install-decide <checked|force>
  <archive…>` prints the install rows and exits 0 plan / 1 refusal / 2 bad
  usage.
- **Build in the runtime clone or the store, never in this checkout.** A run
  started here once left 24 GB of checkout and packaging state inside the
  published tree. Engine logs live under the state root, outside the clone.
- **Shell boundary.** The login shell is fish, but agent tool calls run in
  bash: hand any command to the user as `bash -c '…'`. Prefix makepkg and
  bare-repo git work with `GIT_CONFIG_COUNT=0` — agent shells inject
  `safe.bareRepository=explicit`, which breaks tag verification and LFS
  fetches. `rm` is a trash wrapper in fish; use `command rm`.
- **Never commit or push unprompted.** A green battery is evidence, not
  consent. Do not commit sources, archives, signatures, build trees or logs.
  Trailers:
  `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>`.

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
