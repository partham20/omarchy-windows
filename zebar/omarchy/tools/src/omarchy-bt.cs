// omarchy-bt: tiny Bluetooth helper for the Omarchy Zebar bar.
// Every output line is one JSON object (UTF-8).
//   omarchy-bt list              -> {"devices":[...]}   paired devices + connected state
//   omarchy-bt scan [seconds]    -> {"devices":[...]}   nearby unpaired devices
//   omarchy-bt pair <id>         -> may print {"event":"confirm","pin":"123456"} and read "yes"/"no" from stdin,
//                                   {"event":"providepin"} and read a PIN, {"event":"displaypin","pin":"..."};
//                                   ends with {"done":true,"ok":..,"status":".."}
//   omarchy-bt unpair <id>       -> {"done":true,"ok":..,"status":".."}
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using Windows.Devices.Bluetooth;
using Windows.Devices.Enumeration;
using Windows.Foundation;

static class Program
{
    const string Classic = "{e0cbf06c-cd8b-4647-bb8a-263b43f0f974}";
    const string Le = "{bb7bb05e-5972-42b5-94fc-76eaa7084d49}";
    static readonly string[] Props = { "System.Devices.Aep.IsPaired", "System.Devices.Aep.IsConnected", "System.Devices.Aep.ProtocolId" };
    static Stream stdout = Console.OpenStandardOutput();
    static StreamReader stdin = new StreamReader(Console.OpenStandardInput(), new UTF8Encoding(false));

    static string J(string s)
    {
        if (s == null) return "null";
        var sb = new StringBuilder("\"");
        foreach (var c in s)
        {
            switch (c)
            {
                case '"': sb.Append("\\\""); break;
                case '\\': sb.Append("\\\\"); break;
                case '\n': sb.Append("\\n"); break;
                case '\r': sb.Append("\\r"); break;
                case '\t': sb.Append("\\t"); break;
                default: if (c < 0x20) sb.AppendFormat("\\u{0:x4}", (int)c); else sb.Append(c); break;
            }
        }
        return sb.Append('"').ToString();
    }
    static T Wait<T>(IAsyncOperation<T> op)
    {
        var m = new ManualResetEvent(false);
        op.Completed = (a, s) => m.Set();
        m.WaitOne();
        if (op.Status == AsyncStatus.Error) throw op.ErrorCode;
        return op.GetResults();
    }
    static string B(bool b) { return b ? "true" : "false"; }
    static readonly object outLock = new object();
    static void Emit(string json)
    {
        lock (outLock)
        {
            var bytes = new UTF8Encoding(false).GetBytes(json + "\n");
            stdout.Write(bytes, 0, bytes.Length); stdout.Flush();
        }
    }
    static string Dev(string id, string name, bool paired, bool connected, string kind)
    {
        return "{\"id\":" + J(id) + ",\"name\":" + J(name) + ",\"paired\":" + B(paired) + ",\"connected\":" + B(connected) + ",\"kind\":" + J(kind) + "}";
    }
    static bool Prop(DeviceInformation i, string key)
    {
        object v; return i.Properties.TryGetValue(key, out v) && v is bool && (bool)v;
    }
    static string Kind(DeviceInformation i)
    {
        return i.Id.StartsWith("BluetoothLE", StringComparison.OrdinalIgnoreCase) ? "le" : "classic";
    }

    static int Main(string[] args)
    {
        try
        {
            var action = args.Length > 0 ? args[0] : "list";
            if (action == "list") return List();
            if (action == "scan") return Scan(args.Length > 1 ? int.Parse(args[1]) : 10);
            if (action == "pair" && args.Length > 1) return Pair(args[1]);
            if (action == "unpair" && args.Length > 1) return Unpair(args[1]);
            Emit("{\"done\":true,\"ok\":false,\"error\":\"usage\"}");
            return 2;
        }
        catch (Exception e)
        {
            Emit("{\"done\":true,\"ok\":false,\"error\":" + J(e.GetBaseException().Message) + ",\"devices\":[]}");
            return 1;
        }
    }

    static string Aqs(bool paired)
    {
        return "(System.Devices.Aep.ProtocolId:=\"" + Classic + "\" OR System.Devices.Aep.ProtocolId:=\"" + Le + "\") AND System.Devices.Aep.IsPaired:=System.StructuredQueryType.Boolean#" + (paired ? "True" : "False");
    }

    // Paired devices come from the device cache quickly via a watcher's initial enumeration.
    static List<DeviceInformation> Watch(string aqs, int seconds, bool stopOnEnumerated)
    {
        var found = new Dictionary<string, DeviceInformation>();
        var done = new ManualResetEvent(false);
        var w = DeviceInformation.CreateWatcher(aqs, Props, DeviceInformationKind.AssociationEndpoint);
        w.Added += (s, i) => { lock (found) { found[i.Id] = i; } };
        w.Updated += (s, u) => { lock (found) { DeviceInformation d; if (found.TryGetValue(u.Id, out d)) d.Update(u); } };
        w.Removed += (s, u) => { lock (found) { found.Remove(u.Id); } };
        w.EnumerationCompleted += (s, o) => { if (stopOnEnumerated) done.Set(); };
        w.Start();
        done.WaitOne(TimeSpan.FromSeconds(seconds));
        try { w.Stop(); } catch { }
        lock (found) { return found.Values.ToList(); }
    }

