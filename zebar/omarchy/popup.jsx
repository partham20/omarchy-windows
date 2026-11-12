// Shared code for every Omarchy quick-settings popup. Each popup-*.html sets
// window.POPUP to its mode and loads this file through Babel.
import React, { useState, useEffect, useRef } from 'https://esm.sh/react@18.3.1';
import { createRoot } from 'https://esm.sh/react-dom@18.3.1/client';
import * as zebar from 'https://esm.sh/zebar@3.3.1';

const MODE = window.POPUP;
// The pack folder is wherever this widget's HTML lives (no hard-coded user paths).
const PACK = zebar.currentWidget().htmlPath.replace(/[\\/][^\\/]+$/, '');
const HELPERS = PACK + '\\helpers\\';
const BT_EXE = PACK + '\\tools\\omarchy-bt.exe';
// Filled in by install.ps1 with the AutoHotkey v2 path on this machine.
const AHK = '__AHK_EXE__';

const G = {
  vol: ['\u{F075F}', '\u{F057F}', '\u{F0580}', '\u{F057E}'],
  speaker: '\u{F04C3}', check: '\u{F012C}', prev: '\u{F04AE}', next: '\u{F04AD}', play: '\u{F040A}', pause: '\u{F03E4}',
  music: '\u{F075A}', cal: '\u{F00ED}', left: '\u{F0141}', right: '\u{F0142}',
  bat: '\u{F0079}', charging: '\u{F0084}', sun: '\u{F00DF}', lock: '\u{F033E}', sleep: '\u{F04B2}',
  restart: '\u{F0709}', power: '\u{F0425}', logout: '\u{F0343}', cpu: '\u{F035B}', mem: '\u{F035B}', disk: '\u{F02CA}',
  wifi: ['\u{F092F}', '\u{F091F}', '\u{F0922}', '\u{F0925}', '\u{F0928}'], wifiOff: '\u{F092E}', padlock: '\u{F033E}',
  refresh: '\u{F0450}', bt: '\u{F00AF}', btOn: '\u{F00B1}', btOff: '\u{F00B2}', link: '\u{F0337}', close: '\u{F0156}',
};

// ---------- popup lifecycle: one at a time, Esc / blur / re-click closes ----------
const chan = new BroadcastChannel('omarchy');
const widget = zebar.currentWidget();
let closing = false;
function closePopup() {
  if (closing) return;
  closing = true;
  chan.postMessage({ t: 'closed', mode: MODE, at: Date.now() });
  widget.close();
}
chan.onmessage = e => {
  const m = e.data || {};
  if (m.t === 'close' && (!m.mode || m.mode === MODE)) closePopup();
  if (m.t === 'opening' && m.mode !== MODE) closePopup();
};
chan.postMessage({ t: 'opened', mode: MODE });
window.addEventListener('keydown', e => { if (e.key === 'Escape') closePopup(); });
// Pause blur-to-close while a native dialog we triggered might steal focus.
let holdOpen = false;
window.addEventListener('blur', () => {
  setTimeout(() => { if (!document.hasFocus() && !holdOpen) closePopup(); }, 150);
});
try { widget.tauriWindow.setFocus().catch(() => {}); } catch {}

// ---------- shell helpers ----------
function parseLast(s) {
  const lines = (s || '').trim().split(/\r?\n/).filter(Boolean);
  for (let i = lines.length - 1; i >= 0; i--) { try { return JSON.parse(lines[i]); } catch {} }
  return null;
}
async function ps(script, ...args) {
  try {
    const r = await zebar.shellExec('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', HELPERS + script, ...args]);
    return parseLast(r.stdout) ?? { error: (r.stderr || 'no output').trim().slice(0, 200) };
  } catch (err) {
    return { error: String(err) };
  }
}
async function run(program, args) {
  try { await zebar.shellExec(program, args); } catch (err) { console.error('run failed', program, err); }
}
const openSettings = page => run('explorer', `ms-settings:${page}`);

