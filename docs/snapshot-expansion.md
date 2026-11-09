# Snapshot expansion — reconcile, then convert

Opened 2026-11-09 (owner decision 2026-11-01, "do it now"). Scope: every
floating VCS tracker in `@core`/`@build-tools` becomes a **snapshot** — pinned
to the last commit at or before Monday 00:00 UTC, renamed `-git` →
`-snapshot`, with a permanent versioned `provides=` for the old name.

Why: a floating ref makes every freshness pass a gamble. `gsa-recipe`'s
`freshness.rs` waives a rebuild while the recorded baseline trails the moving
ref by ≤ 5 upstream commits (`DEFAULT_VCS_SKIP_TOLERANCE`,
`REASON_FRESHNESS_WAIVED`) and reports `vcs-ref-moved` past it, so a fast
upstream churns senseless rebuild waves — three `llvm` builds in one day during
the 2026-11 campaign. A `#commit=` pin switches to exact semantics
(`vcs-ref-pinned-mismatch`: rebuild only on real inconsistency), and the recipe
stops being "git tracking" — hence the name.

## 1 · Reconciled state (measured 2026-11-09)

Method, so the numbers are reproducible: scope is the topology rows whose group
list contains `core` or `build-tools` (`gsa -Qt`, never directory names); the
source class is the **primary** `source=()` entry's VCS ref as expanded in the
committed `.SRCINFO`; "already pinned" is reported both for the primary source
and for *any* source, because the 2026-11-01 audit used the looser rule.

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

The delta is explained and not a regression: **9 recipes were added** since
(`hunspell`, `jasper`, `kcrash`, `kguiaddons`, `solid`, `v4l-utils` non-VCS;
`openjph`, `qt6-5compat`, `qt6-wayland` tag-pinned), and **8 were pinned on
2026-11-01** by the rule-64 wave — `llvm-git`, `rust-git`, `mesa-git`,
`libclc-git`, `spirv-llvm-translator-git`, `rust-bindgen-git`, `qt6-tools`,
`gcc-snapshot`. No pin was lost.

### What "already converted" actually means

- **`gcc-snapshot` is the only recipe carrying the `-snapshot` name** (and it
  already has the split-output form `lib32-gcc-libs-snapshot`). It is the
  naming precedent, not a partially finished wave.
- **The rule-64 toolchain family is 9/9 pinned**: `llvm-git`, `rust-git`,
  `mesa-git`, `libclc-git`, `spirv-llvm-translator-git`, `gcc-snapshot`,
  `qt6-tools`, `pyside6-git`, `rust-bindgen-git`. One residue: `qt6-tools`
  still carries **one unpinned auxiliary source** (the `playground/qlitehtml`
  secondary), which the 2026-11-01 item already called out.
- **113 floating `-git` recipes remain untouched** — the programme.

### The 113, measured

| fact | count |
| --- | --- |
| floating primary, name ends `-git` (rename candidates) | **113** |
| floating but exempt (`gsa-pm` — the engine may free-track) | 1 |
| split recipes (multiple `pkgname` outputs) | 13 (130 output names) |
| `pkgbase` ≠ recipe id | 0 |
| already declare `provides=` | 113 |
| already declare `replaces=` | 4 |
| `-snapshot` target name already taken | **0** |

`pkgver()` schemes among the 113: **91 `git describe`**, 18 count-based,
4 custom (`harfbuzz`, `libmysofa`, `libpciaccess`, `wayland` — all
`describe --long --tags` spellings), and **1 with no `pkgver()` at all**
(`ncurses-git`: its version never recomputes, so it cannot be pinned without
gaining one).

Fan-out (topology in-degree — how many recipes list it as a build-order
prerequisite), which is what sizes a wave:

| bucket | recipes |
| --- | --- |
| > 100 | 5 — `git-git` 406, `meson-git` 155, `cmake-git` 143, `glib2-git` 120, `zlib-ng-compat-git` 118 |
| 31–100 | 5 — `ninja-git` 85, `cairo-git` 48, `icu-git` 38, `pango-git` 34, `wayland-git` 32 |
| 5–30 | 51 |
| ≤ 4 | 52 |

Only **3 of the 113 carry an ABI tag** (`icu-git` `abi=must`; `mold-git` and
`fcitx5-qt-git` `abi=should`), so a pin is not an ABI event for the other 110 —
the consumer wave is a selection-expansion cost, not a correctness one.

Pacman-side safety, measured: **zero exact-version (`name=ver`) pins** on a
candidate anywhere in the tree, and only two range pins
(`gimp-git` on `babl-git>=0.1.118`, `gegl-git>=0.4.66`). A **versioned**
provide satisfies both, which is why the old name must never be provided
unversioned.

## 2 · Exclusions (deliberate, not oversights)

- **`gsa-pm`** — owner decision 2026-11-01: the engine is safe to track git and
  rebuild any time.
