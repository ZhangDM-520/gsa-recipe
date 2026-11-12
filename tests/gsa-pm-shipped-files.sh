#!/usr/bin/env bash
set -euo pipefail

# gsa-pm ships EVERY text-producing engine seam, and ships it fresh.
#
# The defect this closes: `--print-conf` and `--print-completion` are
# one-source-of-truth seams — the engine prints the file, so the shipped file
# can never drift from the binary. But printing is not shipping. `package()`
# invoked `--print-conf` and never `--print-completion`, so the completion
# wrapper existed, the engine fixture pinned its text, the contract row said
# "gsa-pm installs it" — and no shell had a completion file. Every `gsa <TAB>`
# fell back to filename completion. The seam was correct in both repositories
# and nothing was on disk.
#
# A single-file assertion would repeat that mistake one seam later, so this
# fixture pins the RELATIONSHIP instead:
#
#   1. every `--print-*` seam named in the PKGBUILD must be a known seam
#      (the roster below) — a new seam forces a row here rather than shipping
#      silently;
#   2. every rostered seam must be INVOKED by package(), so a dropped
#      invocation fails even though the file list still looks complete;
#   3. every installed file must EQUAL the live engine's output for that seam,
#      which kills a hand-copied file that has drifted from the binary.
#
# (3) is why this runs the real engine and the real package(): a stub would
# prove the plumbing and nothing about the text. The engine under test is the
# INSTALLED binary (contract §L.10), like every other fixture here.
#
# Red-verified: dropping the `--print-completion` loop, dropping one installed
# shell's `install` line, editing one installed byte, and introducing an
# unknown `--print-future` seam each fail naming what broke.

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
recipe="$root/packages/core/gsa-pm/PKGBUILD"

fail() {
    printf 'gsa-pm shipped-files fixture: %s\n' "$1" >&2
    exit 1
}

[[ -f $recipe ]] || fail "missing $recipe"

# The roster: seam invocation -> the path package() must install it at.
# Adding a text seam to the engine means adding a row here; the "unknown seam"
# check below enforces that a PKGBUILD edit cannot slip one in unlisted.
seams=(
    '--print-conf gcc|etc/gsa/gcc-makepkg.conf'
    '--print-conf clang|etc/gsa/clang-makepkg.conf'
    '--print-completion fish|usr/share/fish/vendor_completions.d/gsa.fish'
    '--print-completion bash|usr/share/bash-completion/completions/gsa'
    '--print-completion zsh|usr/share/zsh/site-functions/_gsa'
)

# --- 1. no unrostered --print-* seam ---------------------------------------
mapfile -t named < <(grep -oE -- '--print-[a-z-]+' "$recipe" | sort -u)
rostered=$(printf '%s\n' "${seams[@]}" | cut -d' ' -f1 | sort -u)
for seam in "${named[@]}"; do
    grep -qx -- "$seam" <<<"$rostered" ||
        fail "PKGBUILD uses '$seam', which is not in this fixture's roster — add the seam -> install path row, then make package() ship it"
done
for seam in "${rostered[@]}"; do
    grep -qx -- "$seam" <<<"$(printf '%s\n' "${named[@]}")" ||
        fail "this fixture expects '$seam' but the PKGBUILD no longer uses it — drop the row or restore the invocation"
done

# --- 2. the engine under test (contract §L.10) -----------------------------
if [ -z "${GSA_TEST_GSA_BIN:-}" ]; then
    GSA_TEST_GSA_BIN=$(command -v gsa) || {
        printf 'contract §L.10: no installed gsa on PATH — install gsa-pm, or set GSA_TEST_GSA_BIN explicitly\n' >&2
        exit 1
    }
fi
[ -x "$GSA_TEST_GSA_BIN" ] || fail "the engine under test is not executable: $GSA_TEST_GSA_BIN"
export GSA_TEST_GSA_BIN

# --- 2b. the roster is closed against the ENGINE, not just the PKGBUILD ----
# Check 1 closes the roster against what package() happens to mention. That
# still passes when the ENGINE grows a text seam gsa-pm never invokes — the
# original defect, one release later. `--seam-roster` publishes the engine's
# own list of text-producing seams so the two rosters can be diffed.
if engine_seams=$("$GSA_TEST_GSA_BIN" --seam-roster 2>/dev/null); then
    while IFS= read -r seam; do
        [[ -n $seam ]] || continue
        grep -qx -- "$seam" <<<"$rostered" ||
            fail "the ENGINE publishes the text seam '$seam' but gsa-pm does not package it — add the seam -> install path row and an install line (ADR 0006)"
    done <<<"$engine_seams"
