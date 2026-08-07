#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
dry_run=${DRY_RUN:-0}
skip_packages=${SKIP_PACKAGES:-0}
os_release_file=${OS_RELEASE_FILE:-/etc/os-release}
backup_dir=""

usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [options]

Install Michael's portable Sway desktop configuration.

Options:
  --dry-run        Print commands without changing the system
  --config-only    Install configuration without installing packages
  -h, --help       Show this help

Environment overrides:
  DRY_RUN=1, SKIP_PACKAGES=1, OS_RELEASE_FILE=/path/to/os-release
  SWAY_PROFILE=auto|sway|swayfx
EOF
}

while (($#)); do
    case "$1" in
        --dry-run) dry_run=1 ;;
        --config-only) skip_packages=1 ;;
        -h|--help) usage; exit 0 ;;
        *) printf 'error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

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
    ((${#packages[@]} > 0)) || die "Package manifest '$manifest' is empty"
}

install_managed() {
    local mode=$1
    local source=$2
    local destination=$3
    local relative backup_path

    if [[ -e $destination ]] && ! cmp -s "$source" "$destination"; then
        if [[ -z $backup_dir ]]; then
            backup_dir="$HOME/.local/state/sway-workstation/backups/$(date +%Y%m%d-%H%M%S)-$$"
            log "Backing up replaced configuration to $backup_dir"
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
    local mode=$1
    local source=$2
    local destination=$3

    if [[ ! -e $destination ]]; then
        run install -d "${destination%/*}"
        run install -m"$mode" "$source" "$destination"
    fi
}

detect_family() {
    [[ -r $os_release_file ]] || return 1
    # shellcheck disable=SC1090
    source "$os_release_file"

    distro_id=${ID:-unknown}
    distro_ids=" ${distro_id,,} ${ID_LIKE:-} "
    distro_ids=${distro_ids,,}

    case "$distro_ids" in
        *" fedora "*|*" rhel "*) distro_family=fedora ;;
        *" debian "*|*" ubuntu "*) distro_family=debian ;;
        *" arch "*) distro_family=arch ;;
        *" opensuse "*|*" opensuse-tumbleweed "*|*" suse "*) distro_family=opensuse ;;
        *" alpine "*) distro_family=alpine ;;
        *" void "*) distro_family=void ;;
        *" gentoo "*) distro_family=gentoo ;;
        *) return 1 ;;
    esac
}

detect_package_manager() {
    local candidate

    for candidate in dnf apt-get pacman zypper apk xbps-install emerge; do
        if command -v "$candidate" >/dev/null; then
            case "$candidate" in
                dnf) distro_family=fedora ;;
                apt-get) distro_family=debian ;;
                pacman) distro_family=arch ;;
                zypper) distro_family=opensuse ;;
                apk) distro_family=alpine ;;
                xbps-install) distro_family=void ;;
                emerge) distro_family=gentoo ;;
            esac
            distro_id=${ID:-$distro_family}
            return 0
        fi
    done
    return 1
}

if ((EUID == 0)) && [[ -n ${SUDO_USER:-} && ${SUDO_USER:-root} != root ]]; then
    die "Run this script as your normal user, without sudo; it requests sudo only for packages"
fi

distro_id=unknown
distro_family=unknown
PRETTY_NAME=${PRETTY_NAME:-Linux}
if ! detect_family; then
    if [[ $skip_packages == 1 ]]; then
        log "Unknown distribution; continuing because configuration-only mode was requested"
    elif ! detect_package_manager; then
        die "Unsupported package manager. Re-run with --config-only after installing the listed dependencies manually"
    fi
fi

case "$distro_family" in
    fedora) package_manager=dnf ;;
    debian) package_manager=apt-get ;;
    arch) package_manager=pacman ;;
    opensuse) package_manager=zypper ;;
    alpine) package_manager=apk ;;
    void) package_manager=xbps-install ;;
    gentoo) package_manager=emerge ;;
    unknown) package_manager=none ;;
esac
package_manifest="packages-${distro_family}.txt"

if ((EUID == 0)); then
    sudo_command=()
else
    sudo_command=(sudo)
fi

log "Detected ${PRETTY_NAME:-$distro_id} (${distro_family} family)"
if [[ $dry_run == 1 ]]; then
    log "Dry run: commands will be printed but not executed"
fi

