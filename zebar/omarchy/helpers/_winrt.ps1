# Shared WinRT plumbing for the Omarchy Zebar helpers (dot-sourced).
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$script:asTaskOp = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
function Await($op, [Type]$type, [int]$timeoutMs = 15000) {
    $task = $script:asTaskOp.MakeGenericMethod($type).Invoke($null, @($op))
    if (-not $task.Wait($timeoutMs)) { throw "Timed out" }
    $task.Result
}
$script:utf8 = New-Object System.Text.UTF8Encoding $false
function Emit($obj) {
    $bytes = $script:utf8.GetBytes(($obj | ConvertTo-Json -Compress -Depth 6))
    $s = [Console]::OpenStandardOutput(); $s.Write($bytes, 0, $bytes.Length); $s.Flush()
}
[void][Windows.Devices.Radios.Radio, Windows.System.Devices, ContentType = WindowsRuntime]
function Get-Radio([string]$kind) {
    [void](Await ([Windows.Devices.Radios.Radio]::RequestAccessAsync()) ([Windows.Devices.Radios.RadioAccessStatus]))
    $radios = Await ([Windows.Devices.Radios.Radio]::GetRadiosAsync()) ([System.Collections.Generic.IReadOnlyList[Windows.Devices.Radios.Radio]])
    $radios | Where-Object { "$($_.Kind)" -eq $kind } | Select-Object -First 1
}