else
    # An engine predating `--seam-roster` cannot answer; say so loudly rather
    # than passing vacuously, because that engine may also predate a seam.
    printf 'gsa-pm shipped-files fixture: SKIP the engine-roster diff — %s does not answer --seam-roster (engine older than the seam it should ship)\n' \
        "$GSA_TEST_GSA_BIN" >&2
fi

tmp=$(mktemp -d "${TMPDIR:-/tmp}/gsa-pm-shipped.XXXXXX")
trap 'command rm -rf -- "$tmp"' EXIT

# --- a source tree shaped like the fetched checkout ------------------------
# package() cds into `gentoo-style-arch` and reads exactly these paths. The
# engine is the real one under test, so (3) compares bytes, not a marker.
src="$tmp/gentoo-style-arch"
mkdir -p "$src/target/release" "$src/tools"
ln -s "$GSA_TEST_GSA_BIN" "$src/target/release/gsa"
printf 'fixture license\n' >"$src/LICENSE"
for asset in abi-need-check.sh abi-need-check.hook; do
    : >"$src/tools/$asset"
done

# --- 3. run the recipe's own package() ------------------------------------
# makepkg runs every phase with cwd = $srcdir, and package() cds from there.
pkgdir="$tmp/pkg"
mkdir -p "$pkgdir"
(
    set -e
    cd "$tmp"
    # shellcheck disable=SC1090
    source "$recipe" >/dev/null 2>&1
    startdir="$root/packages/core/gsa-pm"
    srcdir="$tmp"
    pkgdir="$pkgdir"
    package
) || fail 'package() failed'

# --- 4. every seam is invoked AND its output is installed, byte-identical --
for row in "${seams[@]}"; do
    invocation=${row%%|*}
    path=${row##*|}
    file="$pkgdir/$path"
    [[ -f $file ]] || fail "package() does not install $path (seam: $invocation)"
    [[ -s $file ]] || fail "package() installed an EMPTY $path (seam: $invocation)"

    # shellcheck disable=SC2086
    "$GSA_TEST_GSA_BIN" $invocation >"$tmp/expected" 2>/dev/null ||
        fail "the engine refuses the shipped seam '$invocation'"
    # No `diff | head`: under pipefail the early-closing head SIGPIPEs diff and
    # `set -e` then kills the fixture silently — the failure must NAME itself.
    if ! cmp -s "$tmp/expected" "$file"; then
        printf 'expected (%s):\n' "$invocation" >&2
        sed -n '1,10p' "$tmp/expected" >&2
        printf 'installed (%s):\n' "$file" >&2
        sed -n '1,10p' "$file" >&2
        fail "$path differs from '$invocation' output — a hand-copied file that drifted from the binary"
    fi
done

# --- 4b. the Rust link must not inherit -flto from the host CFLAGS ---------
# Cargo's link step never receives -flto, so a C dependency compiled with it
# emits LTO objects the linker cannot resolve. Measured 2026-11-12: gsa-pm died
# at link with nine undefined ZSTD_* symbols under makepkg's
# CFLAGS="-flto=auto" while an identical plain `cargo build` linked clean.
# The engine owns its own makepkg configuration (engine ADR 0005), so the host
# CFLAGS are not gsa's to inherit on the Rust link.
build_body=$(sed -n '/^build()/,/^}/p' "$recipe")
grep -q 'CFLAGS="\${CFLAGS//-flto=auto/}"' <<<"$build_body" ||
    fail 'build() does not strip -flto=auto from CFLAGS: the Rust link will fail with undefined ZSTD_* symbols when the host enables LTO (measured 2026-11-12)'

# --- 5. the paths are the ones the shells actually search ------------------
# A file installed somewhere a shell never reads is the same bug with extra
# steps, so name the search roots the contract promises.
grep -qF '$pkgdir/usr/share/fish/vendor_completions.d/gsa.fish' "$recipe" ||
    fail 'the fish completion is not installed under /usr/share/fish/vendor_completions.d'
grep -qF '$pkgdir/usr/share/bash-completion/completions/gsa' "$recipe" ||
    fail 'the bash completion is not installed under /usr/share/bash-completion/completions'
grep -qF '$pkgdir/usr/share/zsh/site-functions/_gsa' "$recipe" ||
    fail 'the zsh completion is not installed under /usr/share/zsh/site-functions'

printf 'gsa-pm shipped-files fixture: PASS (%d seams)\n' "${#seams[@]}"
