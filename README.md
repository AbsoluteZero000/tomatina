# tomatina 🍅

A pomodoro-style focus timer that cycles through **working → recap break → deep break → working...** with multi-bar support for Waybar, Swaybar, and Polybar.

```
🍅  15:23    working
🔁   3:47    recap_break  (rethink what you learned)
🛌   4:12    deep_break   (just resting)
```

## Cycle

```
working (20m) ──► recap_break (5m) ──► deep_break (5m) ──► working ...
```

The timer cycles indefinitely. Run `tomatina stop` to reset to idle.

## Installation

```bash
git clone https://github.com/AbsoluteZero000/tomatina.git
cd tomatina
./install.sh
```

This symlinks `tomatina` to `~/.local/bin/`, creates a default config, writes a Waybar module snippet to `~/.config/tomatina/waybar-module.jsonc`, and patches `~/.config/waybar/config.jsonc` when it exists. A backup is saved as `config.jsonc.bak.tomatina`.

## Usage

```bash
tomatina start                    # Start a work session
tomatina start --cmd "safeeyes --take-break"  # Run command when work ends
tomatina toggle                   # Pause/resume
tomatina stop                     # Stop and reset to idle
tomatina status                   # One-shot status (text)
tomatina status --bar json        # One-shot status (JSON)
tomatina config                   # Interactive configuration
tomatina config show              # Show config
tomatina config set work_duration 25  # Set specific value
tomatina help                     # Full usage
```

## Post-Work Command

The `--cmd` flag runs a command each time the work phase ends (transitioning to recap break). This is useful for break enforcement:

```bash
tomatina start --cmd "safeeyes --take-break"
tomatina start --cmd "notify-send 'Break time! Take a rest.'"
tomatina start --cmd "~/.local/bin/my-break-hook.sh"
```

Set a permanent default in `~/.config/tomatina/config`:
```
cmd=safeeyes --take-break
```

## Bar Integration

### Waybar

Add to `~/.config/waybar/config.jsonc`:

```json
"custom/tomatina": {
    "exec": "$HOME/.local/bin/tomatina",
    "return-type": "json",
    "format": "{}",
    "on-click": "$HOME/.local/bin/tomatina toggle",
    "on-click-right": "$HOME/.local/bin/tomatina stop",
    "signal": 14
}
```

The installer also writes this module block to `~/.config/tomatina/waybar-module.jsonc`.

### Swaybar

In your Sway config:
```
bar {
    status_command tomatina daemon --bar swaybar
}
```

### Polybar

In your Polybar config:
```ini
[module/tomatina]
type = custom/script
exec = tomatina status --bar polybar
interval = 1
```

## Configuration

File: `~/.config/tomatina/config`

```
work_duration=20           # Minutes
recap_break_duration=5     # Minutes
deep_break_duration=5      # Minutes
bar=waybar                 # waybar, swaybar, polybar
cmd=                       # Post-work command (optional)
```

## Uninstall

```bash
./uninstall.sh
```

## License

MIT
