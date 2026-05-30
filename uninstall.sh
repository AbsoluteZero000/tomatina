#!/bin/bash
set -e

NAME="tomatina"
BIN_DIR="${HOME}/.local/bin"
BIN_LINK="${BIN_DIR}/${NAME}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${NAME}"
WAYBAR_CONFIG="${HOME}/.config/waybar/config.jsonc"
WAYBAR_SNIPPET="$CONFIG_DIR/waybar-module.jsonc"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/${NAME}"

echo "==> Uninstalling $NAME..."

# 1. Remove symlink
if [ -L "$BIN_LINK" ] || [ -f "$BIN_LINK" ]; then
    rm -f "$BIN_LINK"
    echo "  - Removed $BIN_LINK"
fi
if [ -f "${BIN_LINK}.bak" ]; then
    echo "  ~ Restored ${BIN_LINK}.bak -> $BIN_LINK"
    mv "${BIN_LINK}.bak" "$BIN_LINK"
fi

# 2. Remove state
if [ -d "$STATE_DIR" ]; then
    rm -rf "$STATE_DIR"
    echo "  - Removed state directory: $STATE_DIR"
fi

# 3. Remove generated Waybar snippet
if [ -f "$WAYBAR_SNIPPET" ]; then
    rm -f "$WAYBAR_SNIPPET"
    echo "  - Removed Waybar snippet: $WAYBAR_SNIPPET"
fi

# 4. Remove config
if [ -d "$CONFIG_DIR" ]; then
    echo ""
    echo "Config directory found: $CONFIG_DIR"
    read -r -p "Remove config directory? [y/N] " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        rm -rf "$CONFIG_DIR"
        echo "  - Removed $CONFIG_DIR"
    else
        echo "  ~ Kept $CONFIG_DIR"
    fi
fi

# 5. Restore legacy Waybar config backup if present
if [ -f "${WAYBAR_CONFIG}.bak" ]; then
    echo ""
    echo "Waybar backup found: ${WAYBAR_CONFIG}.bak"
    read -r -p "Restore Waybar config from backup? (removes tomatina module) [y/N] " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        cp "${WAYBAR_CONFIG}.bak" "$WAYBAR_CONFIG"
        echo "  + Restored $WAYBAR_CONFIG from backup"
    else
        echo "  ~ Kept current Waybar config. Remove custom/tomatina entries manually if needed."
    fi
elif [ -f "$WAYBAR_CONFIG" ]; then
    echo "  ~ Waybar config found at $WAYBAR_CONFIG"
    echo "    Remove any custom/tomatina entries manually if you added them."
fi

# 6. Restart Waybar
if command -v omarchy-restart-waybar &>/dev/null; then
    echo "  ~ Restarting Waybar..."
    omarchy-restart-waybar || echo "  ! Waybar restart failed; restart it manually if needed"
elif command -v systemctl &>/dev/null && systemctl --user status waybar &>/dev/null 2>&1; then
    echo "  ~ Restarting Waybar..."
    systemctl --user restart waybar || echo "  ! Waybar restart failed; restart it manually if needed"
fi

echo ""
echo "Uninstallation complete."
