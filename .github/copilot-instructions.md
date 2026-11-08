# Copilot instructions — Gentoo_Style_Arch (recipe repository)

This repository's memory is **`AGENTS.md` at the repo root**. It is the single
source of truth: what the set is, the read-first map, commands, the recipe
rules (registration, ignore layers, provides discipline, the PGO gate,
trimming, source verification, the optimization playbook, ABI batches), the
pitfall digest and the queue. Read it first, then `docs/JOURNAL.md` for what
just changed.

Nothing is restated here on purpose. A rule, path or command copied into a
second file drifts in one of them.

The engine half — `gsa` itself, its contract and its operations guide — lives
in **`ZhangDM-520/gentoo-style-arch`** (`docs/gsa-contract.md` is the
authoritative interface there). Nothing about `crates/` is authoritative here,
and nothing about `packages/` or `config/` is authoritative there.

## Relationship to the host's global instruction

The host loads this file **before** its global agent instruction, so where the
two overlap the global rule is the baseline and `AGENTS.md` is the
repo-specific refinement. Two global rules arrive unchanged because this
repository has no variant of them: workspace isolation (canonical edits stay in
this repository, scratch goes elsewhere, and fixture scratch stays in the
harness's `$TMPDIR` trees) and the commit routine (never commit or push
unprompted — a green battery is evidence, not consent).

The shell-boundary hazard is the one place this repository adds a concrete
rule: the login shell is fish while tool-call shells are bash, so hand a fish
user `bash -c '…'`, and prefix bare-repo or makepkg VCS git commands with
`GIT_CONFIG_COUNT=0` because agent shells inject git config that breaks them.
`AGENTS.md` §7 states it in full.