    static int List()
    {
        // Fast path: the paired-device selectors read from the device cache (no radio inquiry).
        var rows = new List<Tuple<string, string, bool, string>>();
        var seen = new HashSet<string>();
        foreach (var le in new[] { false, true })
        {
            var sel = le ? BluetoothLEDevice.GetDeviceSelectorFromPairingState(true) : BluetoothDevice.GetDeviceSelectorFromPairingState(true);
            foreach (var i in Wait(DeviceInformation.FindAllAsync(sel)))
            {
                if (string.IsNullOrEmpty(i.Name) || !seen.Add(i.Name)) continue;
                bool connected = false; string aepId = i.Id;
                try
                {
                    if (le)
                    {
                        using (var d = Wait(BluetoothLEDevice.FromIdAsync(i.Id)))
                            if (d != null) { connected = d.ConnectionStatus == BluetoothConnectionStatus.Connected; aepId = d.DeviceInformation.Id; }
                    }
                    else
                    {
                        using (var d = Wait(BluetoothDevice.FromIdAsync(i.Id)))
                            if (d != null) { connected = d.ConnectionStatus == BluetoothConnectionStatus.Connected; aepId = d.DeviceInformation.Id; }
                    }
                }
                catch { }
                rows.Add(Tuple.Create(aepId, i.Name, connected, le ? "le" : "classic"));
            }
        }
        var devs = rows.OrderByDescending(r => r.Item3).ThenBy(r => r.Item2).Select(r => Dev(r.Item1, r.Item2, true, r.Item3, r.Item4));
        Emit("{\"devices\":[" + string.Join(",", devs) + "]}");
        return 0;
    }

    static int Scan(int seconds)
    {
        var devs = Watch(Aqs(false), Math.Max(3, Math.Min(seconds, 30)), false)
            .Where(i => !string.IsNullOrEmpty(i.Name))
            .GroupBy(i => i.Name).Select(g => g.First())
            .OrderBy(i => i.Name)
            .Select(i => Dev(i.Id, i.Name, false, false, Kind(i)));
        Emit("{\"devices\":[" + string.Join(",", devs) + "]}");
        return 0;
    }

    static DeviceInformation Get(string id)
    {
        return Wait(DeviceInformation.CreateFromIdAsync(id, Props, DeviceInformationKind.AssociationEndpoint));
    }

    static int Pair(string id)
    {
        var di = Get(id);
        var custom = di.Pairing.Custom;
        custom.PairingRequested += (s, e) =>
        {
            var deferral = e.GetDeferral();
            try
            {
                switch (e.PairingKind)
                {
                    case DevicePairingKinds.ConfirmOnly:
                        e.Accept();
                        break;
                    case DevicePairingKinds.DisplayPin:
                        Emit("{\"event\":\"displaypin\",\"pin\":" + J(e.Pin) + "}");
                        e.Accept();
                        break;
                    case DevicePairingKinds.ConfirmPinMatch:
                        Emit("{\"event\":\"confirm\",\"pin\":" + J(e.Pin) + "}");
                        var answer = (stdin.ReadLine() ?? "").Trim().ToLowerInvariant();
                        if (answer == "yes") e.Accept();
                        break;
                    case DevicePairingKinds.ProvidePin:
                        Emit("{\"event\":\"providepin\"}");
                        var pin = (stdin.ReadLine() ?? "").Trim();
                        if (pin.Length > 0) e.Accept(pin);
                        break;
                }
            }
            finally { deferral.Complete(); }
        };
        var kinds = DevicePairingKinds.ConfirmOnly | DevicePairingKinds.DisplayPin | DevicePairingKinds.ConfirmPinMatch | DevicePairingKinds.ProvidePin;
        var res = Wait(custom.PairAsync(kinds, DevicePairingProtectionLevel.Default));
        var st = res.Status.ToString();
        Emit("{\"done\":true,\"ok\":" + B(res.Status == DevicePairingResultStatus.Paired || res.Status == DevicePairingResultStatus.AlreadyPaired) + ",\"status\":" + J(st) + "}");
        return 0;
    }

    static int Unpair(string id)
    {
        var di = Get(id);
        var res = Wait(di.Pairing.UnpairAsync());
        Emit("{\"done\":true,\"ok\":" + B(res.Status == DeviceUnpairingResultStatus.Unpaired || res.Status == DeviceUnpairingResultStatus.AlreadyUnpaired) + ",\"status\":" + J(res.Status.ToString()) + "}");
        return 0;
    }
}
