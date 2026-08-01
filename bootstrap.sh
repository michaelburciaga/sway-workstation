#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dry_run=${DRY_RUN:-0}
os_release_file=${OS_RELEASE_FILE:-/etc/os-release}

log() {
    printf '\n==> %s\n' "$*"
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

run() {
    if [[ $dry_run == 1 ]]; then
        printf '  '
        printf '%q ' "$@"
        printf '\n'
    else
        "$@"
    fi
}

require_command() {
    command -v "$1" >/dev/null || die "$1 is required"
}

load_packages() {
    local manifest=$1
    mapfile -t packages < <(sed -E '/^[[:space:]]*(#|$)/d' "$repo_dir/$manifest")
}

[[ -r $os_release_file ]] || die "Cannot identify this operating system"
# shellcheck disable=SC1090
source "$os_release_file"

distro_id=${ID:-unknown}
distro_ids=" ${distro_id,,} ${ID_LIKE:-} "
distro_ids=${distro_ids,,}

case "$distro_ids" in
    *" fedora "*)
        distro_family=fedora
        package_manager=dnf
        package_manifest="packages-fedora.txt"
        compositor_profile=swayfx
        ;;
    *" debian "*|*" ubuntu "*)
        distro_family=debian
        package_manager=apt-get
        package_manifest="packages-debian.txt"
        compositor_profile=sway
        ;;
    *" arch "*)
        distro_family=arch
        package_manager=pacman
        package_manifest="packages-arch.txt"
        compositor_profile=sway
        ;;
    *" opensuse "*|*" opensuse-tumbleweed "*|*" suse "*)
        distro_family=opensuse
        package_manager=zypper
        package_manifest="packages-opensuse.txt"
        compositor_profile=sway
        ;;
    *)
        die "Unsupported distribution '${distro_id}'. Supported families: Fedora, Debian/Ubuntu, Arch, and openSUSE"
        ;;
esac

if ((EUID == 0)); then
    sudo_command=()
else
    sudo_command=(sudo)
fi

