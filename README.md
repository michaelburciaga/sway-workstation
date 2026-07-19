# Fedora Sway workstation

This repository recreates Michael's Fedora 44 SwayFX desktop: packages,
Flatpak apps, Sway/Waybar/Wofi/Mako configuration, the power menu, fonts, and
wallpaper.

It intentionally excludes passwords, browser profiles, SSH keys, GitHub
credentials, Wi-Fi connections, caches, hostnames, and hardware drivers.
Monitor settings are kept local because connector names and supported refresh
rates differ between computers.

## Install on another Fedora computer

```bash
sudo dnf install -y git
git clone https://github.com/michaelburciaga/sway-workstation.git
cd sway-workstation
./bootstrap.sh
```

The script is idempotent: it can be run again to update packages and restore
the tracked configuration. It targets Fedora and installs current compatible
package versions rather than freezing packages to versions from the original
machine.

After installation, log out and select **Sway** in the login screen. For a
custom display mode:

```bash
cp ~/.config/sway/outputs.conf.example ~/.config/sway/outputs.conf
swaymsg -t get_outputs
```

Edit `outputs.conf`, then reload Sway with `Super+Shift+C`.

## Publish this repository to GitHub

Install and authenticate GitHub CLI, then create the private repository:

```bash
sudo dnf install -y gh
gh auth login
cd ~/sway-workstation
git config user.name "YOUR NAME"
git config user.email "YOUR GITHUB EMAIL"
git add .
git commit -m "Add reproducible Fedora Sway workstation setup"
gh repo create sway-workstation --private --source=. --remote=origin --push
```

Private is the safer initial visibility. The tracked files contain no known
credentials, so the repository can be made public later if desired.

## What is captured

- `packages-fedora.txt`: Sway and the explicitly installed workstation apps
- `flatpaks.txt`: the current Flathub application IDs
- `dotfiles/`: Sway, Waybar, Wofi, Mako, autostart, and power-menu files
- `assets/wallpaper.jpg`: the desktop wallpaper
- `repos/`: repository definitions needed by Brave and SwayFX

GNOME's Fedora defaults remain available, but the installer does not attempt to
clone the entire RPM database. Doing so would copy base-image and
hardware-specific packages that are inappropriate on another computer.

In particular, NVIDIA/AMD driver choices, monitor connector names, Wi-Fi
profiles, and Secure Boot enrollment must be handled on each computer.
