# Snapshot expansion — pin the Monday commit, expose the snapshot name

Opened 2026-11-09 (owner decision 2026-11-01, "do it now"; scope and shape
revised by the owner 2026-11-09). Scope: every tracker in `@core`/`@build-tools`
whose source is a **moving git ref** becomes a snapshot — pinned to the last
commit at or before Monday 00:00 UTC.

Why: a floating ref makes every freshness pass a gamble. `gsa-recipe`'s
`freshness.rs` waives a rebuild while the recorded baseline trails the moving
ref by ≤ 5 upstream commits (`DEFAULT_VCS_SKIP_TOLERANCE`,
`REASON_FRESHNESS_WAIVED`) and reports `vcs-ref-moved` past it, so a fast
upstream churns senseless rebuild waves — three `llvm` builds in one day during
the 2026-11 campaign. A `#commit=` pin switches to exact semantics
(`vcs-ref-pinned-mismatch`: rebuild only on real inconsistency).

## The shape (revised 2026-11-09)

Two changes per recipe, and **nothing else**:

1. **The source ref** becomes `#commit=<sha>`, the last commit at or before the
   most recent Monday 00:00 UTC.
2. **The snapshot name is a frontend surface.** `gsa` accepts `<id>-snapshot` as
   an input alias for a pinned `<id>`; the recipe, its directory, its
   `pkgbase`/`pkgnames`, its `provides=` and its pacman identity are
   **unchanged** — still `-git`. `-snapshot` is not a conventional package
   suffix; `gcc-snapshot` is the real-name exception and stays exactly as it is.

No rename, therefore no `provides=`/`replaces=`/`conflicts=` churn, no topology
edit, no `pkgname` edit, no IgnorePkg/world/sets/index migration. That is the
whole point of the revision: the migration cost is one source line.

## 1 · Reconciled state (measured 2026-11-09)

Method, so the numbers are reproducible: scope is the topology rows whose group
list contains `core` or `build-tools` (`gsa -Qt`, never directory names); the
source class is the **primary** `source=()` entry's VCS ref as expanded in the
committed `.SRCINFO`; "already pinned" is reported both per primary source and
per any source, because the 2026-11-01 audit used the looser rule.

| | 2026-11-01 audit | 2026-11-09 (this pass) |
| --- | --- | --- |
| `core`+`build-tools` members | 324 | **333** |
| git-sourced | 226 | **230** |
| floating (no ref, primary) | 135¹ | **114** |
| `#commit=` (primary / any source) | 29 (any) | **24 / 29** |
| `#tag=` | 61 (+`hip-runtime`) | **69** |
| `#branch=` | not separated¹ | **23** |
| non-VCS | — | **103** |

¹ the audit folded `#branch=` into "floating"; on the same rule today the count
is 114 + 23 = **137** of 230, i.e. +2 against 135 for a roster that grew by 9.

The delta is explained and is not a regression: **9 recipes were added** since
(`hunspell`, `jasper`, `kcrash`, `kguiaddons`, `solid`, `v4l-utils` non-VCS;
`openjph`, `qt6-5compat`, `qt6-wayland` tag-pinned), and **8 were pinned on
2026-11-01** by the rule-64 wave — `llvm-git`, `rust-git`, `mesa-git`,
`libclc-git`, `spirv-llvm-translator-git`, `rust-bindgen-git`, `qt6-tools`,
`gcc-snapshot`. No pin was lost.

### The conversion set: 136 recipes

| set | count | note |
| --- | --- | --- |
| floating primary | 113 | the `-git` trackers |
| `#branch=`-pinned primary | 23 | **Q1 answered: convert them too**, so every snapshot means the same thing |
| exempt | 1 | `gsa-pm` — the engine may free-track (owner 2026-11-01) |
| out of scope | 69 `#tag=` + 103 non-VCS | a tag is already an exact ref; a tarball is a release |

