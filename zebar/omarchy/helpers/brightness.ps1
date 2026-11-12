# Brightness helper for the Omarchy Zebar bar (internal laptop panel only).
# Usage: brightness.ps1 get | set <0-100>   -> prints JSON {supported, level}
param([ValidateSet('get', 'set')][string]$Action = 'get', [ValidateRange(0, 100)][int]$Level = -1)
$out = [ordered]@{ supported = $false; level = $null }
try {
    if ($Action -eq 'set' -and $Level -ge 0) {
        $m = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop | Select-Object -First 1
        [void](Invoke-CimMethod -InputObject $m -MethodName WmiSetBrightness -Arguments @{ Timeout = [uint32]1; Brightness = [byte]$Level })
    }
    $b = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1
    $out.supported = $true
    $out.level = [int]$b.CurrentBrightness
} catch {}
$out | ConvertTo-Json -Compress