function useProviders(config) {
  const [group] = useState(() => zebar.createProviderGroup(config));
  const [out, setOut] = useState(group.outputMap);
  useEffect(() => { group.onOutput(() => setOut({ ...group.outputMap })); }, []);
  return out;
}

function Frame({ icon, title, right, children }) {
  return (
    <div className="pop">
      <div className="head">
        <span className="icon">{icon}</span>
        <span className="title">{title}</span>
        {right}
      </div>
      <div className="body">{children}</div>
    </div>
  );
}

function Toggle({ on, busy, onChange, title }) {
  return <button className={`toggle ${on ? 'on' : ''}`} disabled={busy} title={title} onClick={() => onChange(!on)} />;
}

const pct = n => `${Math.round(n)}%`;
function fmtBytes(b) {
  if (b == null) return '?';
  const u = ['B', 'KB', 'MB', 'GB', 'TB']; let i = 0;
  while (b >= 1024 && i < u.length - 1) { b /= 1024; i++; }
  return `${b.toFixed(b >= 100 || i === 0 ? 0 : 1)} ${u[i]}`;
}
function fmtDuration(ms) {
  if (!ms || ms <= 0) return null;
  const m = Math.round(ms / 60000);
  return `${Math.floor(m / 60)}h ${m % 60}m`;
}

// ---------- audio ----------
function AudioPopup() {
  const out = useProviders({ audio: { type: 'audio' }, media: { type: 'media' } });
  const audio = out.audio;
  const dev = audio?.defaultPlaybackDevice;
  const [drag, setDrag] = useState(null);
  const [msg, setMsg] = useState(null);
  const last = useRef(0);

  const setVolume = v => {
    setDrag(v);
    const now = Date.now();
    if (now - last.current > 40) { last.current = now; audio?.setVolume(v, { deviceId: dev?.deviceId }); }
  };
  const commitVolume = v => { audio?.setVolume(v, { deviceId: dev?.deviceId }); setTimeout(() => setDrag(null), 300); };

  const switchDevice = async d => {
    if (d.isDefaultPlayback) return;
    setMsg({ cls: '', text: `Switching to ${d.name}…` });
    const r = await ps('audio.ps1', 'setdefault', d.deviceId);
    setMsg(r?.ok ? { cls: 'ok', text: `Output: ${d.name}` } : { cls: 'err', text: `Couldn't switch: ${r?.error ?? 'unknown error'}` });
  };

  const vol = drag ?? dev?.volume ?? 0;
  const volIcon = !dev || dev.isMuted || vol === 0 ? G.vol[0] : vol < 33 ? G.vol[1] : vol < 66 ? G.vol[2] : G.vol[3];
  const session = out.media?.currentSession;
  const mopt = session ? { sessionId: session.sessionId } : undefined;

  return (
    <Frame icon={volIcon} title="Audio" right={<button className="iconbtn" title="Sound settings" onClick={() => openSettings('sound')}>{G.link}</button>}>
      {!audio && <div className="msg">Audio provider not available.</div>}
      {audio && (
        <>
          <div className="section">
            <div className="row">
              <button className="iconbtn" title={dev?.isMuted ? 'Unmute' : 'Mute'} onClick={() => audio.setMute(!dev?.isMuted, { deviceId: dev?.deviceId })}>{volIcon}</button>
              <input type="range" min="0" max="100" value={vol} disabled={!dev}
                onInput={e => setVolume(+e.target.value)} onChange={e => setVolume(+e.target.value)}
                onMouseUp={e => commitVolume(+e.target.value)} />
              <span style={{ width: 36, textAlign: 'right' }} className={dev?.isMuted ? 'muted' : ''}>{dev?.isMuted ? 'mute' : pct(vol)}</span>
            </div>
          </div>
          <div className="section">
            <div className="label">output</div>
            {audio.playbackDevices.map(d => (
              <div key={d.deviceId} className={`row click ${d.isDefaultPlayback ? 'active' : ''}`} onClick={() => switchDevice(d)} title={d.name}>
                <span>{d.isDefaultPlayback ? G.check : G.speaker}</span>
                <span className="grow">{d.name}</span>
                {d.isMuted && <span className="tag">muted</span>}
              </div>
            ))}
            {msg && <div className={`msg ${msg.cls}`}>{msg.text}</div>}
          </div>
        </>
      )}
      {out.media && (
        <div className="section">
          <div className="label">media</div>
          {session ? (
            <>
              <div className="row" title={`${session.title ?? ''} — ${session.artist ?? ''}`}>
                <span className="accent">{G.music}</span>
                <span className="grow">{session.title || 'Unknown'}<span className="muted">{session.artist ? ` · ${session.artist}` : ''}</span></span>
              </div>
              <div className="grid3">
                <button className="btn" title="Previous" onClick={() => out.media.previous(mopt)}>{G.prev}</button>
                <button className="btn primary" title="Play/Pause" onClick={() => out.media.togglePlayPause(mopt)}>{session.isPlaying ? G.pause : G.play}</button>
                <button className="btn" title="Next" onClick={() => out.media.next(mopt)}>{G.next}</button>
              </div>
            </>
          ) : <div className="msg">Nothing playing.</div>}
        </div>
      )}
    </Frame>
  );
}