The 23 branch-pinned recipes are `libpng-git` (`libpng16`), `libseccomp-git`
(`release-2.6`), the `qt6-*` release-branch modules, `autofdo-git`,
`gtk3-git`, `jack2-git`, `libarchive-git`, `libmypaint-git`, `qt5-base-git`,
`qt6-base-git`, `sdl2-git`, `xxhash-git`, `zstd-git`. Pinning them to a Monday
commit on their own branch keeps the maintenance-line intent while removing the
drift.

Fan-out (topology in-degree), which sizes a wave: **5** over 100
(`git-git` 406, `meson-git` 155, `cmake-git` 143, `glib2-git` 120,
`zlib-ng-compat-git` 118), **8** at 31–100, **59** at 5–30, **64** at ≤ 4.
The working list with per-recipe fan-out and today's ref is
`.logs/snapshot-manifest-2026-11-09.md` (regenerate it, never hand-maintain it).

### Two pieces of the idiom that are forced, not chosen

- **makepkg accepts exactly one ref fragment.** `get_uri_fragment` takes
  everything after `#` (minus a trailing `?...`), and `download_git` cases on
  `${fragment%%=*}` as `commit|tag|branch` — so `#branch=main&commit=<sha>` is
  a single unrecognised fragment and the build aborts. A pin therefore
  **replaces** `#branch=`; the ref it was taken from has to be recorded
  elsewhere. 113 recipes lose nothing (they were on the default ref); the 23
  branch-pinned ones gain a recipe-local `_snapshot_ref=<ref>` variable, which
  makepkg ignores and the `-Sy` provider reads when it advances the pin.
- **The first pin is a version downgrade.** `pkgver()` recomputes from the
  checked-out commit, so pinning HEAD back to last Monday *lowers* the version.
  `gsa`'s install seam skips a "not-newer" archive by design, so the first pass
  installs with `-Sf`/`-Uf`; every later weekly advance moves forward and needs
  no force.

### Excluded, deliberately

- **`#tag=`-pinned (69)** — release-pinned; a tag is an exact ref.
- **non-VCS (103)** — tarball releases.
- **`gsa-pm`** — owner exemption.

### Two in-scope repairs the pin uncovers

- **`ncurses-git` has no `pkgver()`** — its version is hand-written
  (`6.6.20260926.r0.g41553966`) and never recomputes, so it cannot be pinned
  coherently. Q2 answered: gaining a `pkgver()` is in scope.
- **`qt6-tools`** still carries one unpinned auxiliary source (the
  `playground/qlitehtml` secondary) — pin it in the same change.

## 2 · Per-recipe conversion

```sh
# 1. resolve the anchor from the recipe's OWN mirror (never the network at edit time)
mirror=~/.gsa-src/<pkg>/                 # SRCDEST's bare clone
ref=main                                 # the recipe's current ref; origin/HEAD when it had none
sha=$(git -C "$mirror" rev-list -1 --before='<Mon> 00:00Z' origin/$ref)

# 2. one commit: the pin (and _snapshot_ref only where the ref was explicit)
#    source=("...git+<url>#commit=$sha")   _snapshot_ref=$ref   pkgver=<recomputed>
GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<id> \
  > packages/<cat>/<id>/.SRCINFO
bash -n packages/<cat>/<id>/PKGBUILD

# 3. validate, then build and install FORCED (the pin is a downgrade)
gsa -Ma                                  # report-only; read the rows
bash tests/run-all.sh
gsa -B --leaf <id>
gsa -Uf <id>                             # -f: the first pin lowers the version
```

`--leaf` matters: the default `-S` expands to the transitive consumer closure
(406 dependants for `git-git`). A pin is not an ABI event — only `icu-git`
carries `abi=must` among the 136 — so consumers do not rebuild for the pin.

No topology change, no `.SRCINFO` name change, no `pkgname` change: the only
diff per recipe is the source line, the `pkgver`, and (for 23) `_snapshot_ref`.

## 3 · Waves

One batch at a time, battery green between batches. Because there is no rename,
a batch cannot break the topology loader or a consumer's dependency — the risk
is a walled build, which is local to the recipe.

