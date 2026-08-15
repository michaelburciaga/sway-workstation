#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

mkdir -p "$test_dir/bin" "$test_dir/runtime"

cat >"$test_dir/bin/swaymsg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
    '--raw --type get_tree')
        printf '{"focused":true,"floating":"auto_off","rect":{"width":%s,"height":%s}}\n' \
            "$MOCK_WIDTH" "$MOCK_HEIGHT"
        ;;
    '--quiet split horizontal')
        printf 'horizontal\n' >>"$MOCK_RESULT"
        ;;
    '--quiet split vertical')
        printf 'vertical\n' >>"$MOCK_RESULT"
        ;;
    '--monitor --type subscribe ["window", "workspace"]')
        printf '%s\n' '{"change":"title"}'
        printf '%s\n' '{"change":"focus"}'
        ;;
    *)
        printf 'unexpected swaymsg arguments: %s\n' "$*" >&2
        exit 1
        ;;
esac
EOF
chmod +x "$test_dir/bin/swaymsg"

run_case() {
    local name=$1 width=$2 height=$3 expected=$4 result
    result="$test_dir/$name.result"

    PATH="$test_dir/bin:$PATH" \
    XDG_RUNTIME_DIR="$test_dir/runtime" \
    MOCK_WIDTH=$width \
    MOCK_HEIGHT=$height \
    MOCK_RESULT=$result \
        "$repo_dir/dotfiles/.local/bin/sway-autotiling"

    [[ $(tail -n 1 "$result") == "$expected" ]]
    [[ $(wc -l <"$result") -eq 2 ]]
    printf 'ok - %s tiles choose a %s split\n' "$name" "$expected"
}

run_case wide 1600 900 horizontal
run_case tall 700 1200 vertical