// ---------- clock / calendar ----------
function isoWeek(d) {
  const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = t.getUTCDay() || 7;
  t.setUTCDate(t.getUTCDate() + 4 - day);
  return Math.ceil(((t - new Date(Date.UTC(t.getUTCFullYear(), 0, 1))) / 86400000 + 1) / 7);
}
function ClockPopup() {
  const [now, setNow] = useState(new Date());
  const [view, setView] = useState(() => { const d = new Date(); return new Date(d.getFullYear(), d.getMonth(), 1); });
  useEffect(() => { const i = setInterval(() => setNow(new Date()), 1000); return () => clearInterval(i); }, []);

  const first = new Date(view.getFullYear(), view.getMonth(), 1);
  const start = new Date(first); start.setDate(1 - ((first.getDay() + 6) % 7)); // Monday
  const weeks = [];
  for (let w = 0; w < 6; w++) {
    const days = [];
    for (let i = 0; i < 7; i++) { const d = new Date(start); d.setDate(start.getDate() + w * 7 + i); days.push(d); }
    weeks.push(days);
  }
  const same = (a, b) => a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
  const move = n => setView(new Date(view.getFullYear(), view.getMonth() + n, 1));
  const title = view.toLocaleString('en-US', { month: 'long', year: 'numeric' });

  return (
    <Frame icon={G.cal}
      title={<span title="Back to today" style={{ cursor: 'pointer' }} onClick={() => setView(new Date(now.getFullYear(), now.getMonth(), 1))}>{title}</span>}
      right={<>
        <button className="iconbtn" title="Previous month" onClick={() => move(-1)}>{G.left}</button>
        <button className="iconbtn" title="Next month" onClick={() => move(1)}>{G.right}</button>
      </>}>
      <div className="muted" style={{ marginBottom: 6 }}>
        {now.toLocaleString('en-US', { weekday: 'long', day: 'numeric', month: 'long' })} · W{isoWeek(now)} · {now.toLocaleTimeString('en-GB')}
      </div>
      <table className="cal">
        <thead><tr><th>wk</th>{['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'].map(d => <th key={d}>{d}</th>)}</tr></thead>
        <tbody>
          {weeks.map((days, i) => (
            <tr key={i}>
              <td className="wk">{isoWeek(days[0])}</td>
              {days.map(d => (
                <td key={d.toISOString()}
                  className={`${d.getMonth() !== view.getMonth() ? 'out' : ''} ${same(d, now) ? 'today' : ''} ${d.getDay() === 0 || d.getDay() === 6 ? 'we' : ''}`}>
                  {d.getDate()}
                </td>
              ))}
            </tr>
          ))}
        </tbody>
      </table>
    </Frame>
  );
}

