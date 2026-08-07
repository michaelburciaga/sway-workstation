#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

run_case() {
    local name=$1
    local id=$2
    local id_like=$3
    local version=$4
    local expected_family=$5
    local expected_command=$6
    local os_release="$test_dir/${name}.os-release"
    local home_dir="$test_dir/${name}-home"
    local output

    mkdir -p "$home_dir"
    printf 'ID=%s\nID_LIKE="%s"\nVERSION_ID="%s"\nPRETTY_NAME="%s test"\n' \
        "$id" "$id_like" "$version" "$name" >"$os_release"

    output=$(
        HOME="$home_dir" \
        OS_RELEASE_FILE="$os_release" \
        DRY_RUN=1 \
        "$repo_dir/bootstrap.sh"
    )

    [[ $output == *"(${expected_family} family)"* ]]
    [[ $output == *"$expected_command"* ]]
    [[ $output == *"compositors/sway.conf"* ]]
    [[ $output != *"flatpak install"* ]]
    printf 'ok - %s\n' "$name"
}

run_case Fedora fedora "" 44 fedora "dnf install"
run_case Ubuntu ubuntu debian 24.04 debian "apt-get install"
run_case PopOS pop "ubuntu debian" 24.04 debian "apt-get install"
run_case Mint linuxmint "ubuntu debian" 22 debian "apt-get install"
run_case Debian debian "" 13 debian "apt-get install"
run_case Arch arch "" rolling arch "pacman -Syu"
run_case EndeavourOS endeavouros arch rolling arch "pacman -Syu"
run_case Manjaro manjaro arch rolling arch "pacman -Syu"
run_case openSUSE opensuse-tumbleweed "opensuse suse" rolling opensuse \
    "zypper --non-interactive install"
run_case Alpine alpine "" 3.23 alpine "apk add"
run_case Void void "" rolling void "xbps-install -y"
run_case Gentoo gentoo "" rolling gentoo "emerge --ask=n"

unknown_release="$test_dir/unknown.os-release"
unknown_home="$test_dir/unknown-home"
mkdir -p "$unknown_home"
printf '%s\n' 'ID=nixos' 'PRETTY_NAME="NixOS test"' >"$unknown_release"
output=$(
    HOME="$unknown_home" \
    OS_RELEASE_FILE="$unknown_release" \
    DRY_RUN=1 \
    "$repo_dir/bootstrap.sh" --config-only
)
[[ $output == *"Skipping package installation"* ]]
[[ $output == *"dotfiles/.config/sway/config"* ]]
printf 'ok - unknown distributions support configuration-only mode\n'

for unwanted in flatpak brave spotify vlc ffmpeg github-cli golang fastfetch; do
    if grep -Eiq "^[[:space:]]*${unwanted}([[:space:]]|$)" "$repo_dir"/packages-*.txt; then
        printf 'not ok - unwanted package remains: %s\n' "$unwanted" >&2
        exit 1
    fi
done
printf 'ok - package manifests contain no personal applications\n'
