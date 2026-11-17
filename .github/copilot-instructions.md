# Copilot instructions — Gentoo_Style_Arch (recipe repository)

Curated Arch Linux recipe set for **AMD laptops** (AMD CPU, amdgpu/radeon) plus declarative build topology (`config/topology.conf`). **Data only**: the `gsa` engine lives in `ZhangDM-520/gentoo-style-arch` and runs as `/usr/bin/gsa` (`packages/core/gsa-pm` packages it, self-tracking). Never vendor/patch engine code here.

- **`AGENTS.md`**: Stack shape, edges, landmines, rule/pitfall/queue indexes (`docs/{rules,optimization-playbook,pitfalls,queue}.md` hold details).
- **`docs/JOURNAL.md` & `.logs/scratchpad.md`**: Chronology tail and active working buffer.

## Commands

Privilege follows pacman: `-Q*`, `-Sl`, `-Ma`/`-Md`/`-Mi`/`-Ml`/`-Ms`/`-Mw`, `--dry-run`, `-Mh`, and `--{install-decide,qa-check,print-*}` run unprivileged; `-S`, `-B`, `-U`, `-Sw` (`fetch`), `-Sy`, `-Su`, `-Mc*`, and write-side `-M*` require root (rc `3`); `-Mm` refuses root. `makepkg` always drops to the user.

```sh
gsa --help | -Qg | -Qt | -Qi <ref> | -Sl @git | -Qa <ref> | -Qr | -Qp <arc> | -Qu | -Qb | -Ma
bash -n packages/<cat>/<pkg>/PKGBUILD && GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<pkg> > packages/<cat>/<pkg>/.SRCINFO
gsa --qa-check <declared-deps|abi-closure|abi-exposure|provides-versioning|purged-tools|stale-ignorepkg|swap-drift>
bash tests/run-all.sh [filter|--serial|-j N]                 # tests installed /usr/bin/gsa (GSA_TEST_GSA_BIN=... overrides)
cd ../gentoo-style-arch && GSA_RECIPE_CHECKOUT=$PWD/../gsa-recipe bash tests/srcinfo-freshness.sh
sudo gsa -S --dry-run @git | sudo gsa -B --leaf <pkg> | sudo gsa -S <pkg|@core> | sudo gsa -Sy
sudo gsa -Md --fix | sudo gsa -Mi [--prune|--backfill] | gsa -Mh | sudo gsa -Ml --keep N | sudo gsa -Mc @git
```

- **Audit & mirror notes**: `gsa -Ma` always exits `0`—read its report (`packages/deprecated/` `package-drift` rows are expected). `gsa -Mm` rewrites cwd recipes into mirror symlinks when passed `--noconfirm` (probe without it first).
- **Bootstrap `gsa-pm`**: Build via `GIT_CONFIG_COUNT=0 makepkg -f --dir packages/core/gsa-pm`.
- **Build safety**: Never use real rebuilds as syntax checks or run concurrent heavy builds (OOM risk); build in store/runtime clone, never in checkout.

## Selection semantics & exit codes

Selections expand to **transitive consumers** (`--leaf` builds exact targets). Exact lookup only (typos exit `2`); `<id>-snapshot` aliases primary `#commit=` recipes while keeping `-git` ids. `--skip` and `--skip-built` cannot combine. `gsa --install-decide <checked|force> <arc...>` exposes install rows (`0` plan, `1` refusal, `2` usage).

- **Exit codes**: `0` clean, `1` `--fail-fast` build failure, `2` usage/config error, `3` refusal/gate abort, `4` cone-stop failure, `5` deferral-only, `130` interrupted (record emitted).

## Structure & mental model

Topology (not folder names) defines build order and groups (`git`, `stable`, `core`, `misc`, `app`, `build-tools`).

- **`packages/<cat>/<id>/`**: `PKGBUILD` + committed `.SRCINFO` + local patches/assets/licences (`PKGBUILD.in` + `update.PKGBUILD` kept in lockstep). `packages/deprecated/` holds parked recipes (commented out in `topology.conf`).
- **`config/` (3 files only; enforced by engine `tests/project.sh`)**: `topology.conf` (`id|path|groups|edges[|tags]`, tags: `abi=must|should`, `abi-rev=<n>`, `app-cluster=<name>`, `version-sync=nvchecker`, `toolchain=gcc|clang`), `build-defaults.conf`, `abi-exclusions.conf` (`id|reason|review-by`).
- **`lib/`, `tools/`, `tests/`**: `lib/{pgo.sh,cups-config}`, `tools/` diagnostics, `tests/` (`tests/assets/` frozen oracle, `tests/lib/*.bash` helpers).
- **`gsa-pm` `--print-*` seam**: Ships `/etc/gsa/*-makepkg.conf` and shell completions via `tests/gsa-pm-shipped-files.sh`.

## Key conventions & fixture authoring

- **Two ignore layers**: Local `*` + `!` negations and root `.gitignore` (denies subdirs except `LICENSES/`); verify with `git check-ignore -v <asset>`. Fetched-only inputs go in `FETCHED-ONLY`.
- **Flat `b2sums`**: Keep `b2sums` flat (guard mismatches, exempt `GENINTEG=1`).
- **Provides & virtual deps**: Toolchain `-git` provides are versioned (`meson=${pkgver}`); library provides are bare sonames (`libfoo.so`); use virtual deps (`java-runtime`, `libgl`).
- **Engine-owned optimization & PGO**: No baseline flags in recipes; source `lib/pgo.sh` at top and put `verify_no_profile_instrumentation "$pkgdir"` last in every `package*` (fatal `exit 1`; per-recipe `pgo_min_*` thresholds).
- **Fail-closed gates & state**: Never weaken checksums/PGP/ABI gates and never write `/var/lib/gsa` from recipes.
- **Fixtures (`tests/`)**: `$TMPDIR`-scoped, non-mutating, parallel-safe (`GSA_BUILD_DIR` isolated per fixture), using `tests/lib/{fixture-lib,rr-v2}.bash` and `GSA_FAKE_*` stubs; assert on builder output/decision rows, not prose.
- **Workflow**: Add recipes in order (`PKGBUILD` + negations -> `topology.conf` -> `.SRCINFO` -> `bash -n`/`gsa -Sl`/`gsa -Ma`/`--dry-run`); review uncommitted `gsa -Sy` diffs before committing.
- **Work log**: Keep comments public (`docs/JOURNAL.md` 1-line summary; `.logs/scratchpad.md` reset per task; `docs/CURRENT.md` overwrite-only by its own lane).
- **Commit trailers**: End commits with `Assisted-by: LLM (human-reviewed)` then `Signed-off-by:` (no `Co-authored-by`); ask before committing/pushing.
