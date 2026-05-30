#!/bin/bash
set -e

NAME="tomatina"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_SRC="$SCRIPT_DIR/$NAME"
BIN_DIR="${HOME}/.local/bin"
BIN_LINK="${BIN_DIR}/${NAME}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${NAME}"
CONFIG_FILE="$CONFIG_DIR/config"
WAYBAR_CONFIG="${HOME}/.config/waybar/config.jsonc"
WAYBAR_SNIPPET="$CONFIG_DIR/waybar-module.jsonc"

patch_waybar_config() {
    local config="$1"

    if ! command -v python3 &>/dev/null; then
        echo "  ! python3 not found; add Waybar snippet manually from $WAYBAR_SNIPPET"
        return 0
    fi

    WAYBAR_CONFIG_PATH="$config" python3 <<'PY'
import os
import re
import shutil
import sys

path = os.environ["WAYBAR_CONFIG_PATH"]
with open(path, "r", encoding="utf-8") as fh:
    text = fh.read()

module = '''  "custom/tomatina": {
    "exec": "$HOME/.local/bin/tomatina status --bar waybar",
    "return-type": "json",
    "format": "{}  ",
    "on-click": "$HOME/.local/bin/tomatina toggle",
    "on-click-right": "$HOME/.local/bin/tomatina stop",
    "signal": 14,
    "interval": 1
  }'''

changed = False

modules_re = re.compile(r'("modules-center"\s*:\s*\[)(.*?)(\n\s*\])', re.S)
match = modules_re.search(text)
if match:
    body = match.group(2)
    if '"custom/tomatina"' not in body:
        lines = [line for line in body.splitlines() if line.strip()]
        if lines:
            lines = [re.sub(r',\s*$', '', line) for line in lines]
            new_body = '\n    "custom/tomatina",\n' + ',\n'.join(lines)
        else:
            new_body = '\n    "custom/tomatina"'
        text = text[:match.start()] + match.group(1) + new_body + match.group(3) + text[match.end():]
        changed = True
else:
    print("modules-center not found; add custom/tomatina manually", file=sys.stderr)

if '"custom/tomatina"' in text and re.search(r'"custom/tomatina"\s*:\s*\{', text):
    module_re = re.compile(r'\n\s*"custom/tomatina"\s*:\s*\{.*?\n\s*\}', re.S)
    text, count = module_re.subn('\n' + module, text, count=1)
    changed = changed or count > 0
else:
    stripped = text.rstrip()
    if stripped.endswith("}"):
        prefix = stripped[:-1].rstrip()
        if prefix.endswith("{"):
            text = prefix + "\n" + module + "\n}\n"
        else:
            text = prefix + ",\n" + module + "\n}\n"
        changed = True
    else:
        print("Could not find final object brace; add custom/tomatina manually", file=sys.stderr)

if changed:
    backup = path + ".bak.tomatina"
    if not os.path.exists(backup):
        shutil.copy2(path, backup)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    print(f"patched {path} (backup: {backup})")
else:
    print(f"{path} already has custom/tomatina")
PY
}

if [ ! -f "$SCRIPT_SRC" ]; then
    echo "Error: $SCRIPT_SRC not found. Run this script from the repo directory." >&2
    exit 1
fi

echo "==> Installing $NAME..."

# 1. Symlink to ~/.local/bin/
mkdir -p "$BIN_DIR"
if [ -f "$BIN_LINK" ] || [ -L "$BIN_LINK" ]; then
    echo "  ~ $BIN_LINK already exists, backing up to ${BIN_LINK}.bak"
    mv "$BIN_LINK" "${BIN_LINK}.bak"
fi
ln -sf "$SCRIPT_SRC" "$BIN_LINK"
echo "  + Symlinked $BIN_LINK -> $SCRIPT_SRC"

# 2. Create default config if not exists
mkdir -p "$CONFIG_DIR"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" <<EOF
# Tomatina configuration
work_duration=20
recap_break_duration=5
deep_break_duration=5
bar=waybar
cmd=
EOF
    echo "  + Created default config: $CONFIG_FILE"
else
    echo "  ~ Config already exists: $CONFIG_FILE"
fi

# 3. Detect environment and set bar default
if grep -q "^bar=" "$CONFIG_FILE" 2>/dev/null; then
    current_bar=$(grep "^bar=" "$CONFIG_FILE" | cut -d= -f2)
    if [ -z "$current_bar" ]; then
        if [ -n "$SWAYSOCK" ]; then
            sed -i 's/^bar=.*/bar=swaybar/' "$CONFIG_FILE"
            echo "  ~ Detected Sway, set bar=swaybar"
        elif [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
            sed -i 's/^bar=.*/bar=waybar/' "$CONFIG_FILE"
            echo "  ~ Detected Hyprland, set bar=waybar"
        fi
    fi
fi

# 4. Write Waybar snippet and patch Waybar config when available
cat > "$WAYBAR_SNIPPET" <<'MODULE'
    "custom/tomatina": {
        "exec": "$HOME/.local/bin/tomatina status --bar waybar",
        "return-type": "json",
        "format": "{}  ",
        "on-click": "$HOME/.local/bin/tomatina toggle",
        "on-click-right": "$HOME/.local/bin/tomatina stop",
        "signal": 14,
        "interval": 1
    }
MODULE
echo "  + Wrote Waybar module snippet: $WAYBAR_SNIPPET"

if [ -f "$WAYBAR_CONFIG" ]; then
    echo "  ~ Patching Waybar config: $WAYBAR_CONFIG"
    if patch_output=$(patch_waybar_config "$WAYBAR_CONFIG" 2>&1); then
        while IFS= read -r line; do
            [ -n "$line" ] && echo "    $line"
        done <<< "$patch_output"
    else
        echo "  ! Could not patch Waybar config automatically"
        echo "$patch_output" | sed 's/^/    /'
        echo "    Add \"custom/tomatina\" manually and copy the module from $WAYBAR_SNIPPET"
    fi
else
    echo "  ! Waybar config not found at $WAYBAR_CONFIG; snippet is ready if you use Waybar later"
fi

# 5. Restart Waybar
if command -v omarchy-restart-waybar &>/dev/null; then
    echo "  ~ Restarting Waybar..."
    omarchy-restart-waybar || echo "  ! Waybar restart failed; restart it manually if needed"
elif command -v systemctl &>/dev/null && systemctl --user status waybar &>/dev/null 2>&1; then
    echo "  ~ Restarting Waybar..."
    systemctl --user restart waybar || echo "  ! Waybar restart failed; restart it manually if needed"
fi

echo ""
echo "Installation complete."
echo "Run '$NAME start' to begin a focus session."
echo "Run '$NAME config' to customize."
