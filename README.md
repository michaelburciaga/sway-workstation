# Portable Sway workstation

This repository installs a complete Sway desktop and Michael's shared
configuration on the major Linux distribution families.

## Supported distributions

| Distribution family | Tested detection examples | Compositor |
| --- | --- | --- |
| Fedora | Fedora | SwayFX |
| Debian | Ubuntu 24.04+, Debian 13+, Linux Mint, Pop!_OS | Stock Sway |
| Arch | Arch Linux, EndeavourOS, Manjaro, CachyOS | Stock Sway |
| openSUSE | openSUSE Tumbleweed | Stock Sway |

Derivatives are detected through the `ID_LIKE` field in `/etc/os-release`.
Package availability can vary on older releases, so a current supported release
is recommended.

## Install

Start by installing Git on the new machine:

```bash
# Fedora
sudo dnf install -y git

# Ubuntu or Debian
sudo apt update && sudo apt install -y git

# Arch Linux or an Arch derivative
sudo pacman -Syu --needed git

# openSUSE Tumbleweed
sudo zypper install -y git
```

Then clone and run the installer:

```bash
git clone https://github.com/michaelburciaga/sway-workstation.git
cd sway-workstation
./bootstrap.sh
```

The installer detects the distribution, installs the matching package manifest,
sets up Flatpak applications, selects compatible Sway appearance rules, and
copies the configuration. Existing monitor and wallpaper choices are preserved.

To preview the commands without changing the machine, run:

```bash
DRY_RUN=1 ./bootstrap.sh
```

When installation finishes, log out and select **Sway** from the login screen.

## Shortcuts and local settings

Put wallpaper images in `~/Pictures/Wallpapers`, then press **Super+Shift+W**
to choose one from the cached thumbnail picker. The selection persists across
Sway reloads and future logins.

Monitor settings live in `~/.config/sway/outputs.conf`. The installer creates
that file from `outputs.conf.example` only when it does not already exist.
