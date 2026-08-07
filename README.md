# Portable Sway workstation

This repository installs Michael's Sway configuration, wallpaper picker, and
wallpaper-driven color theme without installing a bundle of personal apps.
The installer uses a small distro-specific package manifest and otherwise
keeps the same configuration on every supported system.

## Supported systems

| Package family | Distributions and derivatives |
| --- | --- |
| DNF | Fedora, Nobara, and Fedora-like systems |
| APT | Ubuntu, Pop!_OS, Linux Mint, Debian, and their derivatives |
| Pacman | Arch Linux, EndeavourOS, Manjaro, CachyOS, and derivatives |
| Zypper | openSUSE Tumbleweed and Leap |
| APK | Alpine Linux |
| XBPS | Void Linux |
| Portage | Gentoo Linux |

Detection uses `ID` and `ID_LIKE` from `/etc/os-release`. When a derivative is
unknown, the installer also recognizes the package manager. NixOS and other
declarative or unusual systems can use `--config-only` after the dependencies
have been installed through their native configuration.

Stock Sway is the portable default. If SwayFX is already installed,
`bootstrap.sh` detects it and keeps the blur/opacity profile. No third-party
package repository is enabled.

## Install

Install Git with the system package manager, then run:

```bash
git clone https://github.com/michaelburciaga/sway-workstation.git
cd sway-workstation
./bootstrap.sh
```

Run the script as your normal user, not with `sudo`; it requests elevated
access only while installing system packages. Existing managed configuration
is copied to `~/.local/state/sway-workstation/backups/` before replacement.
Monitor and wallpaper selections are preserved on repeated runs.

Useful modes:

```bash
# Preview every action
./bootstrap.sh --dry-run

# Copy configs only (also works on an unrecognized distribution)
./bootstrap.sh --config-only

# Force stock Sway or SwayFX configuration
SWAY_PROFILE=sway ./bootstrap.sh
SWAY_PROFILE=swayfx ./bootstrap.sh
```

If the system has a display manager, log out and choose **Sway**. On a minimal
installation without one, log in on a TTY and run `sway`.

## What is installed

Only software used by this desktop is in the package manifests:

- Sway, SwayBG, SwayIdle, SwayLock, Waybar, Wofi, Foot, and Mako
- Grim, Slurp, ImageMagick, `jq`, and notification support
- PipeWire/WirePlumber, media-key and brightness helpers
- XDG portals, user-directory support, a PolicyKit agent, and required fonts

The installer deliberately does **not** install browsers, Spotify, VLC,
Flatpak apps, FFmpeg, GitHub CLI, Go, GPU utilities, or icon themes.

## Wallpaper and automatic colors

Put images in `~/Pictures/Wallpapers` and press **Super+Shift+W**. The Wofi
picker caches previews, applies the selected wallpaper, and generates a shared
dark palette for:

- Sway window borders
- Waybar
- Wofi
- Mako notifications
- Foot terminal windows opened afterward
- GTK 3 and GTK 4 applications that honor user CSS

The generator only uses ImageMagick, which the wallpaper picker already needs;
it has no architecture-specific downloaded binary. Wallpaper paths containing
spaces and quotes are safely written to Sway's configuration.

Monitor settings are in `~/.config/sway/outputs.conf`. The installer creates it
from `outputs.conf.example` only when it does not exist.

## Key bindings

| Binding | Action |
| --- | --- |
| `Super+Return` | Foot terminal |
| `Super+Space` | Wofi application launcher |
| `Super+Shift+W` | Wallpaper and theme picker |
| `Super+X` | Portable power menu |
| `Print` | Screenshot focused output |
| `Ctrl+Print` | Screenshot selected area |
| `Alt+Print` | Screenshot focused window |

## Validate changes

The tests never install packages:

```bash
tests/bootstrap-dry-run.sh
tests/theme-generator.sh
```