- **`#tag=`-pinned (69)** — release-pinned, and a tag is an exact ref already.
- **`#branch=`-pinned (23)** — a named maintenance branch (rule 30's attestation
  carve-out): `libpng-git` on `libpng16`, `libseccomp-git` on `release-2.6`,
  the `qt6-*` modules on their release branch, `autofdo-git`, `gtk3-git`,
  `jack2-git`, `libarchive-git`, `libmypaint-git`, `qt5-base-git`,
  `qt6-base-git`, `sdl2-git`, `xxhash-git`, `zstd-git`. **Open question for the
  owner**: a branch tip moves exactly like a floating HEAD, so these carry the
  same churn — convert them too, or keep them as the explicit "track the
  maintenance line" set? Recommendation: keep, and let the rule-64 weekly pin
  cover only what they name.
- **non-VCS (103)** — tarball releases; nothing to pin.

## 3 · Decisions this plan needs

1. **Name idiom.** `-git` → `-snapshot` by suffix on the recipe id and on every
   `pkgname` (`glib2-devel-git` → `glib2-devel-snapshot`), matching
   `lib32-gcc-libs-snapshot`. Verified collision-free for all 113.
2. **pacman honesty idiom per renamed recipe** (owner 2026-11-01):
   `provides=('<old-name>=$pkgver')` **versioned** + `replaces=('<old-name>')` +
   `conflicts=('<old-name>')`. The old-name provide is **permanent** — never
   removed later. Every one of the 113 already has a `provides=()` to append to.
3. **`pkgver` scheme.** Normalize to `<upstream>.r<rev-list --count HEAD>.g<short>`
   (the `rust-git` spelling). This kills cross-tag inversions — `rust-bindgen-git`
   currently reads `0.73.2.r17.gf08d4fff` where `r17` is commits *since the tag*,
   which inverts against an older boundary. 91 of the 113 are `describe`-based
   and need this; the already-pinned family needs the same audit.
   Because every converted recipe is **renamed**, the version-shape change rides
   along inside a new pacman package — it costs no extra database transition.
4. **The Monday anchor.** `#commit=` = `git rev-list -1 --before='<Mon 00:00Z>'
   <ref>` read from the recipe's own `SRCDEST` mirror (never a fresh clone, never
   the network at edit time), written into the source entry; `pkgver` moves in
   the same commit. Same command for the weekly advance, forever.
5. **`ncurses-git`** needs a `pkgver()` added before it can be pinned.
6. **`qt6-tools`' `playground/qlitehtml`** auxiliary source gets pinned (the
   2026-11-01 item asked for it).

## 4 · Per-recipe conversion (one procedure, no variants)

```sh
# 1. resolve the anchor from the recipe's own mirror
mirror=~/.gsa-src/<pkg>/          # SRCDEST's bare clone
sha=$(git -C "$mirror" rev-list -1 --before='2026-11-09 00:00Z' <ref>)
# 2. pin + rename + provide in one commit
#    source=("...git+<url>#commit=$sha")   pkgver=<ver>.r<count>.g<short>
#    pkgname=<name>-snapshot …             provides+=(<old-git-name>=$pkgver)
#    replaces=(<old-git-name>) conflicts=(<old-git-name>)
git mv packages/<cat>/<id>-git packages/<cat>/<id>-snapshot
# 3. topology: id, path, and every edge mention (see §6)
# 4. regenerate metadata and validate
GIT_CONFIG_COUNT=0 makepkg --printsrcinfo --dir packages/<cat>/<id>-snapshot \
  > packages/<cat>/<id>-snapshot/.SRCINFO
bash -n packages/<cat>/<id>-snapshot/PKGBUILD
gsa -Ma                       # report-only; read the rows
bash tests/run-all.sh         # the recipe battery
# 5. build and swap under the new name; the old name must vanish from the DB
gsa -B --leaf <id>-snapshot
gsa -U <id>-snapshot          # replaces+provides carries the transition
gsa -Mi --backfill            # re-register IgnorePkg under the new names
```

`--leaf` matters: the default `-S` expands to the transitive consumer closure,
which for `git-git` (406 dependants) is a full-system rebuild. The rename is
pacman-transparent (provide + replaces), so the consumers do **not** need to
rebuild for the transition — only for a real ABI move.

## 5 · Waves

One coupled batch at a time — pin, rename, provide, build, battery green, then
the next. Never a mixed state inside a batch; the provide makes the mixed state
between batches resolvable.

