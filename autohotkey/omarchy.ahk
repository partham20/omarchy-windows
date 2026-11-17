#Requires AutoHotkey v2.0
#SingleInstance Force
#UseHook                     ; hotkeys use the keyboard hook, so our own Sends never re-trigger them
SetWorkingDir A_ScriptDir
A_MenuMaskKey := "vkE8"      ; stop a Win release after a hotkey from popping the Start menu

TERMINAL      := "wt.exe"
BROWSER       := "msedge.exe"
BROWSER_PRIV  := "--inprivate"
EDITOR        := EnvGet("LOCALAPPDATA") "\Programs\Microsoft VS Code\Code.exe"
FILE_MANAGER  := "explorer.exe"
ACTIVITY      := "taskmgr.exe"
TMUX_CMD      := TERMINAL ' wsl.exe -e bash -lc "tmux attach || tmux new -s Work"'
DOCKER_TUI    := TERMINAL " lazydocker"
PASSWORDS     := EnvGet("LOCALAPPDATA") "\1Password\app\8\1Password.exe"
SIGNAL        := EnvGet("LOCALAPPDATA") "\Programs\signal-desktop\Signal.exe"

URL_CHATGPT   := "https://chatgpt.com"
URL_GROK      := "https://grok.com"
URL_CALENDAR  := "https://calendar.google.com"
URL_EMAIL     := "https://mail.google.com"
URL_YOUTUBE   := "https://youtube.com/"
URL_WHATSAPP  := "https://web.whatsapp.com/"
URL_MESSAGES  := "https://messages.google.com/web/conversations"
URL_PHOTOS    := "https://photos.google.com/"
URL_X         := "https://x.com/"
URL_X_POST    := "https://x.com/compose/post"

LAUNCHER_KEYS := "!{Space}"
SUPPRESS_START_MENU := false

; Hide the Windows taskbar for good (Omarchy has none). Win+Shift+Space
; brings it back when you need it, just like Omarchy's "toggle top bar".
; Set to false to keep the normal taskbar.
HIDE_TASKBAR := true

Launch(target) {
    try Run(target)
    catch
        TrayTip("Could not start:`n" target, "omarchy.ahk", "Iconx")
}

LaunchOrFocus(exe, target) {
    if WinExist("ahk_exe " exe)
        WinActivate
    else
        Launch(target)
}

; Keys that themselves involve Win or the Start menu (Win+V, Win+., Win+H,
; Win+Shift+S ...) misfire if sent while you're still holding Win, so wait
; for Win to be released first.
AfterWin(keys) {
    KeyWait("LWin")
    KeyWait("RWin")
    Send(keys)
}

; ---------------------------------------------------------------------
;  Taskbar hide / show
;  Auto-hide frees the screen space the taskbar reserves; hiding the
;  window stops it sliding up when the mouse touches the screen edge.
; ---------------------------------------------------------------------
TaskbarHidden := false

; Only Explorer's own taskbars. Zebar's tray icons also use a hidden
; window of class Shell_TrayWnd; showing that one pops up a blank white
; "Shell_TrayWnd" window, so it must be left alone.
TASKBAR := "ahk_class Shell_TrayWnd ahk_exe explorer.exe"

TaskbarWindows() {
    DetectHiddenWindows(true)
    wins := []
    for cls in ["Shell_TrayWnd", "Shell_SecondaryTrayWnd"]
        for hwnd in WinGetList("ahk_class " cls " ahk_exe explorer.exe")
            wins.Push(hwnd)
    return wins
}

SetTaskbarAutoHide(on) {
    ; SHAppBarMessage(ABM_SETSTATE, APPBARDATA{lParam = ABS_AUTOHIDE})
    ; Same switch as Settings > Personalization > Taskbar > Automatically hide.
    DetectHiddenWindows(true)
    abd := Buffer(A_PtrSize = 8 ? 48 : 36, 0)
    NumPut("UInt", abd.Size, abd, 0)
    NumPut("Ptr", WinExist(TASKBAR), abd, A_PtrSize)
    NumPut("Ptr", on ? 1 : 0, abd, abd.Size - A_PtrSize)
    DllCall("Shell32\SHAppBarMessage", "UInt", 0xA, "Ptr", abd, "UPtr")
}

HideTaskbar() {
    global TaskbarHidden := true
    for hwnd in TaskbarWindows()
        try WinHide(hwnd)
}

ShowTaskbar() {
    global TaskbarHidden := false
    for hwnd in TaskbarWindows()
        try WinShow(hwnd)
    try WinActivate(TASKBAR)   ; slide it up right away
}