| wave | contents | why this order |
| --- | --- | --- |
| **W0 — engine alias first** | `gsa` accepts `<id>-snapshot` for a pinned `<id>`, with the guard and its fixture; the `-snapshot` wording lands in `AGENTS.md` §4 | the visible half of the feature must exist before recipes start claiming it, and a wrong alias must fail loudly — **landed 2026-11-09**, pinned by the engine's `tests/project.sh` §9 |
| **W1 — leaves (64)** | fan-out ≤ 4 | cheapest end-to-end validation of the idiom |
| **W2 — mid (59)** | fan-out 5–30, by subsystem: codecs, X/graphics, system libraries | adjacency keeps each batch's verification inside one subsystem |
| **W3 — build tools (5)** | `ninja-git`, `cmake-git`, `meson-git`, `zlib-ng-compat-git`, `glib2-git` | makedepends for nearly everything; each gets its own pass |
| **W4 — the rest (8)** | `git-git` 406, `cairo-git` 48, `icu-git` 38 (`abi=must`), `pango-git` 34, `wayland-git` 32, plus the 3 remaining 31–100 rows | largest fan-out and the ABI nucleus last |
| **W5 — engine provider** | `-Sy` resolves "last commit ≤ Monday 00:00Z" and rewrites `#commit=` + `pkgver` together; then retire the 5-commit waiver for pinned families | owner's ordering: establish the convention by hand, then automate |

Each wave ends with `gsa -Ma` clean of new rows, `bash tests/run-all.sh` green,
and the wave's recipes installed at their pinned version.

## 4 · Engine work

1. **W0 — the snapshot alias (landed 2026-11-09).** Target resolution accepts `<id>-snapshot` when
   `<id>`'s primary VCS source is `#commit=`-pinned, and refuses otherwise with
   rc 2 naming the reason ("`foo-git` is not a snapshot: it tracks
   `<ref>`"). Derived from the source ref, so **no new topology vocabulary** and
   no per-recipe opt-in: a pin *is* the snapshot. Real ids never change, and the
   run record, listings and plan keep printing the true id — a record must not
   misname the package it installed. Nearest-candidate hints already cover the
   typo path. Code: `gsa-cli`'s `select::resolve_snapshot_alias`; pinned by
   `tests/project.sh` §9 (resolve, the four refusals, the real-id precedence).
2. **W5 — the `-Sy` provider.** A version-sync provider kind that resolves the
   Monday-boundary commit for a recipe's own git URL (`_snapshot_ref` when
   present, else the default ref) and rewrites `#commit=` **and** `pkgver` in
   one anchored pass (rule 18: the anchor is an upstream commit, which is
   publisher-produced). Contract amendment + fixtures.
3. **W5 — retire the waiver for pinned families.** Once a family is exact-pinned
   `DEFAULT_VCS_SKIP_TOLERANCE` has nothing to waive; keep it only for recipes
   that still float.

## 5 · Acceptance

Per wave: battery green · `gsa -Ma` with no new finding · the wave's recipes
installed at the pinned version · `gsa -Sl <id>-snapshot` resolves for each.

Whole programme: every `@core`/`@build-tools` tracker whose ref used to move
carries `#commit=` · `gsa -Ma` clean · `gsa -Sy` advancing pins without a
manual edit · `gsa -S <id>-snapshot` resolving for all 136 and refusing for a
recipe that still floats.

## 6 · Risks and their detection

| risk | detection |
| --- | --- |
| a pin is taken from the wrong ref (a branch-pinned recipe pinned to the default line) | `_snapshot_ref` recorded; the wave's diff shows the ref it replaced |
| the first install is skipped as "not newer" | `-Uf` in the procedure; a wave that reports "nothing to install" is a red flag |
| a `describe`-based `pkgver` inverts across a tag boundary | per-wave monotonicity check against the installed version; the 2026-11-01 audit's `rust-bindgen-git` `r17` case is the known instance |
| an alias resolves to a recipe that is not a snapshot | rc 2 with the reason; fixture pins both directions |
| a mirror is missing so the anchor cannot be resolved | resolve from `SRCDEST`, never the network at edit time; defer the recipe rather than guess |