// ---------- power / battery ----------
function PowerPopup() {
  const out = useProviders({ battery: { type: 'battery', refreshInterval: 5000 } });
  const bat = out.battery;
  const [confirm, setConfirm] = useState(null);
  const [bright, setBright] = useState(null);
  const pending = useRef(null);
  useEffect(() => { ps('brightness.ps1', 'get').then(r => setBright(r?.supported ? r.level : false)); }, []);
  useEffect(() => { if (!confirm) return; const t = setTimeout(() => setConfirm(null), 4000); return () => clearTimeout(t); }, [confirm]);

  const setBrightness = v => {
    setBright(v);
    clearTimeout(pending.current);
    pending.current = setTimeout(() => ps('brightness.ps1', 'set', String(v)), 150);
  };
  const act = (action, needsConfirm) => {
    if (needsConfirm && confirm !== action) { setConfirm(action); return; }
    run(AHK, [PACK + '\\powermenu.ahk', action]);
    closePopup();
  };
  const left = bat && (bat.isCharging ? fmtDuration(bat.timeTillFull) : fmtDuration(bat.timeTillEmpty));
  const cls = bat && !bat.isCharging ? (bat.chargePercent < 10 ? 'crit' : bat.chargePercent < 20 ? 'warn' : '') : '';
  const btn = (action, icon, label, danger) => (
    <button className={`btn ${confirm === action ? 'danger' : ''}`} onClick={() => act(action, danger)}>
      {icon} {confirm === action ? `Confirm ${label.toLowerCase()}?` : label}
    </button>
  );

  return (
    <Frame icon={bat?.isCharging ? G.charging : G.bat} title="Power"
      right={<button className="iconbtn" title="Power & battery settings" onClick={() => openSettings('batterysaver')}>{G.link}</button>}>
      {bat ? (
        <div className="section">
          <div className="row">
            <span className={`big ${cls}`}>{pct(bat.chargePercent)}</span>
            <span className="grow muted">
              {bat.state}{left ? ` · ${left} ${bat.isCharging ? 'to full' : 'left'}` : ''}
            </span>
          </div>
          <div className={`bar ${cls}`}><div style={{ width: pct(bat.chargePercent) }} /></div>
        </div>
      ) : <div className="msg">No battery.</div>}
      {bright !== false && (
        <div className="section">
          <div className="label">brightness</div>
          <div className="row">
            <span>{G.sun}</span>
            <input type="range" min="0" max="100" value={bright ?? 0} disabled={bright == null}
              onInput={e => setBrightness(+e.target.value)} onChange={e => setBrightness(+e.target.value)} />
            <span style={{ width: 36, textAlign: 'right' }}>{bright == null ? '…' : pct(bright)}</span>
          </div>
        </div>
      )}
      <div className="section">
        <div className="label">session</div>
        <div className="grid2">
          {btn('lock', G.lock, 'Lock', false)}
          {btn('sleep', G.sleep, 'Sleep', false)}
          {btn('restart', G.restart, 'Restart', true)}
          {btn('shutdown', G.power, 'Shut down', true)}
          {btn('signout', G.logout, 'Sign out', true)}
          <button className="btn" onClick={() => openSettings('batterysaver')}>{G.link} Power mode</button>
        </div>
      </div>
    </Frame>
  );
}

