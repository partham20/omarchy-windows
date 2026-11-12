# Switch the default audio output for the Omarchy Zebar bar.
# Usage: audio.ps1 setdefault <MMDevice id>   -> {ok, error}
param([ValidateSet('setdefault')][string]$Action, [string]$Id)
$utf8 = New-Object System.Text.UTF8Encoding $false
function Emit($o) { $b = $utf8.GetBytes(($o | ConvertTo-Json -Compress)); $s = [Console]::OpenStandardOutput(); $s.Write($b, 0, $b.Length); $s.Flush() }

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
[Guid("f8679f50-850a-41cf-9c72-430f290290c8"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IPolicyConfig {
    int GetMixFormat(); int GetDeviceFormat(); int ResetDeviceFormat(); int SetDeviceFormat();
    int GetProcessingPeriod(); int SetProcessingPeriod(); int GetShareMode(); int SetShareMode();
    int GetPropertyValue(); int SetPropertyValue();
    [PreserveSig] int SetDefaultEndpoint([MarshalAs(UnmanagedType.LPWStr)] string deviceId, int role);
    int SetEndpointVisibility();
}
[ComImport, Guid("870af99c-171d-4f9e-af0d-e63df40c2bc9")] class CPolicyConfigClient {}
public static class OmAudio {
    public static int SetDefault(string id) {
        var pc = (IPolicyConfig)new CPolicyConfigClient();
        int hr = 0;
        for (int role = 0; role < 3; role++) { int r = pc.SetDefaultEndpoint(id, role); if (r != 0) hr = r; }
        return hr;
    }
}
'@
try {
    $hr = [OmAudio]::SetDefault($Id)
    Emit @{ ok = ($hr -eq 0); error = $(if ($hr -ne 0) { ('HRESULT 0x{0:X8}' -f $hr) } else { $null }) }
} catch { Emit @{ ok = $false; error = $_.Exception.Message } }
