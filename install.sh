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

# 4. Patch Waybar config
if [ -f "$WAYBAR_CONFIG" ]; then
    if grep -q '"custom/tomatina"' "$WAYBAR_CONFIG" 2>/dev/null; then
        echo "  ~ Waybar module already exists in config"
    else
        cp "$WAYBAR_CONFIG" "${WAYBAR_CONFIG}.bak"
        echo "  + Backed up $WAYBAR_CONFIG -> ${WAYBAR_CONFIG}.bak"

        # Insert the tomatina module into modules-right (before closing brace of the array)
        MODULE_ENTRY=$(cat <<'MODULE'
    "custom/tomatina": {
        "exec": "$HOME/.local/bin/tomatina",
        "return-type": "json",
        "format": "{}",
        "on-click": "$HOME/.local/bin/tomatina toggle",
        "on-click-right": "$HOME/.local/bin/tomatina stop",
        "signal": 14
    }
MODULE
)

        # Find the last module in modules-right array and add tomatina after it
        awk '
        /"modules-right":\s*\[/ { in_right = 1; print; next }
        in_right && /\]/ {
            in_right = 0
            print "    \"custom/tomatina\","
            print
            next
        }
        { print }
        ' "$WAYBAR_CONFIG" > "${WAYBAR_CONFIG}.tmp"

        # Now insert the module definition before the closing brace of the config
        awk -v module="$MODULE_ENTRY" '
        /^}/ && !found {
            print ","
            print module
            found = 1
        }
        { print }
        ' "${WAYBAR_CONFIG}.tmp" > "$WAYBAR_CONFIG"

        rm -f "${WAYBAR_CONFIG}.tmp"
        echo "  + Added custom/tomatina module to Waybar config"
    fi
else
    echo "  ! Waybar config not found at $WAYBAR_CONFIG — skipping patch"
fi

# 5. Restart Waybar
if command -v omarchy-restart-waybar &>/dev/null; then
    echo "  ~ Restarting Waybar..."
    omarchy-restart-waybar
elif command -v systemctl &>/dev/null && systemctl --user status waybar &>/dev/null 2>&1; then
    echo "  ~ Restarting Waybar..."
    systemctl --user restart waybar
fi

echo ""
echo "Installation complete."
echo "Run '$NAME start' to begin a focus session."
echo "Run '$NAME config' to customize."