// ---------- cpu / memory / disk ----------
function CpuPopup() {
  const out = useProviders({ cpu: { type: 'cpu', refreshInterval: 1500 }, memory: { type: 'memory', refreshInterval: 3000 }, disk: { type: 'disk', refreshInterval: 30000 } });
  const [hist, setHist] = useState([]);
  useEffect(() => {
    const h = e => { if (e.data?.t === 'cpu-history') setHist(prev => prev.length ? prev : e.data.samples.slice(-60)); };
    chan.addEventListener('message', h);
    chan.postMessage({ t: 'cpu-history?' });
    return () => chan.removeEventListener('message', h);
  }, []);
  useEffect(() => { if (out.cpu) setHist(h => [...h, out.cpu.usage].slice(-60)); }, [out.cpu]);

  const W = 268, H = 44;
  const pts = hist.map((v, i) => `${(i / Math.max(1, hist.length - 1)) * W},${H - (v / 100) * (H - 2) - 1}`).join(' ');
  const mem = out.memory;
  const disks = out.disk?.disks ?? [];
  const lvl = p => (p > 90 ? 'crit' : p > 75 ? 'warn' : '');

  return (
    <Frame icon={G.cpu} title="System" right={<button className="btn" onClick={() => { run('taskmgr', []); closePopup(); }}>Task Manager</button>}>
      {out.cpu && (
        <div className="section">
          <div className="row"><span className="grow">CPU</span><span className={lvl(out.cpu.usage)}>{pct(out.cpu.usage)}</span></div>
          <svg className="spark" viewBox={`0 0 ${W} ${H}`} preserveAspectRatio="none">
            <polyline points={pts} fill="none" stroke="#7aa2f7" strokeWidth="1.5" vectorEffect="non-scaling-stroke" />
          </svg>
          <div className="muted">
            {[out.cpu.vendor, `${out.cpu.physicalCoreCount} cores / ${out.cpu.logicalCoreCount} threads`, out.cpu.frequency > 0 ? `${(out.cpu.frequency / 1000).toFixed(2)} GHz` : null]
              .filter(Boolean).join(' · ')}
          </div>
        </div>
      )}
      {mem && (
        <div className="section">
          <div className="row"><span className="grow">Memory</span><span className={lvl(mem.usage)}>{fmtBytes(mem.usedMemory)} / {fmtBytes(mem.totalMemory)}</span></div>
          <div className={`bar ${lvl(mem.usage)}`}><div style={{ width: pct(mem.usage) }} /></div>
        </div>
      )}
      {disks.map(d => {
        const used = d.totalSpace.bytes - d.availableSpace.bytes;
        const p = (used / d.totalSpace.bytes) * 100;
        return (
          <div className="section" key={d.mountPoint}>
            <div className="row"><span className="grow">Disk {d.mountPoint}</span><span className={lvl(p)}>{fmtBytes(used)} / {fmtBytes(d.totalSpace.bytes)}</span></div>
            <div className={`bar ${lvl(p)}`}><div style={{ width: pct(p) }} /></div>
          </div>
        );
      })}
    </Frame>
  );
}

