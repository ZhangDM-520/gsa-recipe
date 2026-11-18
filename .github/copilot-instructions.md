# Copilot instructions — the `gsa` recipe repository

Curated Arch Linux recipes for **AMD laptops** (AMD CPU, amdgpu/radeon) plus a declarative build topology. **Data only**: the `gsa` engine lives in `ZhangDM-520/gentoo-style-arch` and runs as `/usr/bin/gsa` (`packages/core/gsa-pm` packages it, self-tracking). Never vendor or patch engine code here; `docs/gsa-contract.md` in the engine repository is authoritative.

## Commands

```sh
bash tests/run-all.sh [filter|--serial|-j N]     # the battery; tests the installed /usr/bin/gsa
bash -n packages/<cat>/<pkg>/PKGBUILD            # recipe syntax
GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<pkg> > packages/<cat>/<pkg>/.SRCINFO
gsa -Qg | -Qt | -Qi <ref> | -Sl @git | -Qr | -Qu | -Ma
gsa --qa-check <declared-deps|abi-closure|abi-exposure|provides-versioning|purged-tools|stale-ignorepkg|swap-drift>
sudo gsa -S --dry-run @git     # repeat per group; plan only
sudo gsa -S --leaf <pkg>       # one recipe, no consumer expansion
GIT_CONFIG_COUNT=0 makepkg -f --dir packages/core/gsa-pm     # engine bootstrap
```

- `gsa -Ma` is report-only and **always exits 0** — read the report. One `package-drift` row per `packages/deprecated/` directory is expected.
- Never use a real rebuild as a syntax check, and never run two heavy builds concurrently (OOM risk). Build in the store or a copy of the tree; a repo-cwd build rewrites `pkgver=` in place.
- `gsa -Mm --noconfirm` is the one verb that rewrites the checkout (mirror symlinks). Probe without `--noconfirm` first.

## Change checklist

1. Recipe lives in `packages/<category>/<id>/` with `PKGBUILD`, committed `.SRCINFO`, and any local patch, asset or licence; a generator pair (`PKGBUILD.in` + `update.PKGBUILD`) stays in lockstep with `PKGBUILD`.
2. A new local asset must survive **two** ignore layers — the recipe's own `.gitignore` (`*` plus `!` negations) and the root `.gitignore` (which acknowledges only `LICENSES/`). Confirm with `git check-ignore -v <asset>` (no output = visible). Never let a recipe `.gitignore` match itself.
3. One `config/topology.conf` record: `id|path|groups|edges[|tags]`. It is the only place binding an ID to a path; groups come from the closed roster (`gsa -Qg`); edges need `pacman -T`/`.SRCINFO` evidence; tags carry `abi=must|should`, `abi-rev=<n>`, `app-cluster=<name>`, `version-sync=nvchecker`, `toolchain=gcc|clang`. A malformed record breaks every command.
4. Regenerate `.SRCINFO` from the same edit; `provides=` goes after `pkgver=`.
5. Validate in this order: `bash -n` → `.SRCINFO` → `gsa -Sl` → `gsa -Ma` (read it) → `gsa -S --dry-run` → `bash tests/run-all.sh`. Any topology edit needs the battery, not just the matching fixture.

## Refused in review

- Baseline compiler flags in a recipe (`-O3`, `-march`, `-mtune`, `-pipe`, `-fno-plt`, `-fuse-ld=mold`, LTO/RELRO). The engine injects them; a recipe keeps a reasoned delta or a substitution (`CFLAGS=${CFLAGS/-fno-math-errno/}`).
- Real-hand `b2sums` growth per knob (`b2sums+=()`); keep the flat list and add a parse-time guard instead.
- `--skippgpcheck`, dropping `?signed`, or `SKIP`ping a pinned `#commit=`/patch sum to get past a failure.
- `!check`/`autodeps` as `options` (invalid under pacman 7.x), or dropping a PGO-training or capability-protecting test.
- Unversioned provides for a NAME capability, hand-versioned soname provides, or a concrete provider where a virtual exists.
- Host facts in a recipe comment (thread counts, installed versions, incident narrative).
- Weakening an ABI/fail-closed gate, or writing `/var/lib/gsa` from a recipe.

## PGO seam

`source "$startdir/../../../lib/pgo.sh"` at top level and put `verify_no_profile_instrumentation "$pkgdir"` as the **last** statement of every `package*()` (fatal `exit 1`). Thresholds are per-recipe `local` variables, never a module knob. Phase 2 re-runs the configure, not only the build.

## Fixtures

`tests/*.sh` are discovered (a new one needs no runner edit), `$TMPDIR`-scoped, non-mutating and parallel-safe (`GSA_BUILD_DIR` per fixture), using `tests/lib/{fixture-lib,rr-v2}.bash` and `GSA_FAKE_*` stubs. Assert on builder output and decision rows (`--install-decide`), never rendered prose. A stub must scan argv rather than match option positions, and a fixture must never hardcode a value the recipe already owns.

## Commits

Every commit ends with `Assisted-by: LLM (human-reviewed)` then `Signed-off-by` matching the configured git identity; no `Co-authored-by`. Never commit or push unprompted — a green battery is evidence, not consent.
