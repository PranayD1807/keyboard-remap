# Fix Windows & PC Keyboards on macOS

`v0.0.2-beta` • Native Swift • Zero Virtual Drivers • ~5 MB RAM

A lightweight native macOS background daemon and Settings UI designed to make external PC & Windows keyboards (Lenovo, Dell, Keychron, Logitech, mechanical keyboards, etc.) work seamlessly on Mac—**without macOS resetting your swapped modifier keys on disconnect, sleep, or reboot**.

---

## The Problem: The macOS PC Keyboard Bug

When you plug a Windows/PC keyboard into a Mac, the physical bottom row is:
$$\text{Ctrl} \quad-\quad \text{Win} \quad-\quad \text{Alt}$$

macOS by default maps `Windows` to `Command` and `Alt` to `Option`, resulting in:
$$\text{Ctrl} \quad-\quad \text{Command} \quad-\quad \text{Option}$$

This breaks Mac muscle memory, which expects **Control $\rightarrow$ Option $\rightarrow$ Command**.

While you can swap them in macOS System Settings, **macOS has a notorious bug**: whenever an external USB receiver is unplugged, a 2.4GHz dongle drops connection, the keyboard goes to sleep, or your Mac wakes from sleep, **macOS silently forgets your swapped modifier keys and resets to factory defaults**.

---

## Why Not Karabiner-Elements?

| Feature | Karabiner-Elements | **This Tool (keyboard-remap)** |
| :--- | :--- | :--- |
| **Driver Overhead** | Installs heavy virtual HID drivers (DriverKit) | **Zero virtual drivers** (uses native macOS IOKit) |
| **Memory Footprint** | ~50 MB – 100 MB background services | **~5 MB RAM** |
| **CPU Usage** | Continuous input stream interception | **0% CPU** (purely event-driven) |
| **Security Permissions** | Requires broad input interception access | **Standard user-level LaunchAgent** |
| **Setup** | Complex JSON rule hierarchies | **One-click "PC to Mac" preset + clean UI** |

---

## Features

* ⚡ **Instant One-Click Preset**: Click *"Swap Alt ↔ Cmd, Win ↔ Opt"* to instantly match the standard Apple keyboard layout.
* 🔌 **Persistent Across Reconnects**: Uses hardware-level `IOHIDManager` event listeners to re-apply mappings the exact millisecond a keyboard connects, reconnects, or wakes from sleep.
* 🎯 **Device-Specific**: Only remaps the selected external keyboard—your MacBook's built-in keyboard remains 100% untouched.
* 🎛️ **Remap Any Key**: Map any key to any key (e.g. `Insert` $\rightarrow$ `Forward Delete`, `Caps Lock` $\rightarrow$ `Escape`, `F1` $\rightarrow$ `Play/Pause`).
* 🖥️ **Native SwiftUI Settings UI**: Clean, modern macOS Settings window with live daemon status and device detection.
* 🔄 **Live Hot-Reload**: Configuration stored in `~/.config/keyboard-remap/config.json`. Any manual edits reload instantly without needing a restart.

---

## Quick Start / Installation

### Method 1: Via Homebrew (Recommended)

```bash
# Add the tap
brew tap PranayD1807/tap

# Install keyboard-remap
brew install keyboard-remap

# Start the background daemon (starts automatically on login)
brew services start keyboard-remap
```

### Method 2: Build From Source

```bash
git clone https://github.com/PranayD1807/keyboard-remap.git
cd keyboard-remap
./install.sh
```

This will automatically:
1. Compile the native daemon to `~/.local/bin/keyboard-remap-daemon`.
2. Compile and package the Settings app to `~/Applications/Keyboard Remap.app`.
3. Set up your config at `~/.config/keyboard-remap/config.json`.
4. Register and start the background service with `launchd`.

---

## Using the Settings UI

Launch the UI anytime via Terminal:
```bash
keyboard-remap-ui
```
*(or press `Cmd + Space` and search for **Keyboard Remap**)*

1. **Select Device**: Choose your external keyboard from the detected devices dropdown.
2. **Apply Preset**: Click **"Swap Alt ↔ Cmd, Win ↔ Opt"**.
3. **Custom Remappings**: Optionally click **"+ Add Remap"** to map other keys (like `Insert` to `Forward Delete`).
4. **Save & Apply**: Click to apply immediately.

---

## Configuration (`config.json`)

Settings are stored at:
```
~/.config/keyboard-remap/config.json
```

```json
{
  "devices": [
    {
      "name": "Lenovo Wireless KB_Mouse KN100 WW",
      "vendor_id": 6127,
      "product_id": 24735,
      "remap": {
        "left_alt": "left_command",
        "left_win": "left_option",
        "right_alt": "left_command",
        "right_win": "left_option",
        "caps_lock": "escape",
        "insert": "forward_delete"
      }
    }
  ]
}
```

---

## Management & Commands

* **View live logs**:
  ```bash
  tail -f ~/Library/Logs/keyboard-remap.log
  ```
* **Stop daemon**:
  ```bash
  launchctl unload ~/Library/LaunchAgents/com.pranay.keyboard-remap.plist
  ```
* **Start daemon**:
  ```bash
  launchctl load ~/Library/LaunchAgents/com.pranay.keyboard-remap.plist
  ```
* **Uninstall**:
  ```bash
  ./uninstall.sh
  ```

---

## License

MIT License. Created by [PranayD1807](https://github.com/PranayD1807).