// ---------- wifi ----------
function wifiGlyph(s) { return s >= 80 ? G.wifi[4] : s >= 60 ? G.wifi[3] : s >= 40 ? G.wifi[2] : s >= 20 ? G.wifi[1] : G.wifi[0]; }
function WifiPopup() {
  const out = useProviders({ network: { type: 'network', refreshInterval: 3000 } });
  const [radio, setRadio] = useState(null);
  const [radioBusy, setRadioBusy] = useState(false);
  const [scan, setScan] = useState(null);
  const [scanning, setScanning] = useState(false);
  const [pwFor, setPwFor] = useState(null);
  const [status, setStatus] = useState(null);
  const pwRef = useRef(null);

  const rescan = async () => {
    setScanning(true);
    const r = await ps('wifi.ps1', 'scan');
    setScan(r?.networks ? r : { networks: [], current: null, error: r?.error });
    setScanning(false);
  };
  useEffect(() => {
    ps('radios.ps1', 'wifi', 'status').then(setRadio);
    rescan();
  }, []);
  useEffect(() => { if (pwFor && pwRef.current) pwRef.current.focus(); }, [pwFor]);

  const toggleRadio = async on => {
    setRadioBusy(true);
    const r = await ps('radios.ps1', 'wifi', on ? 'on' : 'off');
    setRadio(r); setRadioBusy(false);
    if (r?.error) setStatus({ cls: 'err', text: r.error });
    if (on) setTimeout(rescan, 3000); else setScan({ networks: [], current: null });
  };

  const connectSaved = async n => {
    setStatus({ cls: '', text: `Connecting to ${n.ssid}…`, ssid: n.ssid });
    const r = await ps('wifi.ps1', 'connect', n.ssid);
    setStatus(r?.ok ? { cls: 'ok', text: `Connected to ${n.ssid}` } : { cls: 'err', text: r?.message || r?.error || 'Could not connect.' });
    rescan();
  };

  // New network: the password goes to the helper over stdin only, never as an argument.
  const connectNew = async (n, password) => {
    setPwFor(null);
    setStatus({ cls: '', text: `Connecting to ${n.ssid}…`, ssid: n.ssid });
    let stdout = '';
    try {
      const proc = await zebar.shellSpawn('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', HELPERS + 'wifi.ps1', 'add']);
      proc.onStdout(line => { stdout += line + '\n'; });
      const done = new Promise(res => proc.onExit(res));
      proc.write(JSON.stringify({ ssid: n.ssid, auth: n.auth, password: password ?? '' }) + '\n');
      password = null;
      await done;
    } catch (err) {
      setStatus({ cls: 'err', text: String(err) });
      return;
    }
    const r = parseLast(stdout);
    if (r?.ok) setStatus({ cls: 'ok', text: `Connected to ${n.ssid}` });
    else if (r?.state === 'badpassword') setStatus({ cls: 'err', text: r.message || 'Wrong password.' });
    else setStatus({ cls: 'err', text: r?.message || 'Could not connect.' });
    rescan();
  };

  const clickNetwork = n => {
    const cur = scan?.current;
    if (cur?.state === 'connected' && cur.ssid === n.ssid) return;
    if (n.enterprise) { holdOpen = true; run('explorer', ['ms-availablenetworks:']); setTimeout(closePopup, 300); return; }
    if (n.saved) return connectSaved(n);
    if (n.open) return connectNew(n, '');
    setStatus(null);
    setPwFor(pwFor === n.ssid ? null : n.ssid);
  };

  const iface = out.network?.defaultInterface;
  const cur = scan?.current;
  const radioOn = radio?.state === 'on';
  const connectedSsid = cur?.state === 'connected' ? cur.ssid : out.network?.defaultGateway?.ssid;

  return (
    <Frame icon={radioOn ? G.wifi[4] : G.wifiOff} title="Wi-Fi"
      right={<>
        <button className="iconbtn" title="Rescan" onClick={rescan} disabled={!radioOn || scanning}>{G.refresh}</button>
        <Toggle on={radioOn} busy={!radio || radioBusy || !radio?.present} title="Wi-Fi on/off" onChange={toggleRadio} />
      </>}>
      {connectedSsid && (
        <div className="section">
          <div className="label">connected</div>
          <div className="row active">
            <span>{wifiGlyph(cur?.signal ?? out.network?.defaultGateway?.signalStrength ?? 0)}</span>
            <span className="grow">{connectedSsid}</span>
            <span className="tag">{cur?.signal ?? out.network?.defaultGateway?.signalStrength ?? '?'}%</span>
          </div>
          {iface?.ipv4Addresses?.[0] && <div className="msg">IP {iface.ipv4Addresses[0]}{iface.friendlyName ? ` · ${iface.friendlyName}` : ''}</div>}
        </div>
      )}
      {status && <div className={`msg ${status.cls}`}>{status.text}</div>}
      <div className="section">
        <div className="label">{scanning ? 'scanning…' : radioOn ? 'networks' : 'wi-fi is off'}</div>
        {scan?.error && <div className="msg err">{scan.error}</div>}
        {radioOn && (scan?.networks ?? []).filter(n => n.ssid !== connectedSsid).map(n => (
          <React.Fragment key={n.ssid}>
            <div className="row click" onClick={() => clickNetwork(n)} title={`${n.auth} · ${n.signal}%`}>
              <span>{wifiGlyph(n.signal)}</span>
              <span className="grow">{n.ssid}</span>
              {n.enterprise ? <span className="tag warn">802.1X → Windows</span>
                : n.saved ? <span className="tag">saved</span>
                : !n.open ? <span className="tag">{G.padlock}</span> : <span className="tag">open</span>}
            </div>
            {pwFor === n.ssid && (
              <form className="row" onSubmit={e => { e.preventDefault(); const pw = pwRef.current.value; pwRef.current.value = ''; connectNew(n, pw); }}>
                <input ref={pwRef} type="password" placeholder="password" autoComplete="off" spellCheck="false" />
                <button className="btn primary" type="submit">Join</button>
              </form>
            )}
          </React.Fragment>
        ))}
      </div>
    </Frame>
  );
}