if [[ $skip_packages != 1 ]]; then
    [[ -f $repo_dir/$package_manifest ]] || die "Missing $package_manifest"
    if [[ $dry_run != 1 ]]; then
        ((${#sudo_command[@]} == 0)) || require_command sudo
        require_command "$package_manager"
    fi

    if ((${#sudo_command[@]} > 0)); then
        log "Refreshing sudo credentials"
        run "${sudo_command[@]}" -v
    fi

    load_packages "$package_manifest"
    case "$distro_family" in
        fedora)
            log "Installing required Fedora-family packages"
            run "${sudo_command[@]}" dnf install -y "${packages[@]}"
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

            log "Installing required Debian-family packages"
            run "${sudo_command[@]}" env DEBIAN_FRONTEND=noninteractive \
                apt-get install -y --no-install-recommends "${packages[@]}"
            ;;
        arch)
            log "Installing required Arch-family packages"
            run "${sudo_command[@]}" pacman -Syu --needed --noconfirm "${packages[@]}"
            ;;
        opensuse)
            log "Refreshing openSUSE package metadata"
            run "${sudo_command[@]}" zypper --non-interactive refresh
            log "Installing required openSUSE packages"
            run "${sudo_command[@]}" zypper --non-interactive install -y "${packages[@]}"
            ;;
        alpine)
            log "Installing required Alpine packages"
            run "${sudo_command[@]}" apk add --no-cache "${packages[@]}"
            ;;
        void)
            log "Refreshing Void package metadata"
            run "${sudo_command[@]}" xbps-install -S
            log "Installing required Void packages"
            run "${sudo_command[@]}" xbps-install -y "${packages[@]}"
            ;;
        gentoo)
            log "Installing required Gentoo packages"
            run "${sudo_command[@]}" emerge --ask=n --noreplace "${packages[@]}"
            ;;
    esac
else
    log "Skipping package installation"
fi

compositor_profile=${SWAY_PROFILE:-auto}
case "$compositor_profile" in
    auto)
        compositor_profile=sway
        if [[ $dry_run != 1 ]] && command -v sway >/dev/null && \
            sway --version 2>/dev/null | grep -qi swayfx; then
            compositor_profile=swayfx
        fi
        ;;
    sway|swayfx) ;;
    *) die "SWAY_PROFILE must be auto, sway, or swayfx" ;;
esac

log "Installing Sway configuration (profile: $compositor_profile)"
install_managed 0644 "$repo_dir/dotfiles/.config/sway/config" "$HOME/.config/sway/config"
install_managed 0644 "$repo_dir/dotfiles/.config/sway/compositors/${compositor_profile}.conf" \
    "$HOME/.config/sway/compositor.conf"
install_managed 0644 "$repo_dir/dotfiles/.config/waybar/config.jsonc" "$HOME/.config/waybar/config.jsonc"
install_managed 0644 "$repo_dir/dotfiles/.config/waybar/style.css" "$HOME/.config/waybar/style.css"
install_managed 0644 "$repo_dir/dotfiles/.config/wofi/style.css" "$HOME/.config/wofi/style.css"
install_managed 0644 "$repo_dir/dotfiles/.config/mako/config" "$HOME/.config/mako/config"
install_managed 0644 "$repo_dir/dotfiles/.config/foot/foot.ini" "$HOME/.config/foot/foot.ini"
install_managed 0644 "$repo_dir/dotfiles/.config/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css"
install_managed 0644 "$repo_dir/dotfiles/.config/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css"
install_managed 0644 "$repo_dir/dotfiles/.config/xdg-desktop-portal/sway-portals.conf" \
    "$HOME/.config/xdg-desktop-portal/sway-portals.conf"

for script in apply-wallpaper-theme sway-power-menu sway-screenshot \
    sway-session-start sway-wallpaper-picker; do
    install_managed 0755 "$repo_dir/dotfiles/.local/bin/$script" "$HOME/.local/bin/$script"
done

install_managed 0644 "$repo_dir/dotfiles/.config/sway/outputs.conf.example" \
    "$HOME/.config/sway/outputs.conf.example"
install_default 0644 "$repo_dir/dotfiles/.config/sway/outputs.conf.example" \
    "$HOME/.config/sway/outputs.conf"
install_managed 0644 "$repo_dir/dotfiles/.config/sway/wallpaper.conf.example" \
    "$HOME/.config/sway/wallpaper.conf.example"
install_default 0644 "$repo_dir/dotfiles/.config/sway/wallpaper.conf.example" \
    "$HOME/.config/sway/wallpaper.conf"

for colors_file in \
    sway/colors.conf \
    waybar/colors.css \
    wofi/colors.css \
    mako/colors \
    foot/colors.ini \
    gtk-3.0/colors.css \
    gtk-4.0/colors.css; do
    install_default 0644 "$repo_dir/dotfiles/.config/$colors_file" "$HOME/.config/$colors_file"
done

run install -d "$HOME/Pictures/Wallpapers"

if [[ -n ${SWAYSOCK:-} && $dry_run != 1 ]]; then
    log "Reloading the active Sway session"
    swaymsg reload
else
    log "Sway configuration will take effect at the next login"
fi

log "Setup complete"
printf '%s\n' \
    "Log out, choose Sway from the login screen, and sign in." \
    "Put images in ~/Pictures/Wallpapers and press Super+Shift+W." \
    "Edit ~/.config/sway/outputs.conf for monitor-specific settings."
