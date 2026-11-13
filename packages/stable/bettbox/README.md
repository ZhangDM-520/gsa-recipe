# bettbox

Bettbox is a cross-platform proxy client built on the Mihomo (Clash Meta) core, refactored from an early version of FlClash.

Arch Linux AUR package based on [appshubcc/Bettbox](https://github.com/appshubcc/Bettbox), built from source.

## Installation

```sh
# Manual build
makepkg -si

# Or via an AUR helper
paru -S bettbox-compatible
```

## Updating pkgver

The repository includes an `update-pkgver.sh` script and [nvchecker](https://github.com/archlinux/nvchecker) config. Run inside the package directory:

```sh
./update-pkgver.sh
```

The script checks for the latest version via nvchecker (stable or pre-release, whichever is newer; `-test` tags are excluded). If a new version is found, it updates `pkgver`, resets `pkgrel=1`, refreshes checksums (`updpkgsums`), rebuilds `.SRCINFO`, and prints `git diff`. Requires `nvchecker makepkg updpkgsums jq` (`nvchecker` and `jq` installed).

To check without modifying files:

```sh
nvchecker -c .nvchecker.toml
```

`.nvchecker.toml` restricts tags to stable + pre-release and outputs in `pkgver` format:

```
bettbox-compatible: updated to 1.18.9pre1
```

> Note: Submit stable versions to the AUR; pre-releases are for local build testing only.
