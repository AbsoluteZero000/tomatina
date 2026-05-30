#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

run_tomatina() {
    HOME="$TMP_DIR/home" \
    XDG_CONFIG_HOME="$TMP_DIR/config" \
    XDG_RUNTIME_DIR="$TMP_DIR/run" \
    "$ROOT_DIR/tomatina" "$@"
}

mkdir -p "$TMP_DIR/home" "$TMP_DIR/config" "$TMP_DIR/run"

if run_tomatina config set work_duration abc 2>/dev/null; then
    echo "Expected invalid duration to fail" >&2
    exit 1
fi

run_tomatina config set cmd 'notify-send A & notify-send B'
grep -qx 'cmd=notify-send A & notify-send B' "$TMP_DIR/config/tomatina/config"

if run_tomatina start --cmd 2>/dev/null; then
    echo "Expected missing --cmd value to fail" >&2
    exit 1
fi

run_tomatina config set work_duration 1
run_tomatina start >/dev/null
run_tomatina status --bar json | grep -q '"status":"working"'
run_tomatina stop >/dev/null

mkdir -p "$TMP_DIR/expired-config/tomatina" "$TMP_DIR/expired-run/tomatina"
printf 'working\n0\n1\n0\n' > "$TMP_DIR/expired-run/tomatina/state"
printf 'work_duration=1\nrecap_break_duration=1\ndeep_break_duration=1\nbar=json\ncmd=printf fired > %s/fired\n' "$TMP_DIR" > "$TMP_DIR/expired-config/tomatina/config"
HOME="$TMP_DIR/home" \
XDG_CONFIG_HOME="$TMP_DIR/expired-config" \
XDG_RUNTIME_DIR="$TMP_DIR/expired-run" \
    "$ROOT_DIR/tomatina" status --bar json | grep -q '"status":"recap_break"'
sleep 0.2
grep -qx 'fired' "$TMP_DIR/fired"

mkdir -p "$TMP_DIR/install-home/.config/waybar" "$TMP_DIR/fakebin"
cat > "$TMP_DIR/install-home/.config/waybar/config.jsonc" <<'JSON'
{
  "layer": "top",
  "modules-right": [
    "clock"
  ]
}
JSON
cp "$TMP_DIR/install-home/.config/waybar/config.jsonc" "$TMP_DIR/original-waybar.jsonc"
printf '#!/bin/sh\nexit 1\n' > "$TMP_DIR/fakebin/systemctl"
printf '#!/bin/sh\nexit 0\n' > "$TMP_DIR/fakebin/omarchy-restart-waybar"
chmod +x "$TMP_DIR/fakebin/systemctl" "$TMP_DIR/fakebin/omarchy-restart-waybar"
HOME="$TMP_DIR/install-home" \
XDG_CONFIG_HOME="$TMP_DIR/install-home/.config" \
PATH="$TMP_DIR/fakebin:$PATH" \
    "$ROOT_DIR/install.sh" >/dev/null
grep -q '"custom/tomatina"' "$TMP_DIR/install-home/.config/waybar/config.jsonc"
grep -q '"format": "{}  "' "$TMP_DIR/install-home/.config/waybar/config.jsonc"
test -f "$TMP_DIR/install-home/.config/waybar/config.jsonc.bak.tomatina"
cmp "$TMP_DIR/original-waybar.jsonc" "$TMP_DIR/install-home/.config/waybar/config.jsonc.bak.tomatina"
test -f "$TMP_DIR/install-home/.config/tomatina/waybar-module.jsonc"

echo "smoke tests passed"