ToggleTaskbar() {
    if TaskbarHidden
        ShowTaskbar()
    else
        HideTaskbar()
}

; Explorer restarts and some notifications bring the taskbar back; while it
; is meant to be hidden, quietly hide it again.
KeepTaskbarHidden() {
    if !TaskbarHidden
        return
    for hwnd in TaskbarWindows() {
        try {
            if WinGetStyle(hwnd) & 0x10000000   ; WS_VISIBLE
                WinHide(hwnd)
        }
    }
}

; Never leave the taskbar stuck hidden if the script exits or is reloaded.
RestoreTaskbar(*) {
    for hwnd in TaskbarWindows()
        try WinShow(hwnd)
}

WebApp(url) => Launch(BROWSER ' --app="' url '"')

Notify(msg) => TrayTip(msg, "Omarchy")

BatteryStatus() {
    ps := Buffer(12, 0)
    DllCall("GetSystemPowerStatus", "Ptr", ps)
    ac   := NumGet(ps, 0, "UChar")
    pct  := NumGet(ps, 2, "UChar")
    secs := NumGet(ps, 4, "UInt")
    if (pct = 255)
        return "No battery detected"
    s := pct "%" (ac = 1 ? " (plugged in)" : "")
    if (ac != 1 && secs != 0xFFFFFFFF)
        s .= "  ·  " (secs // 3600) "h " Mod(secs // 60, 60) "m left"
    return s
}

if SUPPRESS_START_MENU
    Hotkey("~LWin", (*) => Send("{Blind}{vkE8}"))

if HIDE_TASKBAR {
    SetTaskbarAutoHide(true)
    HideTaskbar()
    SetTimer(KeepTaskbarHidden, 1500)
}
OnExit(RestoreTaskbar)

SysMenu := Menu()
SysMenu.Add("&Lock", (*) => DllCall("LockWorkStation"))
SysMenu.Add("S&leep", (*) => DllCall("PowrProf\SetSuspendState", "Int", 0, "Int", 0, "Int", 0))
SysMenu.Add("&Restart", (*) => Run("shutdown.exe /r /t 0"))
SysMenu.Add("Shut &down", (*) => Run("shutdown.exe /s /t 0"))
SysMenu.Add("Sign &out", (*) => Run("shutdown.exe /l"))
SysMenu.Add()
SysMenu.Add("Reload omarchy.ahk", (*) => Reload())

CHEATS := [
    ["Win+Enter", "Terminal"],
    ["Win+Alt+Enter", "Terminal + tmux (WSL)"],
    ["Win+Shift+Enter / Win+Shift+B", "Browser"],
    ["Win+Shift+Alt+B", "Browser (private)"],
    ["Win+Shift+F", "File manager"],
    ["Win+Shift+N", "Editor"],
    ["Win+Shift+D", "lazydocker"],
    ["Win+Shift+M", "Spotify"],
    ["Win+Shift+O", "Obsidian"],
    ["Win+Shift+G", "Signal"],
    ["Win+Shift+/", "1Password"],
    ["Win+Shift+A / C / E / Y / P / X", "ChatGPT / Calendar / Email / YouTube / Photos / X"],
    ["Win+Shift+Alt+A / G / X", "Grok / WhatsApp / X post"],
    ["Win+Space", "Launcher (Flow)"],
    ["Win+Alt+Space", "PowerToys Command Palette"],
    ["Win+Esc", "System menu"],
    ["Win+K", "This cheat sheet"],
    ["Win+Ctrl+L  (Win+L)", "Lock"],
    ["Win+C / V / X", "Universal copy / paste / cut"],
    ["Win+Ctrl+V", "Clipboard history"],
    ["Win+Ctrl+E", "Emoji picker"],
    ["Win+Ctrl+C", "Screenshot (region)"],
    ["Alt+PrtSc", "Screen recording"],
    ["Win+PrtSc / Win+Ctrl+PrtSc", "Color picker / OCR text (PowerToys)"],
    ["Win+Ctrl+A / B / W", "Audio / Bluetooth / Wi-Fi settings"],
    ["Win+Ctrl+N", "Night light settings"],
    ["Win+Ctrl+T", "Activity monitor"],
    ["Win+Ctrl+X", "Dictation"],
    ["Win+Ctrl+Z / Win+Ctrl+Alt+Z", "Zoom in / zoom off"],
    ["Win+Ctrl+Alt+T / B", "Show time / battery"],
    ["Win+Shift+Space", "Show / hide the Windows taskbar"],
    ["--- GlazeWM ---", ""],
    ["Win+W", "Close window"],
    ["Win+Arrows", "Focus"],
    ["Win+Shift+Arrows", "Swap window"],
    ["Win+1..0", "Go to workspace"],
    ["Win+Shift+1..0", "Move window to workspace (follow)"],
    ["Win+Shift+Alt+1..0", "Move window to workspace (silent)"],
    ["Win+Tab / Win+Shift+Tab", "Next / previous workspace"],
    ["Win+Ctrl+Tab", "Last workspace"],
    ["Win+J", "Toggle split direction"],
    ["Win+T", "Toggle floating"],
    ["Win+F / Win+Alt+F", "Fullscreen / maximized"],
    ["Win+O", "Pop out (float + on top)"],
    ["Win+- / Win+=", "Narrower / wider"],
    ["Win+Shift+- / Win+Shift+=", "Shorter / taller"],
    ["Win+Backspace / Win+Ctrl+Backspace", "More transparent / opaque"],
    ["Win+Shift+Alt+Arrows", "Move workspace to monitor"],
    ["Win+Ctrl+R", "Resize mode (Esc exits)"],
    ["Win+Shift+Alt+R / P", "Reload GlazeWM / pause GlazeWM"]
]

ShowCheats() {
    static g := 0
    if g {
        g.Show()
        return
    }
    g := Gui("+AlwaysOnTop -MinimizeBox", "Omarchy keys")
    g.SetFont("s10", "Segoe UI")
    lv := g.Add("ListView", "r28 w620 -Multi", ["Keys", "Action"])
    for row in CHEATS
        lv.Add(, row[1], row[2])
    lv.ModifyCol(1, 260)
    lv.ModifyCol(2, 340)
    g.OnEvent("Escape", (gui) => gui.Hide())
    g.OnEvent("Close", (gui) => gui.Hide())
    g.Show()
}

#Enter::    Launch(TERMINAL)
#!Enter::   Launch(TMUX_CMD)
#+Enter::   Launch(BROWSER)
#+b::       Launch(BROWSER)
#+!b::      Launch(BROWSER " " BROWSER_PRIV)
#+f::       Launch(FILE_MANAGER)
#+n::       Launch(FileExist(EDITOR) ? '"' EDITOR '"' : "code")
#+d::       Launch(DOCKER_TUI)
#+m::       LaunchOrFocus("Spotify.exe", "spotify:")
#+o::       LaunchOrFocus("Obsidian.exe", "obsidian://")
#+g::       LaunchOrFocus("Signal.exe", '"' SIGNAL '"')
#+/::       LaunchOrFocus("1Password.exe", '"' PASSWORDS '"')

#+a::       WebApp(URL_CHATGPT)
#+!a::      WebApp(URL_GROK)
#+c::       WebApp(URL_CALENDAR)
#+e::       WebApp(URL_EMAIL)
#+y::       WebApp(URL_YOUTUBE)
#+!g::      WebApp(URL_WHATSAPP)
#+^g::      WebApp(URL_MESSAGES)
#+p::       WebApp(URL_PHOTOS)
#+x::       WebApp(URL_X)
#+!x::      WebApp(URL_X_POST)

#Space::    AfterWin(LAUNCHER_KEYS)
#+Space::   ToggleTaskbar()
#Escape:: {
    KeyWait("LWin"), KeyWait("RWin")
    SysMenu.Show()
}
#k::        ShowCheats()
#^l::       DllCall("LockWorkStation")

#c::        Send("^{Insert}")
#v::        Send("+{Insert}")
#x::        Send("^x")
#^v::       AfterWin("#v")
#^e::       AfterWin("#.")

#^c::           AfterWin("#+s")
!PrintScreen::  Send("#+r")
#PrintScreen::  AfterWin("#+c")
#^PrintScreen:: AfterWin("#+t")

#^a::       Launch("ms-settings:sound")
#^b::       Launch("ms-settings:bluetooth")
#^w::       Launch("ms-settings:network-wifi")
#^n::       Launch("ms-settings:nightlight")
#^t::       Launch(ACTIVITY)
#^x::       AfterWin("#h")
#^z::       AfterWin("#{NumpadAdd}")
#^!z::      AfterWin("#{Esc}")

#^!t::      Notify(FormatTime(, "dddd HH:mm  ·  d MMMM yyyy"))
#^!b::      Notify(BatteryStatus())
