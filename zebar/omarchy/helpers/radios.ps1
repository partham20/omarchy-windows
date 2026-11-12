# Radio on/off for the Omarchy Zebar bar.
# Usage: radios.ps1 wifi|bluetooth status|on|off   -> {present, state, error}
param([ValidateSet('wifi', 'bluetooth')][string]$Kind, [ValidateSet('status', 'on', 'off')][string]$Action = 'status')
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot\_winrt.ps1"
$out = [ordered]@{ present = $false; state = 'unknown'; error = $null }
try {
    $r = Get-Radio $(if ($Kind -eq 'wifi') { 'WiFi' } else { 'Bluetooth' })
    if ($r) {
        $out.present = $true
        if ($Action -ne 'status') {
            $target = if ($Action -eq 'on') { [Windows.Devices.Radios.RadioState]::On } else { [Windows.Devices.Radios.RadioState]::Off }
            $res = Await ($r.SetStateAsync($target)) ([Windows.Devices.Radios.RadioAccessStatus])
            if ("$res" -ne 'Allowed') { $out.error = "Windows refused: $res" }
            Start-Sleep -Milliseconds 500
        }
        $out.state = "$($r.State)".ToLower()
    }
} catch { $out.error = $_.Exception.Message }
Emit $out