| wave | contents | why this order |
| --- | --- | --- |
| **W0 — guard** | engine report-only lint `pin-discipline` + a recipe fixture; document the naming idiom in `AGENTS.md` §4 | a ratchet first, so a new floating `-git` in `@core` goes red instead of being discovered later |
| **W1 — leaves (52)** | fan-out ≤ 4 | cheapest end-to-end validation of the idiom: `acl`, `brotli`, `gdbm`, `jemalloc`, `libuv`, `libzip`, `libei`, `gegl`, `babl`, `fcitx5-qt` … |
| **W2 — mid (51)** | fan-out 5–30, split by adjacency: codecs (`ffmpeg`, `libwebp`, `libjpeg-turbo`, `libheif`, `libsndfile`, `opus`, `lz4`, `bzip2`, `xz`), X/graphics (`libx11`, `libxcb`, `libxext`, `libxrandr`, `libxi`, `libxpm`, `libxft`, `freetype2`, `fontconfig`, `harfbuzz`, `pango`, `cairo`, `gtk4`, `libadwaita`, `librsvg`, `libglvnd`, `vulkan-*`), system (`ncurses`, `readline`, `libffi`, `elfutils`, `expat`, `pcre2`, `libxml2`, `libcap-ng`, `libbpf`, `liburing`, `polkit`, `krb5`, `gnutls`, `libusb`, `libinput`, `libdrm`, `libpulse`, `sndfile`…) | adjacency keeps each batch's verification inside one subsystem |
| **W3 — build tools (5)** | `ninja-git` 85, `cmake-git` 143, `meson-git` 155, `zlib-ng-compat-git` 118, `glib2-git` 120 | these are makedepends for nearly everything: a bad batch is a whole-system wall, so each gets its own pass and its own battery run |
| **W4 — the rest (5)** | `git-git` 406, `cairo-git` 48, `icu-git` 38 (`abi=must`), `pango-git` 34, `wayland-git` 32 | the ABI nucleus and the largest fan-out last, when the idiom is proven 108 times |
| **W5 — engine (LAST)** | the `-Sy` snapshot provider + retire the 5-commit waiver for pinned families | owner's ordering: establish the convention by hand, then automate it |

Each wave ends with: `gsa -Ma` clean of new rows, `bash tests/run-all.sh` green,
`gsa -S --dry-run @core` resolving, and the renamed packages installed with the
old names gone from `pacman -Q`.

## 6 · Ripple, measured

| surface | size | how it is handled |
| --- | --- | --- |
| topology edge mentions of a candidate | **1906 across 557 of 665 rows** | rewritten by id; the loader validates the whole map, so a miss is an immediate rc 2 |
| topology rows that are themselves candidates | 113 | id + path |
| `pkgname` outputs | **130** | suffix on each |
| recipe-local `depends`/`provides` textual references | 100 tokens across the tree | unchanged — the provide keeps them resolvable |
| exact-version pins | **0** | nothing to fix |
| recipe fixtures naming a candidate | 11 ids in 7 files | update in the same wave |
| IgnorePkg closure | dynamic | `gsa -Mi --backfill` after each wave |
| binpkg index rows | keyed by recipe id | old rows become orphans; `-M` prune |
| `abi/subscriptions` (`:=`) records | name the provider id | stale records are skipped loudly (rule 68); re-bless via the wave |
| `world` / `sets/` | hold ids | `gsa -Mw`/`-Ms --remove old --add new` |
| docs citing an id | `AGENTS.md` §4/§5, `docs/JOURNAL.md` history (never rewritten) | §4/§5 updated where the rule names a recipe |

## 7 · Engine work (W5, must land last)

1. **`-Sy` snapshot provider** — a version-sync provider kind that resolves
   "last commit at or before the most recent Monday 00:00Z" for a recipe's own
   git URL and rewrites `#commit=`/`_commit` **and** `pkgver` in one anchored
   pass (rule 18: the anchor is the upstream commit itself, which is
   publisher-produced). Contract §B.11/§18 amendment + fixtures.
2. **Retire the 5-commit waiver for pinned families** — once a family is
   exact-pinned, `DEFAULT_VCS_SKIP_TOLERANCE` has nothing to waive; keep it only
   for recipes that still float (and after this programme, that is only
   `gsa-pm` and whatever the owner excludes).
3. **`pin-discipline` lint** (report-only, raised to a ratchet at the end of
   W1) — a floating VCS ref in `@core`/`@build-tools` becomes a finding, so the
   next recipe added cannot quietly reintroduce the class.

## 8 · Acceptance

Per wave: battery green, `gsa -Ma` with no new finding, the wave's packages
installed under their new names, and every old name still resolving through the
versioned provide (`pacman -Qi <old-name>` answers via the provider, and
`gsa -Qt` lists no id of the old form).

Whole programme: `gsa -Qt` shows `-snapshot` for every converted recipe,
`-git` names only where §2 excludes them; `gsa -Ma` clean; the
`pin-discipline` ratchet empty; `gsa -Sy` advancing the pins without a manual
edit.

## 9 · Risks and their detection

| risk | detection |
| --- | --- |
| a consumer rebuilds against a half-renamed tree | impossible inside a batch (one commit); between batches the provide keeps the name resolvable — `gsa -S --dry-run @core` after each wave |
| an exact-version pin appears later | the `pin-discipline` lint plus a battery case that greps for `name=` on a provided old name |
| the rename orphans a `:=` subscription | rule 68's loud `abi-stale-record` line; `gsa -Ma` |
| a `pkgver` normalization inverts | assert monotonicity against the previous archive's version in the wave's validation |
| the Monday anchor is unreachable (no mirror) | resolve from `SRCDEST`'s bare clone, never the network at edit time; a missing mirror defers the recipe rather than guessing |
