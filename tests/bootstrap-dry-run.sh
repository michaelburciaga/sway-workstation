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
    local expected_profile=$7
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
    [[ $output == *"compositors/${expected_profile}.conf"* ]]
    printf 'ok - %s\n' "$name"
}

run_case Fedora fedora "" 44 fedora "dnf install" swayfx
run_case Ubuntu ubuntu debian 24.04 debian "apt-get install" sway
run_case Debian debian "" 13 debian "apt-get install" sway
run_case EndeavourOS endeavouros arch rolling arch "pacman -Syu" sway
run_case openSUSE opensuse-tumbleweed "opensuse suse" rolling opensuse \
    "zypper --non-interactive install" sway

unsupported_release="$test_dir/unsupported.os-release"
printf '%s\n' 'ID=gentoo' 'PRETTY_NAME="Gentoo test"' \
    >"$unsupported_release"

if HOME="$test_dir/unsupported-home" \
    OS_RELEASE_FILE="$unsupported_release" \
    DRY_RUN=1 \
    "$repo_dir/bootstrap.sh" >/dev/null 2>&1; then
    printf 'not ok - unsupported distribution was accepted\n' >&2
    exit 1
fi
printf 'ok - unsupported distribution is rejected clearly\n'