if [[ $dry_run != 1 ]]; then
    ((${#sudo_command[@]} == 0)) || require_command sudo
    require_command "$package_manager"
fi

log "Detected ${PRETTY_NAME:-$distro_id} (${distro_family} family)"
if [[ $dry_run == 1 ]]; then
    log "Dry run: commands will be printed but not executed"
fi

if ((${#sudo_command[@]} > 0)); then
    log "Refreshing sudo credentials"
    run "${sudo_command[@]}" -v
fi

load_packages "$package_manifest"

case "$distro_family" in
    fedora)
        log "Enabling Fedora repositories"
        run "${sudo_command[@]}" install -Dm0644 \
            "$repo_dir/repos/brave-browser.repo" \
            /etc/yum.repos.d/brave-browser.repo
        run "${sudo_command[@]}" install -Dm0644 \
            "$repo_dir/repos/swayfx.repo" \
            /etc/yum.repos.d/_copr:swayfx:swayfx.repo

        fedora_release=${VERSION_ID%%.*}
        if [[ $dry_run != 1 ]]; then
            fedora_release=$(rpm -E %fedora)
        fi
        run "${sudo_command[@]}" dnf install -y \
            "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${fedora_release}.noarch.rpm"

        log "Installing Fedora packages"
        run "${sudo_command[@]}" dnf install -y --allowerasing "${packages[@]}"
        ;;
    debian)
        log "Refreshing APT package metadata"
        run "${sudo_command[@]}" apt-get update

        if [[ ${distro_id,,} == ubuntu ]]; then
            log "Enabling Ubuntu's Universe repository"
            run "${sudo_command[@]}" env DEBIAN_FRONTEND=noninteractive \
                apt-get install -y software-properties-common
            run "${sudo_command[@]}" add-apt-repository -y universe
            run "${sudo_command[@]}" apt-get update
        fi

        log "Installing Debian/Ubuntu packages"
        run "${sudo_command[@]}" env DEBIAN_FRONTEND=noninteractive \
            apt-get install -y "${packages[@]}"
        ;;
    arch)
        log "Installing Arch packages"
        run "${sudo_command[@]}" pacman -Syu --needed --noconfirm "${packages[@]}"
        ;;
    opensuse)
        log "Refreshing openSUSE package metadata"
        run "${sudo_command[@]}" zypper --non-interactive refresh

        log "Installing openSUSE packages"
        run "${sudo_command[@]}" zypper --non-interactive install -y "${packages[@]}"
        ;;
esac

log "Installing Flatpak applications"
run flatpak remote-add --user --if-not-exists flathub \
    https://dl.flathub.org/repo/flathub.flatpakrepo
while IFS= read -r app_id; do
    [[ -z $app_id || $app_id == \#* ]] && continue
    run flatpak install --user -y flathub "$app_id"
done < "$repo_dir/flatpaks.txt"

log "Installing Sway configuration"
run install -d "$HOME/.config/sway" "$HOME/.config/waybar" \
    "$HOME/.config/wofi" "$HOME/.config/mako" "$HOME/.local/bin" \
    "$HOME/Pictures/Wallpapers"

run install -m0644 "$repo_dir/dotfiles/.config/sway/config" "$HOME/.config/sway/config"
run install -m0644 "$repo_dir/dotfiles/.config/sway/compositors/${compositor_profile}.conf" \
    "$HOME/.config/sway/compositor.conf"
run install -m0644 "$repo_dir/dotfiles/.config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
run install -m0644 "$repo_dir/dotfiles/.config/waybar/style.css" "$HOME/.config/waybar/style.css"
run install -m0644 "$repo_dir/dotfiles/.config/wofi/style.css" "$HOME/.config/wofi/style.css"
run install -m0644 "$repo_dir/dotfiles/.config/mako/config" "$HOME/.config/mako/config"
run install -m0755 "$repo_dir/dotfiles/.local/bin/sway-launch-browser" "$HOME/.local/bin/sway-launch-browser"
run install -m0755 "$repo_dir/dotfiles/.local/bin/sway-power-menu" "$HOME/.local/bin/sway-power-menu"
run install -m0755 "$repo_dir/dotfiles/.local/bin/sway-screenshot" "$HOME/.local/bin/sway-screenshot"
run install -m0755 "$repo_dir/dotfiles/.local/bin/sway-session-start" "$HOME/.local/bin/sway-session-start"
run install -m0755 "$repo_dir/dotfiles/.local/bin/sway-wallpaper-picker" "$HOME/.local/bin/sway-wallpaper-picker"

run install -m0644 "$repo_dir/dotfiles/.config/sway/outputs.conf.example" "$HOME/.config/sway/outputs.conf.example"
if [[ ! -e $HOME/.config/sway/outputs.conf ]]; then
    run install -m0644 "$repo_dir/dotfiles/.config/sway/outputs.conf.example" "$HOME/.config/sway/outputs.conf"
fi

run install -m0644 "$repo_dir/dotfiles/.config/sway/wallpaper.conf.example" "$HOME/.config/sway/wallpaper.conf.example"
if [[ ! -e $HOME/.config/sway/wallpaper.conf ]]; then
    run install -m0644 "$repo_dir/dotfiles/.config/sway/wallpaper.conf.example" "$HOME/.config/sway/wallpaper.conf"
fi

if [[ -n ${SWAYSOCK:-} && $dry_run != 1 ]]; then
    log "Reloading the active Sway session"
    swaymsg reload
else
    log "Sway configuration will take effect at the next login"
fi

log "Setup complete"
printf '%s\n' \
    "Log out, choose Sway from the login screen, and sign in." \
    "For monitor tuning, copy ~/.config/sway/outputs.conf.example to outputs.conf and edit it." \
    "To connect GitHub, run: gh auth login"
