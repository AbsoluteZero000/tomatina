#!/bin/bash
set -e

NAME="tomatina"
BIN_DIR="${HOME}/.local/bin"
BIN_LINK="${BIN_DIR}/${NAME}"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${NAME}"
WAYBAR_CONFIG="${HOME}/.config/waybar/config.jsonc"
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

# 3. Remove config
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

# 4. Restore Waybar config from backup
if [ -f "${WAYBAR_CONFIG}.bak" ]; then
    echo ""
    echo "Waybar backup found: ${WAYBAR_CONFIG}.bak"
    read -r -p "Restore Waybar config from backup? (removes tomatina module) [y/N] " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        cp "${WAYBAR_CONFIG}.bak" "$WAYBAR_CONFIG"
        echo "  + Restored $WAYBAR_CONFIG from backup"
    else
        # Try to remove the module entries from the config
        read -r -p "Remove tomatina entries from current Waybar config? [y/N] " confirm2
        if [ "$confirm2" = "y" ] || [ "$confirm2" = "Y" ]; then
            awk '
            /"custom\/tomatina"/ { skip_module = 1 }
            skip_module && /^    },?$/ { skip_module = 0; next }
            !skip_module { print }
            ' "$WAYBAR_CONFIG" > "${WAYBAR_CONFIG}.tmp"
            mv "${WAYBAR_CONFIG}.tmp" "$WAYBAR_CONFIG"
            echo "  - Removed tomatina module from Waybar config"
        fi
    fi
elif [ -f "$WAYBAR_CONFIG" ]; then
    echo ""
    read -r -p "Remove tomatina entries from current Waybar config? (no backup found) [y/N] " confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        awk '
        /"custom\/tomatina/ { skip_module = 1 }
        skip_module && /^    },?$/ { skip_module = 0; next }
        !skip_module { print }
        ' "$WAYBAR_CONFIG" > "${WAYBAR_CONFIG}.tmp"
        mv "${WAYBAR_CONFIG}.tmp" "$WAYBAR_CONFIG"
        echo "  - Removed tomatina module from Waybar config"
    fi
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
echo "Uninstallation complete."
