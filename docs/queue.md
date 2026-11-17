---
permalink: gsa-recipe/docs/queue
title: queue
type: note
---

# gsa-recipe Active Queue

Detailed backlog items indexed in [AGENTS.md](../AGENTS.md) § Queued. Delete finished items rather than ticking them.

## High-Priority Campaigns & Topology Debt

- **Snapshot-pin waves (W1 pinned 2026-11-09; W2–W4 queued for owner weekend build)**: W1 (64 fan-out <= 4 trackers) pinned to `<= Monday 2026-11-09 00:00Z` with regenerated `.SRCINFO`; **nothing built/installed yet** (discarded validation archives are stale). Next: build+install W1, then pin/verify W2 (59), W3 (5), W4 (8 incl. `git-git`, `icu-git`). Engine W0/W5 landed (`docs/snapshot-expansion.md` §8; note `libidn2-git` gnulib URL, `libmypaint-git` `gegl.pc`).
- **Flag-revision validation rebuild (2026-11-03)**: T1–T3 appends across 133 recipes still await ~2-week owner rebuild (`libldacdec` `-O3 -march=native` pending).
- **Topology missing-prereq edges (2026-11-01)**: ~1,825 gap pairs in `config/topology.conf`; add one verified build-order edge at a time. Verify/drop 3 unverified edges (`fluidsynth-git -> libsndfile-git/readline-git`, `gdb -> zlib-ng-compat-git`).
- **Versioned-provides epoch under-claim & warm-`$srcdir` `prepare()` sweep (2026-11-01)**: 15+ epoch recipes need `${epoch}` in `provides` (requires real rebuilds); remaining tarball recipes need idempotent `ln`/`cp`/`patch` guards.
- **LLVM-ABI consumers outside tags & `icu-git` skew (2026-11-14)**: Add `abi=should` + edges (or document safe) for `postgresql-libs` and `linux-tools`. `icu-git` (`libicuuc.so.80` vs distro `78.3`) affects `nuspell`, `vte3` (recipes added, awaiting build), and stock `qt6-webengine` (`abi-exclusions.conf`)—decide long-term alignment before next `-Syu`.

## Package-Specific Decisions & Parks

- **Queued `validpgpkeys` fixes**: `nautilus`, `gobject-introspection`, `bind`, `fish` (confirm publisher keys).
- **`sqlite` doc-zip checksum mismatch**: Drop `sqlite-doc-*` or verify artifact at 3.54.0 bump.
- **ROCm / `dbus-broker` / `doxygen-git` / `libadwaita-git` / `linux-firmware` / `systemd`**: Rebuild `hip-runtime` with `hsa-rocr`/`rocm-llvm`/`comgr` or prune; choose between `stable/dbus-broker` and `git/dbus-broker-git`; confirm `doxygen-git` purge; keep or drop `libadwaita-git` `check()`/`weston`; re-specify `linux-firmware` deferred `rm`; schedule `systemd` changes as their own coupled pass.
- **Kernel & PGO (`linux-cachyos`)**: CVE-2026-90432 RC-channel move unverified beyond runtime `uname -r`; decide whether to ship AutoFDO+Propeller profiles at next rebuild.
- **Backlog & verification debts**: `ghostscript`/`tesseract` (drop if print/OCR gap unneeded); `keys/*.asc` gitignore policy; `gst-libav` `gst-ffmpeg=$pkgver` alignment; `gnulib` 7-recipe unpinned HEAD caveat; `spandsp` FreeSWITCH fork owner sign-off; stale `.SRCINFO` on `hermes-agent-git` and `zen-browser-pgo`.
- **Parked packages**: `libdisplay-info-git` (`0.3.0`, heal with wlroots 0.20 or stay parked); `libpng-git` (`#branch=libpng16`, `.so.18` batch); `libseccomp-git` (`#branch=release-2.6`); `libgit2-git` (`#tag=v1.9.7`).
- **`llvm-git <-> rust-git` procedure**: Automate manual sweep -> stage `llvm-git` -> bootstrap `rust-git` -> atomic `pacman -U`.
