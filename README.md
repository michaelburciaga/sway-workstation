# Sway workstation

A portable Sway setup for Fedora, Ubuntu/Pop!_OS/Debian, Arch, openSUSE, Alpine, Void, and Gentoo.

## Install

```bash
git clone https://github.com/michaelburciaga/sway-workstation.git
cd sway-workstation
./bootstrap.sh
```

Run the installer as your normal user, not with `sudo`.

Useful options:

```bash
./bootstrap.sh --dry-run
./bootstrap.sh --config-only
```

After installation, log out and choose **Sway** from the login screen.

## Keybindings

| Keys | Action |
| --- | --- |
| `Super + Enter` | Open the system terminal |
| `Super + Space` | Open the app launcher |
| `Super + Q` | Close the active window |
| `Super + F` | Toggle fullscreen |
| `Super + Shift + T` | Toggle floating mode |
| `Super + 1–0` | Switch workspace |
| `Super + Shift + 1–0` | Move window to workspace |
| `Super + Arrow` or `Super + H/J/K/L` | Move focus |
| `Super + Shift + Arrow` or `Super + Shift + H/J/K/L` | Move window |
| `Super + Shift + R` | Resize mode |
| `Super + Shift + W` | Choose wallpaper and colors |
| `Super + X` | Open power menu |
| `Super + Alt + L` | Lock screen |
| `Super + Shift + C` | Reload Sway |
| `Print` | Screenshot current output |
| `Ctrl + Print` | Screenshot selected area |
| `Alt + Print` | Screenshot active window |

Monitor settings are stored in:

```text
~/.config/sway/outputs.conf
```

Wallpapers go in:

```text
~/Pictures/Wallpapers
```
