#!/usr/bin/env bash
set -euo pipefail

# tests/memory-layout.sh — the retired-notes layout gate.
#
# Agent bookkeeping was retired from this repository on 2026-11-17: the
# chronological journal, the rules/pitfalls/queue bodies, the live snapshot and
# the per-action exports all moved to the maintainer's private warehouse. What
# stays public is one contract file, `AGENTS.md`, plus the design docs under
# `docs/`. The history did not stop existing — it stopped being a tracked tree.
#
# So the layout is enforced by INVERSION: the retired paths must be ABSENT and
# `AGENTS.md` must be PRESENT. A silent regression here is a reader following a
# dead pointer — a re-created journal, an ignore rule that lets a scratch buffer
# back into history, a comment citing a file that no longer exists. Each of
# those has to go red in the battery instead of being found later by somebody
# who trusted the map.
#
# The assertions are on the CONTRACT — existence and absence — never on prose
# wording, so the documents stay free to be rewritten while the layout holds.
# Nothing here names a host path or a machine-local note: the check runs in
# public CI and must be true of the checkout alone.
#
# `tests/assets/**` is excluded from the citation scan because it is the frozen
# differential oracle (the retired fish engine), not live documentation: those
# files keep their pre-retirement text verbatim. `*.patch` files are upstream
# payloads applied verbatim, so the paths inside them belong to the upstream
# project rather than to this repository's notes. This fixture names the paths
# it forbids in its prose and its messages, so it excludes itself — section 1
# is what catches a re-created file.
#
# Read-only and therefore parallel-safe: every check is `git grep`, `wc -l` or
# `[[ -e ]]`. Nothing is written, no $TMPDIR workspace is synthesized and no
# trap is needed, so the fixture can run beside every other battery member.

source "$(dirname "${BASH_SOURCE[0]}")/lib/fixture-lib.bash"

root=$gsa_repo_root

fail() {
    printf 'memory-layout fixture: %s\n' "$1" >&2
    exit 1
}

# ─── 1. The retired paths are absent ──────────────────────────────────────
# A re-created file is a second source of truth and would silently diverge from
# the copy that is actually read.
retired=(
    .logs
    docs/JOURNAL.md
    docs/journals
    docs/plans
    docs/reviews
    docs/researchs
    docs/pitfalls.md
    docs/rules.md
    docs/queue.md
    scratchpad.md
    MEMORY.md
    NOTE.md
    CURRENT.md
)
for f in "${retired[@]}"; do
    if [[ -e $root/$f ]]; then
        fail "$f belongs to the private warehouse as of 2026-11-17 — the public record is AGENTS.md plus docs/; delete it rather than restoring a second source of truth"
    fi
done

# ─── 2. The convention file is present ────────────────────────────────────
# Existence alone would pass on a truncated file, so the contract file also
# clears a floor: a stub that lost its body must fail loudly, not silently.
[[ -f $root/AGENTS.md ]] ||
    fail "missing the operational contract file: AGENTS.md"
lines=$(wc -l <"$root/AGENTS.md")
((lines >= 100)) ||
    fail "AGENTS.md is a stub: $lines line(s), want at least 100 (contract truncated?)"

# ─── 3. No live citation of a retired path ────────────────────────────────
# A kept file may still say where the records went — the private warehouse —
# but a citation of a specific retired file points a reader at something that
# does not exist. AGENTS.md is excluded because the contract narrates the
# retirement itself, and this fixture is excluded because it names what it
# forbids.
if out=$(git -C "$root" grep -n -E \
    'docs/JOURNAL\.md|docs/(journals|plans|reviews|researchs)/|(^|[^/[:alnum:]_.-])(MEMORY|NOTE|CURRENT|scratchpad)\.md|(^|[^/[:alnum:]_.-])\.logs(/|$|[^-])|docs/(pitfalls|rules|queue)\.md' \
    -- . ':!tests/assets' ':!AGENTS.md' ':!*.patch' ':!tests/memory-layout.sh' 2>/dev/null); then
    hits=$(printf '%s\n' "$out" | head -5)
    fail "live citation of a retired path — the agent bookkeeping lives in the maintainer's private warehouse; describe it that way instead of naming a dead file; offending hits:
$hits"
fi

printf 'memory-layout fixture: PASS (retired paths absent, AGENTS.md present, no live retired citations)\n'
