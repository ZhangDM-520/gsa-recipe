# Scratchpad

**Idle.** No active task.

Last action: `.logs/action-2026-11-14-abi-gate-icu-wiring.md`
(the pacman reinstall's ABI-gate abort — icu-git blamed and confirmed by
`gsa -Qr`; nuspell + vte3 now house recipes wired to icu-git, nine reviewed
gaps + the `qt6-webengine` package-id row in `config/abi-exclusions.conf`).

Next: nothing is committed. Activation is commit+push → `sudo gsa -Sy` (the
hook reads the store copy) → `sudo gsa -S --leaf nuspell vte3`. The icu
generation decision for qt6-webengine is queued in AGENTS.md §6.
