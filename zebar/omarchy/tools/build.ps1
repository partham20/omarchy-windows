# Builds tools\omarchy-bt.exe from tools\src\omarchy-bt.cs using the C# compiler that ships with
# Windows (.NET Framework 4.x) and the WinRT metadata in System32. Nothing is downloaded.
$ErrorActionPreference = 'Stop'
$fw = "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319"
$wm = "$env:WINDIR\System32\WinMetadata"
$src = Join-Path $PSScriptRoot 'src\omarchy-bt.cs'
$out = Join-Path $PSScriptRoot 'omarchy-bt.exe'
if (-not (Test-Path "$fw\csc.exe")) { throw "csc.exe not found in $fw" }
& "$fw\csc.exe" /nologo /target:exe /optimize /out:"$out" `
    /r:"$wm\Windows.Devices.winmd" /r:"$wm\Windows.Foundation.winmd" `
    /r:"$fw\System.Runtime.dll" /r:"$fw\System.Runtime.InteropServices.WindowsRuntime.dll" `
    "$src"
if ($LASTEXITCODE -ne 0) { throw "omarchy-bt build failed" }
Write-Host "Built $out"
