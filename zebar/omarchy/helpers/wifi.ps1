# Wi-Fi helper for the Omarchy Zebar bar (wraps netsh; SSIDs come back as UTF-8 JSON).
# Usage: wifi.ps1 scan            -> {current, networks:[{ssid, signal, auth, saved, enterprise, open}]}
#        wifi.ps1 connect <name>  -> {ok, state, message}      (saved profile)
#        wifi.ps1 add             -> reads ONE JSON line from stdin: {ssid, auth, password}
#                                    creates a temporary WLAN profile, connects, removes it again on failure.
# Passwords are only ever read from stdin, written to a temp XML that is deleted immediately
# after `netsh wlan add profile`, and never echoed or logged.
param([ValidateSet('scan', 'connect', 'add')][string]$Action = 'scan', [string]$Name = '', [switch]$NoConnect)

# Read the request from stdin (raw UTF-8) before attaching a console below.
$stdinLine = $null
if ($Action -eq 'add') {
    $in = [Console]::OpenStandardInput()
    $ms = New-Object System.IO.MemoryStream
    $b = New-Object byte[] 1
    while ($in.Read($b, 0, 1) -eq 1) { if ($b[0] -eq 10) { break }; $ms.WriteByte($b[0]) }
    $stdinLine = (New-Object System.Text.UTF8Encoding $false).GetString($ms.ToArray()).Trim([char]0xFEFF, "`r", ' ')
    $ms.Dispose()
}

Add-Type -Namespace OmWifi -Name K -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern bool AllocConsole();
[DllImport("kernel32.dll")] public static extern IntPtr GetConsoleWindow();
[DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
'@
# Zebar spawns us without a console; attach a hidden one so netsh honours the UTF-8 code page.
if ([OmWifi.K]::GetConsoleWindow() -eq [IntPtr]::Zero) {
    [void][OmWifi.K]::AllocConsole()
    [void][OmWifi.K]::ShowWindow([OmWifi.K]::GetConsoleWindow(), 0)
}
$utf8 = New-Object System.Text.UTF8Encoding $false
try { [Console]::OutputEncoding = $utf8 } catch {}
$OutputEncoding = $utf8

function Emit($obj) {
    $bytes = $utf8.GetBytes(($obj | ConvertTo-Json -Compress -Depth 5))
    $s = [Console]::OpenStandardOutput(); $s.Write($bytes, 0, $bytes.Length); $s.Flush()
}
function Field($line) { ($line -split ':', 2)[1].Trim() }

function Get-Current {
    $iface = netsh wlan show interfaces
    $state = $iface | Where-Object { $_ -match '^\s+State\s+:' } | Select-Object -First 1
    if (-not $state) { return $null }
    $o = [ordered]@{ state = (Field $state); ssid = $null; signal = 0 }
    $ssidLine = $iface | Where-Object { $_ -match '^\s+SSID\s+:' } | Select-Object -First 1
    $sigLine = $iface | Where-Object { $_ -match '^\s+Signal\s+:' } | Select-Object -First 1
    if ($ssidLine) { $o.ssid = Field $ssidLine }
    if ($sigLine) { $o.signal = [int]((Field $sigLine) -replace '[^0-9]', '') }
    $o
}

function Wait-Connected($ssid, [int]$seconds = 20) {
    $deadline = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Milliseconds 1000
        $c = Get-Current
        if ($c -and $c.state -eq 'connected' -and $c.ssid -eq $ssid) { return $true }
    }
    return $false
}

function Connect-Profile($name) {
    $msg = ((netsh wlan connect name="$name" ssid="$name") -join ' ').Trim()
    if ($LASTEXITCODE -ne 0) { return @{ ok = $false; state = 'failed'; message = $msg } }
    if (Wait-Connected $name) { return @{ ok = $true; state = 'connected'; message = $msg } }
    return @{ ok = $false; state = 'failed'; message = 'Could not connect (wrong password or out of range).' }
}

function Esc([string]$s) { [System.Security.SecurityElement]::Escape($s) }

