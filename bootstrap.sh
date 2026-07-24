#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

log() {
    printf '\n==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

[[ -r /etc/os-release ]] || die "Cannot identify this operating system"
# shellcheck disable=SC1091
source /etc/os-release
[[ ${ID:-} == fedora ]] || die "This installer supports Fedora; detected ${ID:-unknown}"
command -v sudo >/dev/null || die "sudo is required"
command -v dnf >/dev/null || die "dnf is required"

log "Refreshing sudo credentials"
sudo -v

log "Enabling repositories"
sudo install -Dm0644 "$repo_dir/repos/brave-browser.repo" /etc/yum.repos.d/brave-browser.repo
sudo install -Dm0644 "$repo_dir/repos/swayfx.repo" /etc/yum.repos.d/_copr:swayfx:swayfx.repo

# This repository supplies the multimedia packages used by the workstation.
fedora_release=$(rpm -E %fedora)
sudo dnf install -y "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_release}.noarch.rpm"

log "Installing Fedora packages"
mapfile -t packages < <(sed -E '/^[[:space:]]*(#|$)/d' "$repo_dir/packages-fedora.txt")
sudo dnf install -y --allowerasing "${packages[@]}"

log "Installing Spotify"
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
while IFS= read -r app_id; do
    [[ -z $app_id || $app_id == \#* ]] && continue
    flatpak install --user -y flathub "$app_id"
done < "$repo_dir/flatpaks.txt"

log "Installing Sway configuration"
install -d "$HOME/.config/sway" "$HOME/.config/waybar" \
    "$HOME/.config/wofi" "$HOME/.config/mako" "$HOME/.config/autostart" \
    "$HOME/.local/bin"

install -m0644 "$repo_dir/dotfiles/.config/sway/config" "$HOME/.config/sway/config"
install -m0644 "$repo_dir/dotfiles/.config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
install -m0644 "$repo_dir/dotfiles/.config/waybar/style.css" "$HOME/.config/waybar/style.css"
install -m0644 "$repo_dir/dotfiles/.config/wofi/style.css" "$HOME/.config/wofi/style.css"
install -m0644 "$repo_dir/dotfiles/.config/mako/config" "$HOME/.config/mako/config"
install -m0644 "$repo_dir/dotfiles/.config/autostart/blueman.desktop" "$HOME/.config/autostart/blueman.desktop"
install -m0755 "$repo_dir/dotfiles/.local/bin/sway-power-menu" "$HOME/.local/bin/sway-power-menu"

install -m0644 "$repo_dir/dotfiles/.config/sway/outputs.conf.example" "$HOME/.config/sway/outputs.conf.example"
if [[ ! -e $HOME/.config/sway/outputs.conf ]]; then
    install -m0644 "$repo_dir/dotfiles/.config/sway/outputs.conf.example" "$HOME/.config/sway/outputs.conf"
fi

if [[ -n ${SWAYSOCK:-} ]]; then
    log "Reloading the active Sway session"
    swaymsg reload
else
    log "Sway syntax will be checked when the session starts"
fi

log "Setup complete"
printf '%s\n' \
    "Log out, choose Sway from the login screen, and sign in." \
    "For monitor tuning, copy ~/.config/sway/outputs.conf.example to outputs.conf and edit it." \
    "To connect GitHub, run: gh auth login"
