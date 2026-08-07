#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dry_run=${DRY_RUN:-0}
skip_packages=${SKIP_PACKAGES:-0}
os_release_file=${OS_RELEASE_FILE:-/etc/os-release}
backup_dir=""

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [--dry-run] [--config-only]
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --config-only) skip_packages=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
    shift
done

run() {
    if [[ $dry_run == 1 ]]; then
        printf '  '; printf '%q ' "$@"; printf '\n'
    else
        "$@"
    fi
}

install_managed() {
    local mode=$1 source=$2 destination=$3 relative backup_path
    if [[ -e $destination ]] && ! cmp -s "$source" "$destination"; then
        if [[ -z $backup_dir ]]; then
            backup_dir="$HOME/.local/state/sway-workstation/backups/$(date +%Y%m%d-%H%M%S)-$$"
            log "Backing up replaced files to $backup_dir"
        fi
        relative=${destination#"$HOME"/}
        backup_path="$backup_dir/$relative"
        run install -d "${backup_path%/*}"
        run cp -a -- "$destination" "$backup_path"
    fi
    run install -d "${destination%/*}"
    run install -m"$mode" "$source" "$destination"
}

install_default() {
    local mode=$1 source=$2 destination=$3
    if [[ ! -e $destination ]]; then
        run install -d "${destination%/*}"
        run install -m"$mode" "$source" "$destination"
    fi
}

detect_distro() {
    [[ -r $os_release_file ]] || return 1
    # shellcheck disable=SC1090
    source "$os_release_file"
    distro_id=${ID:-unknown}
    local ids=" ${distro_id,,} ${ID_LIKE:-} "
    ids=${ids,,}
    case "$ids" in
        *" fedora "*|*" rhel "*) distro_family=fedora; package_manager=dnf ;;
        *" debian "*|*" ubuntu "*) distro_family=debian; package_manager=apt-get ;;
        *" arch "*) distro_family=arch; package_manager=pacman ;;
        *" opensuse "*|*" suse "*) distro_family=opensuse; package_manager=zypper ;;
        *" alpine "*) distro_family=alpine; package_manager=apk ;;
        *" void "*) distro_family=void; package_manager=xbps-install ;;
        *" gentoo "*) distro_family=gentoo; package_manager=emerge ;;
        *) return 1 ;;
    esac
}

if ((EUID == 0)) && [[ ${SUDO_USER:-root} != root ]]; then
    die "Run this as your normal user, not with sudo"
fi

distro_id=unknown
distro_family=unknown
package_manager=none
PRETTY_NAME=${PRETTY_NAME:-Linux}

if ! detect_distro; then
    [[ $skip_packages == 1 ]] || die "Unsupported distribution; use --config-only"
fi

log "Detected ${PRETTY_NAME:-$distro_id} (${distro_family} family)"
[[ $dry_run == 0 ]] || log "Dry run: no changes will be made"

if [[ $skip_packages != 1 ]]; then
    manifest="$repo_dir/packages-${distro_family}.txt"
    [[ -f $manifest ]] || die "Missing ${manifest##*/}"
    command -v sudo >/dev/null || die "sudo is required"
    command -v "$package_manager" >/dev/null || die "$package_manager is required"
    mapfile -t packages < <(sed -E '/^[[:space:]]*(#|$)/d' "$manifest")
    ((${#packages[@]})) || die "Package manifest is empty"

    log "Refreshing sudo credentials"
    run sudo -v

    case "$distro_family" in
        fedora) run sudo dnf install -y "${packages[@]}" ;;
        debian)
            run sudo apt-get update
            run sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${packages[@]}"
            ;;
        arch) run sudo pacman -Syu --needed --noconfirm "${packages[@]}" ;;
        opensuse)
            run sudo zypper --non-interactive refresh
            run sudo zypper --non-interactive install -y "${packages[@]}"
            ;;
        alpine) run sudo apk add --no-cache "${packages[@]}" ;;
        void)
            run sudo xbps-install -S
            run sudo xbps-install -y "${packages[@]}"
            ;;
        gentoo) run sudo emerge --ask=n --noreplace "${packages[@]}" ;;
    esac
else
    log "Skipping package installation"
fi

log "Installing Sway configuration"
install_managed 0644 "$repo_dir/dotfiles/.config/sway/config" "$HOME/.config/sway/config"
install_managed 0644 "$repo_dir/dotfiles/.config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
install_managed 0644 "$repo_dir/dotfiles/.config/waybar/style.css" "$HOME/.config/waybar/style.css"
install_managed 0644 "$repo_dir/dotfiles/.config/wofi/style.css" "$HOME/.config/wofi/style.css"
install_managed 0644 "$repo_dir/dotfiles/.config/mako/config" "$HOME/.config/mako/config"
install_managed 0644 "$repo_dir/dotfiles/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
install_managed 0644 "$repo_dir/dotfiles/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
install_managed 0644 "$repo_dir/dotfiles/.config/xdg-desktop-portal/sway-portals.conf" "$HOME/.config/xdg-desktop-portal/sway-portals.conf"

for script in apply-wallpaper-theme sway-power-menu sway-screenshot sway-session-start sway-terminal sway-wallpaper-picker; do
    install_managed 0755 "$repo_dir/dotfiles/.local/bin/$script" "$HOME/.local/bin/$script"
done

install_managed 0644 "$repo_dir/dotfiles/.config/sway/outputs.conf.example" "$HOME/.config/sway/outputs.conf.example"
install_default 0644 "$repo_dir/dotfiles/.config/sway/outputs.conf.example" "$HOME/.config/sway/outputs.conf"
install_managed 0644 "$repo_dir/dotfiles/.config/sway/wallpaper.conf.example" "$HOME/.config/sway/wallpaper.conf.example"
install_default 0644 "$repo_dir/dotfiles/.config/sway/wallpaper.conf.example" "$HOME/.config/sway/wallpaper.conf"

for colors_file in sway/colors.conf waybar/colors.css wofi/colors.css mako/colors gtk-3.0/colors.css gtk-4.0/colors.css; do
    install_default 0644 "$repo_dir/dotfiles/.config/$colors_file" "$HOME/.config/$colors_file"
done

run install -d "$HOME/Pictures/Wallpapers"

if [[ -n ${SWAYSOCK:-} && $dry_run != 1 ]]; then
    swaymsg reload
fi

log "Setup complete"
printf '%s\n' \
    "Log out, choose Sway, and sign in." \
    "Press Super+Shift+W to choose a wallpaper." \
    "Edit ~/.config/sway/outputs.conf for monitor settings."