switch ($Action) {
    'connect' {
        if (-not $Name) { Emit @{ ok = $false; state = 'failed'; message = 'No network name' }; break }
        Emit (Connect-Profile $Name)
    }
    'add' {
        try { $req = $stdinLine | ConvertFrom-Json } catch { $req = $null }
        $stdinLine = $null
        if (-not $req) { Emit @{ ok = $false; state = 'failed'; message = 'Bad request' }; break }
        $ssid = [string]$req.ssid; $auth = [string]$req.auth; $pw = [string]$req.password
        $req = $null
        if (-not $ssid) { Emit @{ ok = $false; state = 'failed'; message = 'No SSID' }; break }
        switch -Regex ($auth) {
            '^Open$'            { $a = 'open';    $e = 'none'; break }
            'WPA3-Personal'     { $a = 'WPA3SAE'; $e = 'AES';  break }
            'WPA2-Personal'     { $a = 'WPA2PSK'; $e = 'AES';  break }
            '^WPA-Personal'     { $a = 'WPAPSK';  $e = 'AES';  break }
            default             { $a = $null }
        }
        if (-not $a) { Emit @{ ok = $false; state = 'unsupported'; message = "Unsupported security: $auth" }; break }
        if ($a -ne 'open' -and $pw.Length -lt 8) { Emit @{ ok = $false; state = 'badpassword'; message = 'Password must be at least 8 characters.' }; break }

        $hex = -join ($utf8.GetBytes($ssid) | ForEach-Object { $_.ToString('X2') })
        $keyXml = if ($a -eq 'open') { '' } else {
            "<sharedKey><keyType>passPhrase</keyType><protected>false</protected><keyMaterial>$(Esc $pw)</keyMaterial></sharedKey>" }
        $xml = @"
<?xml version="1.0"?>
<WLANProfile xmlns="http://www.microsoft.com/networking/WLAN/profile/v1">
  <name>$(Esc $ssid)</name>
  <SSIDConfig><SSID><hex>$hex</hex><name>$(Esc $ssid)</name></SSID></SSIDConfig>
  <connectionType>ESS</connectionType>
  <connectionMode>auto</connectionMode>
  <MSM><security>
    <authEncryption><authentication>$a</authentication><encryption>$e</encryption><useOneX>false</useOneX></authEncryption>
    $keyXml
  </security></MSM>
</WLANProfile>
"@
        $pw = $null; $keyXml = $null
        $tmp = Join-Path $env:TEMP ("om-wlan-" + [guid]::NewGuid().ToString('N') + ".xml")
        try {
            [IO.File]::WriteAllText($tmp, $xml, $utf8)
            $xml = $null
            $addMsg = ((netsh wlan add profile filename="$tmp" user=current) -join ' ').Trim()
            $addOk = ($LASTEXITCODE -eq 0)
        } finally {
            Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
        }
        if (-not $addOk) { Emit @{ ok = $false; state = 'failed'; message = $addMsg }; break }
        if ($NoConnect) { Emit @{ ok = $true; state = 'added'; message = $addMsg }; break }
        $r = Connect-Profile $ssid
        if (-not $r.ok) {
            [void](netsh wlan delete profile name="$ssid")
            $r.state = 'badpassword'
            $r.message = 'Could not connect - wrong password? The profile was removed.'
        }
        Emit $r
    }
    default {
        # Ask Windows for a fresh scan (netsh only reports the cached list).
        try {
            Add-Type -Namespace OmWifi -Name Scan -MemberDefinition @'
[DllImport("wlanapi.dll")] static extern int WlanOpenHandle(uint v, IntPtr r, out uint neg, out IntPtr h);
[DllImport("wlanapi.dll")] static extern int WlanEnumInterfaces(IntPtr h, IntPtr r, out IntPtr list);
[DllImport("wlanapi.dll")] static extern int WlanScan(IntPtr h, ref Guid g, IntPtr ssid, IntPtr ie, IntPtr r);
[DllImport("wlanapi.dll")] static extern void WlanFreeMemory(IntPtr p);
[DllImport("wlanapi.dll")] static extern int WlanCloseHandle(IntPtr h, IntPtr r);
public static int ScanAll() {
    uint neg; IntPtr h; if (WlanOpenHandle(2, IntPtr.Zero, out neg, out h) != 0) return 0;
    int n = 0; IntPtr list;
    if (WlanEnumInterfaces(h, IntPtr.Zero, out list) == 0) {
        int count = Marshal.ReadInt32(list);
        for (int i = 0; i < count; i++) {
            // WLAN_INTERFACE_INFO_LIST: dwNumberOfItems, dwIndex, then WLAN_INTERFACE_INFO[] (GUID + 256 WCHAR + state) = 532 bytes each
            var g = (Guid)Marshal.PtrToStructure(new IntPtr(list.ToInt64() + 8 + i * 532), typeof(Guid));
            if (WlanScan(h, ref g, IntPtr.Zero, IntPtr.Zero, IntPtr.Zero) == 0) n++;
        }
        WlanFreeMemory(list);
    }
    WlanCloseHandle(h, IntPtr.Zero);
    return n;
}
'@
            if ([OmWifi.Scan]::ScanAll() -gt 0) { Start-Sleep -Milliseconds 3500 }
        } catch {}
        $saved = @(netsh wlan show profiles | Where-Object { $_ -match '^\s+All User Profile\s+:' } | ForEach-Object { Field $_ })
        $nets = @{}
        $cur = $null
        foreach ($line in (netsh wlan show networks mode=bssid)) {
            if ($line -match '^SSID \d+ : ?(.*)$') {
                $ssid = $Matches[1].Trim()
                $cur = $null
                if (-not $ssid) { continue }
                if ($nets.ContainsKey($ssid)) { $cur = $nets[$ssid] }
                else { $cur = [ordered]@{ ssid = $ssid; signal = 0; auth = ''; saved = ($saved -contains $ssid); enterprise = $false; open = $false }; $nets[$ssid] = $cur }
            } elseif ($cur -and $line -match '^\s+Authentication\s+:') {
                $cur.auth = Field $line
                $cur.enterprise = ($cur.auth -match 'Enterprise')
                $cur.open = ($cur.auth -eq 'Open')
            } elseif ($cur -and $line -match '^\s+Signal\s+:') {
                $s = [int]((Field $line) -replace '[^0-9]', '')
                if ($s -gt $cur.signal) { $cur.signal = $s }
            }
        }
        Emit ([ordered]@{ current = (Get-Current); networks = @($nets.Values | Sort-Object { -$_.signal }) })
    }
}
