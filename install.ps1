<#
.SYNOPSIS
  Installs the Omarchy-style setup for Windows 11 (GlazeWM + AutoHotkey v2 + Zebar + Flow Launcher).

.DESCRIPTION
  Safe to run more than once. Existing files are backed up to *.bak before being replaced.
  Does not change Windows settings or the registry.

  -SkipInstall     don't run winget
  -NoStartup       don't create Startup-folder shortcuts
  -NoStart         don't (re)start GlazeWM, Zebar and the AutoHotkey script at the end
#>
param([switch]$SkipInstall, [switch]$NoStartup, [switch]$NoStart)
$ErrorActionPreference = 'Stop'
$repo = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding $false

function Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Backup($path) {
    if (Test-Path -LiteralPath $path -PathType Leaf) { Copy-Item -LiteralPath $path "$path.bak" -Force }
}
function Put($src, $dst) {
    New-Item -ItemType Directory -Force (Split-Path $dst) | Out-Null
    if ((Test-Path $dst) -and ((Get-FileHash $src).Hash -eq (Get-FileHash $dst).Hash)) { return }
    Backup $dst
    Copy-Item -LiteralPath $src $dst -Force
}

# ---------------------------------------------------------------- 1. packages
if (-not $SkipInstall) {
    Step 'Installing packages with winget (already-installed ones are skipped)'
    foreach ($id in 'glzr-io.glazewm', 'AutoHotkey.AutoHotkey', 'Flow-Launcher.Flow-Launcher', 'Microsoft.PowerToys', 'DEVCOM.JetBrainsMonoNerdFont') {
        Write-Host "   $id"
        winget install --id $id -e --accept-package-agreements --accept-source-agreements --silent --disable-interactivity | Out-Null
    }
}

$ahk = @("$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe", "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe") |
    Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $ahk) { throw 'AutoHotkey v2 not found. Install AutoHotkey.AutoHotkey or re-run without -SkipInstall.' }
$glaze = "$env:ProgramFiles\glzr.io\GlazeWM\glazewm.exe"
$zebarExe = "$env:ProgramFiles\glzr.io\Zebar\zebar.exe"

# ---------------------------------------------------------------- 2. files
Step 'Copying GlazeWM config'
Put "$repo\glazewm\config.yaml" "$env:USERPROFILE\.glzr\glazewm\config.yaml"

Step 'Copying AutoHotkey script'
Put "$repo\autohotkey\omarchy.ahk" "$env:USERPROFILE\omarchy\omarchy.ahk"

