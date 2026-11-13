# macOS Keyboard Remap Daemon & Settings UI

A lightweight, native macOS solution to persistently remap any modifier or custom key (e.g. swapping Alt $\leftrightarrow$ Command, Windows $\leftrightarrow$ Option, F-keys, Navigation, or Media keys on external keyboards) so settings **never reset** when you disconnect and reconnect your keyboard, turn it off/on, or wake your Mac from sleep.

---

## Features

* **Auto-Detect Keyboards**: Automatically detects all connected USB, Bluetooth, and built-in keyboards.
* **Device Selection**: Target any specific keyboard without affecting your built-in MacBook keyboard.
* **Remap ANY Key**:
  * **Quick Modifiers**: One-click preset to swap Alt $\leftrightarrow$ Cmd and Win $\leftrightarrow$ Opt.
  * **Custom Remappings**: Map any key to any key (e.g. `F1` $\rightarrow$ `Play/Pause`, `Insert` $\rightarrow$ `Forward Delete`, `Caps Lock` $\rightarrow$ `Escape`, etc.).
* **Persistent Across Reconnects**: Uses kernel-level `IOHIDManager` event listeners to re-apply mappings the exact millisecond a keyboard connects or wakes from sleep.
* **Native Settings UI**: Clean macOS SwiftUI app with an interactive device picker, custom remap rules builder, and live daemon status.
* **Live JSON Hot-Reload**: Changes to `config.json` apply instantly without restarting.
* **Zero Resource Footprint**: Event-driven daemon (~5 MB RAM, 0% CPU).

---

## Quick Start / Installation

```bash
cd keyboard-remap
./install.sh
```

---

## Settings UI

Launch the UI anytime using:
```bash
keyboard-remap-ui
```
*(or search **Keyboard Remap** in Spotlight with `Cmd + Space`)*

### Inside the UI:
1. **Select Device**: Choose your keyboard from the dropdown.
2. **Quick Modifiers**: Use the standard rows or click **"Swap Alt ↔ Cmd, Win ↔ Opt"** for an instant PC-to-Mac layout.
3. **Custom Key Remappings**: Click **"+ Add Remap"** to map any arbitrary key:
   - Modifiers (`Command`, `Option`, `Control`, `Shift`, `Caps Lock`)
   - Function keys (`F1` - `F12`)
   - Navigation (`Home`, `End`, `Page Up`, `Page Down`, `Insert`, `Arrows`)
   - Editing (`Escape`, `Return`, `Backspace`, `Forward Delete`)
   - Media controls (`Volume Up/Down`, `Mute`, `Play/Pause`, `Next/Prev Track`)
4. **Save & Apply**: Saves directly to `config.json` and updates the keyboard immediately.

---

## Configuration File

Settings are saved in:
```
~/.config/keyboard-remap/config.json
```

### Example `config.json` with Custom Key Remaps
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
        "right_alt": "right_command",
        "right_win": "right_option",
        "caps_lock": "escape",
        "f1": "play_pause",
        "insert": "forward_delete"
      }
    }
  ]
}
```

---

## Management

* **View Live Logs**:
  ```bash
  tail -f ~/Library/Logs/keyboard-remap.log
  ```
* **Stop / Restart Service**:
  ```bash
  # Stop
  launchctl unload ~/Library/LaunchAgents/com.pranay.keyboard-remap.plist

  # Start
  launchctl load ~/Library/LaunchAgents/com.pranay.keyboard-remap.plist
  ```
* **Uninstall**:
  ```bash
  ./uninstall.sh
  ```