// ---------- bluetooth ----------
function BtPopup() {
  const [radio, setRadio] = useState(null);
  const [radioBusy, setRadioBusy] = useState(false);
  const [paired, setPaired] = useState(null);
  const [nearby, setNearby] = useState(null);
  const [scanning, setScanning] = useState(false);
  const [status, setStatus] = useState(null);
  const [prompt, setPrompt] = useState(null); // {kind:'confirm'|'providepin'|'displaypin', pin, proc, name}
  const [confirmUnpair, setConfirmUnpair] = useState(null);
  const pinRef = useRef(null);

  const bt = async (...args) => {
    try { return parseLast((await zebar.shellExec(BT_EXE, args)).stdout); } catch (err) { return { error: String(err) }; }
  };
  const refresh = async () => { const r = await bt('list'); setPaired(r?.devices ?? []); if (r?.error) setStatus({ cls: 'err', text: r.error }); };
  useEffect(() => { ps('radios.ps1', 'bluetooth', 'status').then(setRadio); refresh(); }, []);

  const toggleRadio = async on => {
    setRadioBusy(true);
    const r = await ps('radios.ps1', 'bluetooth', on ? 'on' : 'off');
    setRadio(r); setRadioBusy(false);
    if (r?.error) setStatus({ cls: 'err', text: r.error });
    if (on) setTimeout(refresh, 1500); else { setNearby(null); }
  };

  const doScan = async () => {
    setScanning(true); setStatus(null);
    const r = await bt('scan', '10');
    setNearby((r?.devices ?? []).filter(d => !(paired ?? []).some(p => p.name === d.name)));
    if (r?.error) setStatus({ cls: 'err', text: r.error });
    setScanning(false);
  };

  const pair = async d => {
    setStatus({ cls: '', text: `Pairing with ${d.name}…` });
    let buf = '';
    let proc;
    try {
      proc = await zebar.shellSpawn(BT_EXE, ['pair', d.id]);
    } catch (err) { setStatus({ cls: 'err', text: String(err) }); return; }
    proc.onStdout(line => {
      buf += line;
      for (const l of line.split(/\r?\n/)) {
        let m; try { m = JSON.parse(l); } catch { continue; }
        if (m.event === 'confirm') setPrompt({ kind: 'confirm', pin: m.pin, proc, name: d.name });
        else if (m.event === 'providepin') setPrompt({ kind: 'providepin', proc, name: d.name });
        else if (m.event === 'displaypin') setPrompt({ kind: 'displaypin', pin: m.pin, proc, name: d.name });
        else if (m.done) {
          setPrompt(null);
          setStatus(m.ok ? { cls: 'ok', text: `Paired with ${d.name}` } : { cls: 'err', text: `Pairing failed: ${m.status ?? m.error}` });
          setNearby(n => (n ?? []).filter(x => x.id !== d.id));
          refresh();
        }
      }
    });
    proc.onExit(() => setPrompt(null));
  };
  const answer = text => { prompt?.proc?.write(text + '\n'); setPrompt(p => (p?.kind === 'displaypin' ? p : null)); };

  const unpair = async d => {
    if (confirmUnpair !== d.id) { setConfirmUnpair(d.id); setTimeout(() => setConfirmUnpair(c => (c === d.id ? null : c)), 4000); return; }
    setConfirmUnpair(null);
    setStatus({ cls: '', text: `Removing ${d.name}…` });
    const r = await bt('unpair', d.id);
    setStatus(r?.ok ? { cls: 'ok', text: `Removed ${d.name}` } : { cls: 'err', text: `Couldn't remove: ${r?.status ?? r?.error}` });
    refresh();
  };

  const on = radio?.state === 'on';
  return (
    <Frame icon={on ? G.btOn : G.btOff} title="Bluetooth"
      right={<Toggle on={on} busy={!radio || radioBusy || !radio?.present} title="Bluetooth on/off" onChange={toggleRadio} />}>
      {radio && !radio.present && <div className="msg err">No Bluetooth radio found.</div>}
      {status && <div className={`msg ${status.cls}`}>{status.text}</div>}
      {prompt?.kind === 'confirm' && (
        <div className="section">
          <div className="msg warn">Does {prompt.name} show PIN <b className="accent">{prompt.pin}</b>?</div>
          <div className="grid2">
            <button className="btn primary" onClick={() => answer('yes')}>Yes, pair</button>
            <button className="btn" onClick={() => answer('no')}>No</button>
          </div>
        </div>
      )}
      {prompt?.kind === 'providepin' && (
        <form className="row" onSubmit={e => { e.preventDefault(); const v = pinRef.current.value; pinRef.current.value = ''; answer(v); }}>
          <input ref={pinRef} type="text" placeholder={`PIN for ${prompt.name}`} autoFocus />
          <button className="btn primary" type="submit">OK</button>
        </form>
      )}
      {prompt?.kind === 'displaypin' && <div className="msg warn">Type <b className="accent">{prompt.pin}</b> on {prompt.name}</div>}
      <div className="section">
        <div className="label">paired</div>
        {paired == null && <div className="msg">loading…</div>}
        {paired?.length === 0 && <div className="msg">No paired devices.</div>}
        {paired?.map(d => (
          <div key={d.id} className={`row ${d.connected ? 'active' : ''}`}>
            <span>{G.bt}</span>
            <span className="grow" title={d.name}>{d.name}</span>
            <span className="tag">{d.connected ? 'connected' : 'paired'}</span>
            <button className={`btn ${confirmUnpair === d.id ? 'danger' : ''}`} onClick={() => unpair(d)}>{confirmUnpair === d.id ? 'Remove?' : G.close}</button>
          </div>
        ))}
      </div>
      <div className="section">
        <div className="row">
          <span className="label grow" style={{ margin: 0 }}>{scanning ? 'scanning…' : 'nearby'}</span>
          <button className="btn" disabled={!on || scanning} onClick={doScan}>{scanning ? '…' : 'Scan'}</button>
        </div>
        {nearby?.length === 0 && !scanning && <div className="msg">Nothing found. Put the device in pairing mode and scan again.</div>}
        {nearby?.map(d => (
          <div key={d.id} className="row click" onClick={() => pair(d)} title="Click to pair">
            <span>{G.bt}</span>
            <span className="grow">{d.name}</span>
            <span className="tag">{d.kind === 'le' ? 'LE' : ''} pair</span>
          </div>
        ))}
      </div>
    </Frame>
  );
}

const POPUPS = { audio: AudioPopup, clock: ClockPopup, power: PowerPopup, cpu: CpuPopup, wifi: WifiPopup, bt: BtPopup };
const Comp = POPUPS[MODE] ?? (() => <div className="msg err">Unknown popup: {String(MODE)}</div>);
createRoot(document.getElementById('root')).render(<Comp />);
