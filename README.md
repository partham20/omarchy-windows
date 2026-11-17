# omarchy-windows

[Omarchy](https://github.com/basecamp/omarchy)'s keyboard-driven Hyprland + Waybar workflow, rebuilt on **Windows 11** with:

- **[GlazeWM](https://github.com/glzr-io/glazewm)** — tiling window manager, 10 workspaces, Omarchy's window bindings
- **[AutoHotkey v2](https://www.autohotkey.com/)** — app launchers, web apps, system shortcuts, a `Win+K` cheat sheet
- **[Zebar 3.x](https://github.com/glzr-io/zebar)** — a Waybar-style top bar in Tokyo Night, with Omarchy-like quick-settings popups
- **[Flow Launcher](https://www.flowlauncher.com/)** — the app launcher on `Win+Space`

> **Unofficial.** This project is not affiliated with, endorsed by, or connected to Omarchy, Basecamp or 37signals.
> It borrows Omarchy's key bindings and look so the muscle memory carries over to Windows.

## Install

Run in **PowerShell as your normal user** (not as admin):

```powershell
git clone https://github.com/partham20/omarchy-windows.git
cd omarchy-windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\install.ps1
```

The installer is safe to re-run. It:

1. installs GlazeWM, AutoHotkey v2, Flow Launcher, PowerToys and JetBrainsMono Nerd Font with `winget` (skips what's already there; `-SkipInstall` to skip entirely),
2. copies `glazewm/config.yaml` → `%USERPROFILE%\.glzr\glazewm\`, `autohotkey/omarchy.ahk` → `%USERPROFILE%\omarchy\`, and the Zebar pack → `%USERPROFILE%\.glzr\zebar\omarchy\`, backing up anything it replaces to `*.bak`,
3. builds the small Bluetooth helper `omarchy-bt.exe` from source with the C# compiler that ships with Windows (nothing is downloaded),
4. writes the pack's `zpack.json` (the widgets and the exact programs each widget may run) and points Zebar's `settings.json` at the `omarchy/bar` widget,
5. adds Startup-folder shortcuts for GlazeWM and `omarchy.ahk` (`-NoStartup` to skip),
6. starts everything (`-NoStart` to skip).

The installer itself does **not** change Windows settings or the registry. The one Windows setting the setup touches is the taskbar: while `omarchy.ahk` runs, it switches on taskbar auto-hide and hides the taskbar (see [Taskbar](#taskbar)).

### Taskbar

Omarchy has no taskbar, so by default `omarchy.ahk` hides the Windows one:

- **Win+Shift+Space** shows it again (Omarchy's "toggle top bar" key). Press it again to hide it.
- While it's shown, it behaves like a normal auto-hide taskbar: it slides away when you click elsewhere and slides back when the mouse touches the bottom edge.
- The Start menu still opens with the Win key or Ctrl+Esc.
- If the script exits or reloads, the taskbar is shown again, so it can never get stuck hidden.
- To keep the normal taskbar, set `HIDE_TASKBAR := false` at the top of `omarchy.ahk`, and switch auto-hide back off in Settings → Personalization → Taskbar → Taskbar behaviors → Automatically hide the taskbar.

### Switch these off yourself

- **PowerToys Run** — it also wants `Alt+Space`, which Flow Launcher uses. PowerToys Settings → PowerToys Run → off.
- **Snap windows** — Settings → System → Multitasking → Snap windows → off (it fights the tiling WM).

## Key bindings

`Super` in Omarchy is the **Windows key** here. `Win+K` shows all of these on screen.

### Apps

| Omarchy | Windows | Action |
|---|---|---|
| Super+Return | Win+Enter | Terminal (Windows Terminal) |
| Super+Alt+Return | Win+Alt+Enter | Terminal with tmux (WSL) |
| Super+Shift+Return / Super+Shift+B | Win+Shift+Enter / Win+Shift+B | Browser (Edge) |
| Super+Shift+Alt+B | Win+Shift+Alt+B | Private browser window |
| Super+Shift+F | Win+Shift+F | File manager (Explorer) |
| Super+Shift+N | Win+Shift+N | Editor (VS Code) |
| Super+Shift+D | Win+Shift+D | lazydocker |
| Super+Shift+M | Win+Shift+M | Spotify |
| Super+Shift+O | Win+Shift+O | Obsidian |
| Super+Shift+G | Win+Shift+G | Signal |
| Super+Shift+/ | Win+Shift+/ | 1Password |
| Super+Shift+A | Win+Shift+A | ChatGPT (web app) |
| Super+Shift+Alt+A | Win+Shift+Alt+A | Grok (web app) |
| Super+Shift+C | Win+Shift+C | Calendar (web app) |
| Super+Shift+E | Win+Shift+E | Email (web app) |
| Super+Shift+Y | Win+Shift+Y | YouTube (web app) |
| Super+Shift+P | Win+Shift+P | Photos (web app) |
| Super+Shift+X / Super+Shift+Alt+X | Win+Shift+X / Win+Shift+Alt+X | X / new X post |
| Super+Shift+Alt+G | Win+Shift+Alt+G | WhatsApp (web app) |
| Super+Shift+Ctrl+G | Win+Shift+Ctrl+G | Google Messages (web app) |

Web apps open as chromeless Edge `--app` windows. Paths and URLs are at the top of `autohotkey/omarchy.ahk`.

### Menus and system

| Omarchy | Windows | Action |
|---|---|---|
| Super+Space | Win+Space | Launcher (Flow Launcher) |
| Super+Alt+Space | Win+Alt+Space | Command palette (PowerToys Command Palette) |
| Super+Escape | Win+Esc | System menu (lock / sleep / restart / shut down / sign out) |
| Super+K | Win+K | Key cheat sheet |
| Super+Ctrl+L | Win+Ctrl+L (or Win+L) | Lock |
| Super+C / V / X | Win+C / V / X | Universal copy / paste / cut |
| Super+Ctrl+V | Win+Ctrl+V | Clipboard history |
| Super+Ctrl+E | Win+Ctrl+E | Emoji picker |
| Print | Win+Ctrl+C | Screenshot (region) |
| Alt+Print | Alt+PrtSc | Screen recording (Snipping Tool) |
| Super+Print | Win+PrtSc | Color picker (PowerToys) |
| — | Win+Ctrl+PrtSc | Copy text from screen (PowerToys OCR) |
| Super+Ctrl+A / B / W | Win+Ctrl+A / B / W | Audio / Bluetooth / Wi-Fi settings |
| Super+Ctrl+N | Win+Ctrl+N | Night light |
| Super+Ctrl+T | Win+Ctrl+T | Activity monitor (Task Manager) |
| Super+Ctrl+X | Win+Ctrl+X | Dictation |
| Super+Ctrl+Z / Super+Ctrl+Alt+Z | Win+Ctrl+Z / Win+Ctrl+Alt+Z | Zoom in / zoom off (Magnifier) |
| Super+Ctrl+Alt+T / B | Win+Ctrl+Alt+T / B | Show time / battery |
| Super+Shift+Space (toggle top bar) | Win+Shift+Space | Show / hide the Windows taskbar |

### Windows and workspaces (GlazeWM)

| Omarchy | Windows | Action |
|---|---|---|
| Super+W | Win+W | Close window |
| Super+Arrows | Win+Arrows | Move focus |
| Super+Shift+Arrows | Win+Shift+Arrows | Swap window |
| Super+1…0 | Win+1…0 | Go to workspace 1–10 |
| Super+Shift+1…0 | Win+Shift+1…0 | Move window to workspace (and follow) |
| Super+Shift+Alt+1…0 | Win+Shift+Alt+1…0 | Move window to workspace (stay) |
| Super+Tab / Super+Shift+Tab | Win+Tab / Win+Shift+Tab | Next / previous workspace |
| Super+Ctrl+Tab | Win+Ctrl+Tab | Last workspace |
| Super+J | Win+J | Toggle split direction |
| Super+T | Win+T | Toggle floating |
| Super+F / Super+Alt+F | Win+F / Win+Alt+F | Fullscreen / maximised |
| Super+O | Win+O | Pop out (float + always on top) |
| Super+- / Super+= | Win+- / Win+= | Narrower / wider |
| Super+Shift+- / Super+Shift+= | Win+Shift+- / Win+Shift+= | Shorter / taller |
| Super+Backspace | Win+Backspace / Win+Ctrl+Backspace | More transparent / opaque |
| Super+Shift+Alt+Arrows | Win+Shift+Alt+Arrows | Move workspace to another monitor |
| — | Win+Ctrl+R | Resize mode (arrows or hjkl, Esc to leave) |
| — | Win+Shift+Alt+R / P / W / E | Reload / pause / redraw / quit GlazeWM |

### Reserved by Windows

Some combinations can't be taken over by any app: **Win+L** (lock) and **Ctrl+Alt+Del** always go to Windows. Several `Win+…` shortcuts used above normally belong to Windows features (e.g. Win+Tab Task View, Win+Arrows Snap); GlazeWM and AutoHotkey override them while they're running.

## Top bar

A 26px Tokyo Night bar (`#1a1b26` / `#a9b1d6` / accent `#7aa2f7`) in JetBrainsMono Nerd Font:

- **Left:** logo (click: Command Palette, right-click: terminal) and workspaces 1–5 plus any active ones; the focused workspace shows `󱓻`, empty ones are dimmed, click to switch.
- **Centre:** clock (`Thursday 21:37`) and weather.
- **Right:** system tray, Bluetooth, Wi-Fi/Ethernet, volume (scroll to change, right-click to mute), CPU, battery.

Clicking an icon opens an Omarchy-style popup under it. Only one is open at a time, and it closes on Esc, on clicking elsewhere or on clicking the icon again. Right-clicking still opens the matching Windows Settings page.

| Popup | What's in it |
|---|---|
| Clock | Month calendar with ISO week numbers, today highlighted, previous/next month |
| Audio | Volume slider, mute, output-device switcher, media controls for what's playing |
| Power | Battery %, state and time left, brightness slider (laptops), Lock, Sleep, Restart / Shut down / Sign out (each needs a confirm click) |
| CPU | CPU % with a 3-minute sparkline, memory, disks, Task Manager button |
| Wi-Fi | On/off switch, current connection and IP, nearby networks; click a saved network to connect, type a password inline for a new one (wrong password removes the profile again). Enterprise (802.1X) networks are marked and hand over to the Windows network flyout |
| Bluetooth | On/off switch, paired devices with connection state, scan for nearby devices, pair (PIN confirmed inline) and remove |

How the popups work:

- Each popup is its own Zebar widget (`popup-*.html` + `popup.jsx`), opened with `zebar.startWidget` and coordinated with the bar over a `BroadcastChannel`.
- Zebar has no Bluetooth provider and can't switch audio outputs, so `helpers/*.ps1` (WinRT radios, `netsh` for Wi-Fi, the Windows audio policy API, WMI brightness) and `tools/omarchy-bt.exe` (WinRT device pairing) fill those gaps.
- Zebar only lets a widget run programs listed in `zpack.json`, matched by exact program name and an argument regex. Each popup gets only the commands it needs.
- Wi-Fi passwords are passed to the helper on stdin, written to a temporary profile file that is deleted straight after `netsh wlan add profile`, and stored only in the Windows WLAN profile. They're never put on a command line or logged; the popups also drop Zebar's shell-call console logging.

## What isn't mapped

- **Hyprland-only features**: animations, blur, window groups/tabs, scratchpads, and per-window opacity rules beyond GlazeWM's transparency step.
- **Omarchy's theme switcher, menus for installing packages, and screen recording to a file** — Windows equivalents differ too much.
- **Enterprise Wi-Fi** (username + certificate, or SIM-based) — handed to Windows' own network flyout.
- **Audio input switching** and **per-app volume** — the popup only switches outputs.
- App launchers point to default install locations; edit the paths at the top of `autohotkey/omarchy.ahk` if yours differ.

## Layout

```
glazewm/config.yaml          GlazeWM config (gaps, borders, rules, Omarchy bindings)
autohotkey/omarchy.ahk       launchers, web apps, system keys, cheat sheet
zebar/omarchy/               Zebar widget pack
  bar.html, styles.css         the top bar
  popup.jsx, popup.css         all popups (popup-<name>.html picks which one)
  powermenu.ahk                lock / sleep / restart / shut down / sign out
  helpers/*.ps1                Wi-Fi, radios, audio output, brightness
  tools/src/omarchy-bt.cs      Bluetooth list / scan / pair / unpair
  tools/build.ps1              builds omarchy-bt.exe with the built-in csc.exe
install.ps1                  installer (also generates zpack.json)
```

## Credits

- Key bindings, Waybar layout and overall design: **[basecamp/omarchy](https://github.com/basecamp/omarchy)** (MIT).
- Colours: Tokyo Night.
- Built on [GlazeWM](https://github.com/glzr-io/glazewm), [Zebar](https://github.com/glzr-io/zebar), [AutoHotkey](https://www.autohotkey.com/), [Flow Launcher](https://www.flowlauncher.com/) and [PowerToys](https://github.com/microsoft/PowerToys).

## License

MIT © partham20