Step 'Copying Zebar widget pack'
$pack = "$env:USERPROFILE\.glzr\zebar\omarchy"
Get-ChildItem "$repo\zebar\omarchy" -Recurse -File | Where-Object { $_.Extension -notin '.exe', '.bak' } | ForEach-Object {
    Put $_.FullName (Join-Path $pack $_.FullName.Substring("$repo\zebar\omarchy\".Length))
}
# popup.jsx needs this machine's AutoHotkey path.
$jsx = "$pack\popup.jsx"
$text = [IO.File]::ReadAllText($jsx).Replace('__AHK_EXE__', $ahk.Replace('\', '\\'))
[IO.File]::WriteAllText($jsx, $text, $utf8)

Step 'Building the Bluetooth helper (omarchy-bt.exe)'
& "$pack\tools\build.ps1"

# ---------------------------------------------------------------- 3. zpack.json
# Zebar only lets widgets run programs whitelisted here, matched by exact program name and
# an argument regex. Generated per machine because the rules contain absolute paths.
Step 'Writing zpack.json (widget list + shell-command whitelist)'
$P = [regex]::Escape("$pack\")
$PS = '^-NoProfile -ExecutionPolicy Bypass -File ' + $P + 'helpers\\'
$BT = "$pack\tools\omarchy-bt.exe"
function Cmd($program, $regex) { [ordered]@{ program = $program; argsRegex = $regex } }
function Widget($name, $w, $h, $cmds) {
    $isBar = $name -eq 'bar'
    [ordered]@{
        name = $name; htmlPath = "./$name.html"; zOrder = $(if ($isBar) { 'normal' } else { 'top_most' })
        shownInTaskbar = $false; focused = (-not $isBar); resizable = $false; transparent = $false
        includeFiles = @('*.html', '*.css', '*.jsx')
        caching = [ordered]@{ defaultDuration = 604800; rules = @() }
        privileges = [ordered]@{ shellCommands = @($cmds) }
        presets = @([ordered]@{
            name = 'default'; anchor = 'top_left'; offsetX = '0px'; offsetY = $(if ($isBar) { '0px' } else { '30px' })
            width = $w; height = $h; monitorSelection = [ordered]@{ type = $(if ($isBar) { 'all' } else { 'primary' }) }
            dockToEdge = [ordered]@{ enabled = $false; edge = $null; windowMargin = '0px' }
        })
    }
}
$zpack = [ordered]@{
    '$schema' = 'https://github.com/glzr-io/zebar/raw/v3.3.1/resources/zpack-schema.json'
    name = 'omarchy'; version = '1.1.0'
    description = 'Omarchy/Waybar-style top bar for GlazeWM (Tokyo Night) with quick-settings popups.'
    tags = @('topbar', 'glazewm'); previewImages = @(); repositoryUrl = 'https://github.com/partham20/omarchy-windows'
    widgets = @(
        (Widget 'bar' '100%' '26px' @(
            (Cmd 'explorer' '^ms-settings:(bluetooth|network-wifi|network-ethernet|sound|dateandtime|batterysaver)$'),
            (Cmd 'explorer' '^shell:AppsFolder\\Microsoft\.CommandPalette_8wekyb3d8bbwe!App$'),
            (Cmd 'wt' ''), (Cmd 'taskmgr' ''))),
        (Widget 'popup-audio' '300px' '340px' @(
            (Cmd 'powershell' ($PS + 'audio\.ps1 setdefault \{[0-9.]+\}\.\{[0-9a-fA-F-]{36}\}$')),
            (Cmd 'explorer' '^ms-settings:sound$'))),
        (Widget 'popup-clock' '268px' '262px' @()),
        (Widget 'popup-power' '280px' '318px' @(
            (Cmd $ahk ('^' + $P + 'powermenu\.ahk (lock|sleep|restart|shutdown|signout)$')),
            (Cmd 'powershell' ($PS + 'brightness\.ps1 (get|set (100|[1-9]?[0-9]))$')),
            (Cmd 'explorer' '^ms-settings:batterysaver$'))),
        (Widget 'popup-cpu' '290px' '262px' @((Cmd 'taskmgr' ''))),
        (Widget 'popup-wifi' '320px' '430px' @(
            (Cmd 'powershell' ($PS + 'wifi\.ps1 (scan|add|connect [^\r\n]{1,64})$')),
            (Cmd 'powershell' ($PS + 'radios\.ps1 wifi (status|on|off)$')),
            (Cmd 'explorer' '^ms-availablenetworks:$'))),
        (Widget 'popup-bt' '300px' '400px' @(
            (Cmd $BT '^(list|scan 10|(pair|unpair) Bluetooth(LE)?#Bluetooth(LE)?[0-9a-fA-F:]{17}-[0-9a-fA-F:]{17})$'),
            (Cmd 'powershell' ($PS + 'radios\.ps1 bluetooth (status|on|off)$'))))
    )
}
$json = $zpack | ConvertTo-Json -Depth 12
$json = [regex]::Replace($json, '\\u(?<h>[0-9a-fA-F]{4})', { param($m) [string][char][Convert]::ToInt32($m.Groups['h'].Value, 16) })
Backup "$pack\zpack.json"
[IO.File]::WriteAllText("$pack\zpack.json", $json, $utf8)

# ---------------------------------------------------------------- 4. zebar startup
Step 'Pointing Zebar at the omarchy bar'
$settings = "$env:USERPROFILE\.glzr\zebar\settings.json"
Backup $settings
[IO.File]::WriteAllText($settings, @'
{
  "$schema": "https://github.com/glzr-io/zebar/raw/v3.3.1/resources/settings-schema.json",
  "startupConfigs": [
    { "pack": "omarchy", "widget": "bar", "preset": "default" }
  ]
}
'@, $utf8)

# ---------------------------------------------------------------- 5. startup shortcuts
if (-not $NoStartup) {
    Step 'Creating Startup shortcuts (GlazeWM, omarchy.ahk)'
    $startup = [Environment]::GetFolderPath('Startup')
    $sh = New-Object -ComObject WScript.Shell
    $l = $sh.CreateShortcut("$startup\GlazeWM.lnk"); $l.TargetPath = $glaze; $l.Arguments = 'start'; $l.WorkingDirectory = Split-Path $glaze; $l.Save()
    $l = $sh.CreateShortcut("$startup\omarchy.ahk.lnk"); $l.TargetPath = $ahk; $l.Arguments = "`"$env:USERPROFILE\omarchy\omarchy.ahk`""; $l.WorkingDirectory = "$env:USERPROFILE\omarchy"; $l.Save()
}

# ---------------------------------------------------------------- 6. start
if (-not $NoStart) {
    Step 'Starting GlazeWM, Zebar and omarchy.ahk'
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    if (Get-Process glazewm -ErrorAction SilentlyContinue) { & "$env:ProgramFiles\glzr.io\GlazeWM\cli\glazewm.exe" command wm-reload-config | Out-Null }
    else { Start-Process $glaze -ArgumentList start }
    Get-Process zebar -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Seconds 1
    Start-Process $zebarExe
    Start-Process $ahk -ArgumentList "`"$env:USERPROFILE\omarchy\omarchy.ahk`""
}

Write-Host ''
Write-Host 'Done. Two Windows settings to switch off yourself:' -ForegroundColor Green
Write-Host '  - PowerToys Run (clashes with Flow Launcher on Alt+Space)'
Write-Host '  - Settings > System > Multitasking > Snap windows'
Write-Host 'Press Win+K for the key cheat sheet.'
