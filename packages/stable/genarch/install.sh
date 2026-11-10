#!/usr/bin/env bash
# genarch — general installer (no pacman).
#
# Installs the engine, its intent and its documentation from a source tree or from a tagged
# release tarball. Use this on a host that is not on Arch, or when you want the binary outside
# the package manager; on Arch the PKGBUILD beside this file is the supported path.
#
# The engine reads its intent from $INTENT_DIR (default /usr/lib/genarch). A non-default
# directory only takes effect at run time through GENARCH_INTENT.
set -euo pipefail

REPO="https://github.com/ZhangDM-520/genarch-settings"
VERSION="0.1.1"
PREFIX="/usr"
# Fixed, not derived from --prefix: the engine resolves /usr/lib/genarch itself; a relocated
# intent is a run-time `GENARCH_INTENT` override, not an install layout.
INTENT_DIR="/usr/lib/genarch"
DOC_DIR=""
SOURCE=""
ENABLE=1
DRY=0
TMP=""

usage() {
  cat <<'USAGE'
usage: install.sh [options]

  --source DIR      build from DIR instead of downloading the tagged tarball
  --version VER     release to download (default: the version this script shipped with)
  --prefix PATH     where the binary goes (default /usr)
  --intent-dir DIR  where the intent goes (default /usr/lib/genarch)
  --doc-dir DIR     where the documentation goes (default <prefix>/share/doc/genarch)
  --no-units        install files only: no apply, no daemon-reload, no enable
  --dry-run         print every action; change nothing
  -h, --help        this text

The engine is idempotent: installing over an existing one re-plans and converges, it does not
reset anything.  Uninstall: disable genarch.service genarch-ceil.timer, remove the binary, the
intent directory and the documentation, then run `systemctl daemon-reload`.
USAGE
}

say() { printf 'genarch-install: %s\n' "$*"; }
die() { printf 'genarch-install: %s\n' "$*" >&2; exit 1; }
# `run` is the only place a mutation happens, so --dry-run is a property of the script rather
# than something every call site has to remember.
run() {
  if (( DRY )); then
    printf 'DRY-RUN'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

while (( $# )); do
  case "$1" in
    --source)     SOURCE="${2:?--source needs a directory}"; shift 2 ;;
    --version)    VERSION="${2:?--version needs a value}"; shift 2 ;;
    --prefix)     PREFIX="${2:?--prefix needs a path}"; shift 2 ;;
    --intent-dir) INTENT_DIR="${2:?--intent-dir needs a path}"; shift 2 ;;
    --doc-dir)    DOC_DIR="${2:?--doc-dir needs a path}"; shift 2 ;;
    --no-units)   ENABLE=0; shift ;;
    --dry-run)    DRY=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            printf 'genarch-install: unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

(( EUID == 0 )) || (( DRY )) || die "must run as root (or pass --dry-run to preview)"
[[ -n $DOC_DIR ]] || DOC_DIR="$PREFIX/share/doc/genarch"

if [[ -z $SOURCE ]]; then
  if [[ -f ./Cargo.toml ]] && grep -q '^name = "genarch"' ./Cargo.toml; then
    SOURCE="$PWD"
    say "building the checkout at $SOURCE"
  else
    command -v curl >/dev/null 2>&1 || die "curl is required to fetch the release tarball"
    command -v tar  >/dev/null 2>&1 || die "tar is required to unpack the release tarball"
    TMP="$(mktemp -d)"
    trap 'rm -rf "$TMP"' EXIT
    url="$REPO/archive/v$VERSION.tar.gz"
    say "fetching $url"
    # Download and unpack are temp-only, so they run for real even under --dry-run: the
    # source resolution has to be verifiable before the preview claims anything.
    curl -fsSL "$url" -o "$TMP/genarch.tar.gz"
    tar -xzf "$TMP/genarch.tar.gz" -C "$TMP"
    SOURCE="$TMP/genarch-settings-$VERSION"
  fi
fi

[[ -f "$SOURCE/Cargo.toml" ]] || die "no Cargo.toml under $SOURCE"
grep -q '^name = "genarch"' "$SOURCE/Cargo.toml" || die "$SOURCE is not the genarch tree"

# Build inputs. A missing runtime dependency is reported, never fatal: the report marks the
# rows it cannot judge as SKIPPED, and an install that refuses to proceed over a missing
# `ryzenadj` would be unable to fix anything.
command -v cargo >/dev/null 2>&1 || die "cargo is required to build (install the rust toolchain)"
for dep in ryzenadj iw systemctl udevadm sudo; do
  command -v "$dep" >/dev/null 2>&1 \
    || say "warning: $dep not found — dependent rows will be SKIPPED or inert"
done

say "building (release, locked)"
run cargo build --release --locked --manifest-path "$SOURCE/Cargo.toml"
BIN="$SOURCE/target/release/genarch"
[[ -x $BIN ]] || die "the build produced no binary at $BIN"

say "installing the binary to $PREFIX/bin"
run install -d "$PREFIX/bin"
run install -Dm755 "$BIN" "$PREFIX/bin/genarch"

say "installing the intent to $INTENT_DIR"
run install -d "$INTENT_DIR"
for file in intent.toml sysctl.toml ryzenadj.toml passes.toml; do
  run install -Dm644 "$SOURCE/intent/$file" "$INTENT_DIR/$file"
done
for dir in managed mirror; do
  run rm -rf "$INTENT_DIR/$dir"
  run cp -a "$SOURCE/intent/$dir" "$INTENT_DIR/$dir"
done

say "installing documentation to $DOC_DIR"
run install -Dm644 "$SOURCE/AGENTS.md" "$DOC_DIR/AGENTS.md"
run install -Dm644 "$SOURCE/CONTEXT.md" "$DOC_DIR/CONTEXT.md"
run install -Dm644 "$SOURCE/docs/DESIGN.md" "$DOC_DIR/DESIGN.md"
run install -Dm755 -- "$0" "$DOC_DIR/install.sh"

if (( ENABLE )); then
  say "converging the host to the intent"
  run "$PREFIX/bin/genarch" apply --dry-run
  run "$PREFIX/bin/genarch" apply
  run systemctl daemon-reload
  run udevadm control --reload
  run systemctl enable --now genarch.service genarch-ceil.timer
fi

say "done — read-only check: $PREFIX/bin/genarch report"
(( DRY )) || "$PREFIX/bin/genarch" report || true