## 7 · Deferred (not part of this programme)

`pkgver` scheme normalization (`git describe` → `<upstream>.r<rev-list --count
HEAD>.g<short>`) was bundled with the 2026-11-01 decision because a rename would
have absorbed the version-shape change for free. With the rename withdrawn it
would be a bare version move for 91 recipes, so it is **deferred**: the
inversion risk above is tracked per wave instead. Revisit if a pin inverts.

## 8 · W1 status (2026-11-09)

**Pinned: 64/64 — and that is the whole of W1 so far.** Every fan-out ≤ 4
tracker carries `#commit=` at the last commit at or before Monday 2026-11-09
00:00 UTC; 12 of them are branch-pinned and record `_snapshot_ref=<branch>` in
the PKGBUILD (invisible to makepkg, read by the future `-Sy` provider).
`.SRCINFO` regenerated for all 64 through `makepkg --printsrcinfo`;
`tests/srcinfo-freshness.sh` is clean over the whole tree (665 recipes) and the
recipe battery is 27/27.

**Queued: the weekend full rebuild.** The owner runs a full rebuild this
weekend or the next (2026-11-09 decision); W1's build + install and W2–W4's
pins ride it, and the whole programme is VERIFIED afterwards rather than
per-wave in this session — so no wave is called done until that pass reports.

**Build and install are deliberately NOT part of this pass** (owner,
2026-11-09: "do not do real build test"). Two consequences to keep in mind:

- A pin is a recipe-file change only. Until a wave is built and installed, the
  installed packages still carry the previous versions — an advance, not a
  downgrade, for every recipe here.
- Any archive built earlier today predates the `--fetch` re-anchoring that
  moved the pins from the mirror's stale HEAD to the true Monday boundary.
  Treat those archives as stale; the wave's build must run again against the
  current pins whenever the owner starts it.

### Rules learned while applying the pins

- **Never resolve a branch name bare in a mirror.** A mirror can carry a TAG
  with the branch's name (`refs/tags/master` beside `refs/heads/master`); git
  then resolves the ambiguous name to the tag. `autofdo-git` was pinned to a
  2024 tag commit this way and its build died on `unknown target
  create_llvm_prof`. Resolve fully qualified, in order:
  `refs/remotes/origin/<ref>`, `refs/heads/<ref>`, then the bare name.
- **A build run whose workspace is this git tree rewrites `pkgver=` in place.**
  Running `gsa -B` in the checkout bumped 30 out-of-wave PKGBUILDs through the
  fetch-side `pkgver()` rewrite and left their `.SRCINFO` stale (they were
  restored). Build from the canonical store, or from a copy of the tree.
- **A pinned provider whose `provides=` embeds `$pkgver` drags its consumer
  cone** — `-B --leaf` does not suppress the ABI wave (`libcolord-git` alone
  expanded to ~150 packages, measured). The wave is computed from subscription
  records under the real state root, so a build-only pass in a COPY of the tree
  with a scratch `GSA_STATE_DIR` sees no wave:

  ```sh
  cp -a ~/Projects/gsa-recipe /tmp/gsa-pin-build   # a copy: builds rewrite pkgver in place
  cd /tmp/gsa-pin-build
  GSA_STATE_DIR=/tmp/gsa-pin-state sudo -n --preserve-env=GSA_STATE_DIR \
    gsa -B --leaf $(cat wave-ids)                   # archives land in the real build dir
  ```

  Installing then goes through the real state (`gsa -U <archive paths>`, since
  a scratch state has no binpkg rows), and a provider whose version moved
  installs **with** its consumer cone, never solo.
- Two environment blocks seen during the discarded build pass, worth knowing
  before the real one: `libidn2-git`'s `./bootstrap` fetches gnulib from a
  doubled-`https.` savannah URL that answers HTTP 500, and `libmypaint-git`
  wants `gegl` via pkg-config while the installed `gegl-git` ships only
  `gegl-0.4.pc`.
