#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT

mkdir -p \
    "$test_dir/bin" \
    "$test_dir/home/.config/gtklock" \
    "$test_dir/home/.cache/sway-lock" \
    "$test_dir/runtime"

cp "$repo_dir/dotfiles/.config/gtklock/layout.ui" \
    "$test_dir/home/.config/gtklock/layout.ui"
cp "$repo_dir/dotfiles/.config/gtklock/style.css" \
    "$test_dir/home/.config/gtklock/style.css"
touch "$test_dir/home/.cache/sway-lock/background.png"

cat >"$test_dir/bin/getent" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'testuser:x:1000:1000:Michael Test:/home/testuser:/bin/bash'
EOF

cat >"$test_dir/bin/id" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == -un ]] && printf '%s\n' testuser
EOF

cat >"$test_dir/bin/gtklock" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$MOCK_GTKLOCK_ARGS"
EOF

cat >"$test_dir/bin/swaylock" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"$MOCK_SWAYLOCK_ARGS"
EOF
chmod +x "$test_dir/bin/"*

HOME="$test_dir/home" \
PATH="$test_dir/bin:$PATH" \
XDG_RUNTIME_DIR="$test_dir/runtime" \
MOCK_GTKLOCK_ARGS="$test_dir/gtklock.args" \
MOCK_SWAYLOCK_ARGS="$test_dir/swaylock.args" \
    "$repo_dir/dotfiles/.local/bin/lock-screen"

layout="$test_dir/runtime/gtklock-layout-$(id -u).ui"
grep -q 'Michael Test' "$layout"
! grep -q '@USER_NAME@' "$layout"
grep -qx -- '--daemonize' "$test_dir/gtklock.args"
grep -qx -- '--background' "$test_dir/gtklock.args"
grep -qx -- "$test_dir/home/.cache/sway-lock/background.png" \
    "$test_dir/gtklock.args"
python3 -c 'import sys, xml.etree.ElementTree as ET; ET.parse(sys.argv[1])' "$layout"

HOME="$test_dir/home" \
PATH="$test_dir/bin:$PATH" \
GTKLOCK_DISABLE=1 \
MOCK_SWAYLOCK_ARGS="$test_dir/swaylock.args" \
    "$repo_dir/dotfiles/.local/bin/lock-screen"
grep -qx -- '-f' "$test_dir/swaylock.args"

printf 'ok - lock screen shows the account name and keeps a swaylock fallback\n'
