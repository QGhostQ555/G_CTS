/* G_CTS WebUI · Material 3  —  Ghost 基于 MoWei CpuTurboScheduler 二改
   原 WebUI 作者：酷安@瓦力喀 / 酷安@机型质检员 / 酷安@Aus_tin（本版为重写） */
(() => {
'use strict';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const MOD = '/data/adb/modules/MW_CpuTurboScheduler';
const SD = '/sdcard/Android/MW_CpuSpeedController';

/* ───────── 图标（线性，24px） ───────── */
const P = {
  cpu: '<rect x="6" y="6" width="12" height="12" rx="2"/><rect x="9.5" y="9.5" width="5" height="5" rx="1"/><path d="M9 3v3M15 3v3M9 18v3M15 18v3M3 9h3M3 15h3M18 9h3M18 15h3"/>',
  tune: '<path d="M4 7h9M17 7h3M4 17h3M11 17h9"/><circle cx="15" cy="7" r="2"/><circle cx="9" cy="17" r="2"/>',
  doc: '<path d="M6 3h8l5 5v13H6z"/><path d="M14 3v5h5M9 13h6M9 17h6"/>',
  gear: '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
  leaf: '<path d="M5 19c0-9 5-14 14-14 0 9-5 14-14 14z"/><path d="M5 19 14 10"/>',
  balance: '<path d="M12 4v16M6 20h12M5 8h14M5 8l-2.5 6a2.5 2.5 0 0 0 5 0zM19 8l-2.5 6a2.5 2.5 0 0 0 5 0z"/>',
  gauge: '<path d="M4.5 17a8.5 8.5 0 1 1 15 0"/><path d="M12 14l4-4"/><circle cx="12" cy="14" r="1.2"/>',
  bolt: '<path d="M13 2 4 14h7l-1 8 9-12h-7z"/>',
  chev: '<path d="M6 9l6 6 6-6"/>', check: '<path d="M5 12.5l4.5 4.5L19 7.5"/>',
  refresh: '<path d="M20 11a8 8 0 1 0-2.3 5.7M20 4v7h-7"/>',
  copy: '<rect x="9" y="9" width="11" height="11" rx="2"/><path d="M5 15V6a2 2 0 0 1 2-2h9"/>',
  trash: '<path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/>',
  save: '<path d="M5 3h11l3 3v15H5zM8 3v5h7V3M8 21v-7h8v7"/>',
  undo: '<path d="M9 14 4 9l5-5M4 9h10a6 6 0 0 1 0 12h-3"/>',
  search: '<circle cx="11" cy="11" r="6.5"/><path d="M16 16l5 5"/>',
  sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M2 12h2M20 12h2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4"/>',
  moon: '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5z"/>',
  auto: '<circle cx="12" cy="12" r="8"/><path d="M12 4a8 8 0 0 1 0 16z" fill="currentColor"/>',
  info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6M12 7.5v.01"/>',
  down: '<path d="M12 3v12M7 10l5 5 5-5M5 21h14"/>',
  history: '<path d="M3 12a9 9 0 1 0 3-6.7L3 8M3 3v5h5M12 7v5l3 2"/>',
  power: '<path d="M12 3v9M6.3 6.3a8 8 0 1 0 11.4 0"/>',
  warn: '<path d="M12 3 2 20h20zM12 10v5M12 17.5v.01"/>',
  battery: '<rect x="3" y="8" width="16" height="9" rx="2"/><path d="M21 11v3"/>',
  thermo: '<path d="M10 14V5a2 2 0 0 1 4 0v9a4 4 0 1 1-4 0z"/>',
  palette: '<path d="M12 3a9 9 0 1 0 0 18c1.2 0 2-.9 2-2 0-.6-.3-1-.6-1.4-.3-.4-.4-.7-.4-1.1 0-.8.7-1.5 1.5-1.5H17a4 4 0 0 0 4-4c0-4.4-4-8-9-8z"/><circle cx="7.5" cy="11" r="1"/><circle cx="10" cy="7" r="1"/><circle cx="15" cy="7" r="1"/>',
  modesync: '<path d="M7 7h6v2H9.5A4.5 4.5 0 1 0 14 13.5"/><path d="M17 17h-6v-2h3.5A4.5 4.5 0 1 0 10 10.5"/><path d="M15 5l2 2-2 2M9 19l-2-2 2-2"/>',
};
const ic = (n, c = '') => `<svg class="ic ${c}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${P[n] || ''}</svg>`;

/* ───────── 常量 ───────── */
const MODES = [
  { id: 'powersave', name: '省电', tag: '续航优先', icon: 'leaf', hue: 145 },
  { id: 'balance', name: '均衡', tag: '日常首选', icon: 'balance', hue: 215 },
  { id: 'performance', name: '性能', tag: '重载更跟手', icon: 'gauge', hue: 30 },
  { id: 'fast', name: '极速', tag: '高性能 · 高功耗', icon: 'bolt', hue: 345 },
];
const MID = Object.fromEntries(MODES.map(m => [m.id, m]));
const CL = [['Small', '小核'], ['Medium', '中核'], ['Big', '大核'], ['SuperBig', '超大核']];
const PARAM = {
  up_rate_limit_us: ['升频间隔', 'µs · 升频后最短等待时间；较小值响应更快'],
  down_rate_limit_us: ['降频间隔', 'µs · 降频后最短等待时间；较大值减少频率来回波动'],
  down_threshold: ['降频负载阈值', '% · 低于该负载阈值时允许降频'],
  freq_step: ['频率步进', '· 每次调频变化的步长，按当前 governor 定义'],
  sampling_down_factor: ['降频采样倍率', '· 按 governor 的采样策略解释'],
  sampling_rate: ['采样间隔', 'µs · 按 governor 的采样策略解释'],
  up_threshold: ['升频负载阈值', '% · 高于该负载阈值时提高频率'],
  ignore_nice_load: ['忽略 Nice 负载', '0 / 1'],
  hispeed_load: ['高速负载阈值', '% · 负载超过该值时跳到 hispeed 频率'],
  hispeed_freq: ['高速频率', 'kHz'], target_load_shift: ['目标负载移位', ''], target_load_thresh: ['目标负载阈值', ''],
  adaptive_low_freq: ['自适应低频', 'kHz'], adaptive_high_freq: ['自适应高频', 'kHz'], pl: ['预测负载', '0 / 1'],
};
const SWITCHES = [
  ['function', 'EasScheduler', 'EAS 能效调度', '调整 EAS 参数，让任务更倾向落在高能效核心'],
  ['function', 'cpuset', '核心分组 (cpuset)', '按前台/后台限定可用核心，减少后台抢占大核'],
  ['function', 'LoadBalancing', '负载均衡', '优化 CFS 负载均衡，降低跨簇迁移抖动'],
  ['function', 'AdjIOScheduler', 'I/O 调度器', '选择并应用设备支持的块队列调度器；队列调优另行设置'],
  ['function', 'LaunchBoost', '应用启动加速', '启动应用时短暂提频，冷/热启动更快'],
  ['function', 'AffintySetter', '关键线程绑核', '对系统与传感器关键线程做亲和性绑定'],
  ['function', 'DisableQcomGpu', '禁用 GPU Boost', '阻止高通 GPU boost 无序拉升频率'],
  ['function', 'CpuIdleScaling_Governor', '自定义 CPU 空闲调速器', '使用下方选择的 CPUIdle 调速器'],
];
const HUES = [[205, '蓝'], [175, '青'], [145, '绿'], [95, '黄绿'], [40, '橙'], [345, '红'], [305, '紫'], [265, '靛']];

/* ───────── 偏好与主题 ───────── */
const prefs = (() => {
  const d = { theme: 'auto', amoled: false, seed: 215, seedMode: true };
  try {
    const o = { ...d, ...JSON.parse(localStorage.getItem('gcts.prefs') || '{}') };
    if (o.seed === 'mode') { o.seedMode = true; o.seed = 215; }
    if (typeof o.seedMode !== 'boolean') o.seedMode = true;
    if (typeof o.seed !== 'number') o.seed = 215;
    return o;
  } catch { return d; }
})();
const savePrefs = () => { try { localStorage.setItem('gcts.prefs', JSON.stringify(prefs)); } catch {} };
const mq = matchMedia('(prefers-color-scheme: dark)');
function applyTheme() {
  const dark = prefs.theme === 'dark' || (prefs.theme === 'auto' && mq.matches);
  const root = document.documentElement;
  root.classList.toggle('dark', dark);
  root.classList.toggle('amoled', dark && prefs.amoled);
  const hue = prefs.seedMode ? (MID[S.mode] || MID.balance).hue : prefs.seed;
  root.style.setProperty('--h', hue);
}
mq.addEventListener?.('change', () => applyTheme());

/* ───────── 后端：KernelSU exec ───────── */
let cbN = 0;
function sh(cmd, ms = 20000) {
  return new Promise(res => {
    const name = `__g${++cbN}_${Date.now().toString(36)}`;
    const t = setTimeout(() => { delete window[name]; res({ errno: -1, stdout: '', stderr: 'timeout' }); }, ms);
    window[name] = (errno, stdout, stderr) => { clearTimeout(t); delete window[name]; res({ errno, stdout: stdout || '', stderr: stderr || '' }); };
    try { window.ksu.exec(cmd, '{}', name); } catch (e) { clearTimeout(t); delete window[name]; res({ errno: -2, stdout: '', stderr: String(e) }); }
  });
}
const b64 = s => btoa(unescape(encodeURIComponent(s)));
const real = {
  async info() {
    const r = await sh(`S=/sys/devices/system/cpu
echo "PROP|$(getprop ro.product.marketname)|$(getprop ro.product.model)|$(getprop ro.soc.model)|$(getprop ro.board.platform)|$(getprop ro.build.version.release)|$(uname -r)"
echo "MOD|$(sed -n 's/^version=//p' ${MOD}/module.prop)|$(cat ${MOD}/profile 2>/dev/null)"
for p in $S/cpufreq/policy*; do [ -d "$p" ] || continue; n=\${p##*policy}; echo "POL|$n|$(cat $p/related_cpus)|$(cat $p/cpuinfo_max_freq)|$(cat $p/scaling_available_frequencies 2>/dev/null)|$(cat $p/scaling_available_governors 2>/dev/null)"; done
IOS=""
IOS_SEEN=0
IO_QUEUES=0
IOS_WRITABLE=1
IO_TUNABLE=1
IO_TUNED=0
for queue in /sys/block/*/queue; do
  [ -d "$queue" ] || continue
  IO_QUEUES=$((IO_QUEUES + 1))
  q="$queue/scheduler"
  if [ ! -r "$q" ] || [ ! -w "$q" ]; then IOS_WRITABLE=0; fi
  if [ -r "$queue/iostats" ] && [ -w "$queue/iostats" ] &&
     [ -r "$queue/nomerges" ] && [ -w "$queue/nomerges" ]; then
    IO_TUNED=$((IO_TUNED + 1))
  else IO_TUNABLE=0
  fi
  [ -r "$q" ] || { IOS_WRITABLE=0; continue; }
  AVAILABLE=""
  for g in $(cat "$q" 2>/dev/null); do
    g=\${g#\[}; g=\${g%\]}
    [ -n "$g" ] || continue
    case " $AVAILABLE " in *" $g "*) ;; *) AVAILABLE="$AVAILABLE $g" ;; esac
  done
  AVAILABLE=\${AVAILABLE# }
  if [ "$IOS_SEEN" -eq 0 ]; then
    IOS="$AVAILABLE"; IOS_SEEN=1
  else
    COMMON=""
    for g in $IOS; do case " $AVAILABLE " in *" $g "*) COMMON="$COMMON $g" ;; esac; done
    IOS=\${COMMON# }
  fi
done
if [ "$IOS_WRITABLE" -ne 1 ]; then IOS=""; fi
echo "IOS|$IOS"
echo "IOCAP|$IO_QUEUES|$IOS_WRITABLE|$IO_TUNABLE|$IO_TUNED"
IDLE_AVAILABLE=$(cat "$S/cpuidle/available_governors" 2>/dev/null)
IDLE_NODE="$S/cpuidle/current_governor"
IDLE_CURRENT=$(cat "$IDLE_NODE" 2>/dev/null)
IDLE_WRITABLE=0
[ -n "$IDLE_AVAILABLE" ] && [ -w "$IDLE_NODE" ] && IDLE_WRITABLE=1
echo "IDLE|$IDLE_AVAILABLE|$IDLE_CURRENT|$IDLE_WRITABLE"
cfg_value() {
  awk -v section="[$1]" -v key="$2" '
    $0 == section { inside=1; next }
    /^\\[/ { inside=0 }
    inside && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      sub(/^[^=]*=[[:space:]]*/, "")
      gsub(/["\\r]/, "")
      gsub(/[[:space:]]+$/, "")
      print
      exit
    }
  ' "$3"
}
BUS_NODES=0
BUS_SUPPORTED=1
for key in CPUllccmin CPUllccmax CPUddrmin CPUddrmax; do
  node=$(cfg_value Bus_dcvs "$key" ${SD}/config.ini)
  if [ -n "$node" ] && [ -r "$node" ] && [ -w "$node" ]; then
    BUS_NODES=$((BUS_NODES + 1))
  else BUS_SUPPORTED=0
  fi
done
[ "$BUS_NODES" -eq 4 ] || BUS_SUPPORTED=0
echo "BUS|$BUS_SUPPORTED|$BUS_NODES"
GPU=/sys/class/kgsl/kgsl-3d0/idle_timer
if [ -s "$SD/gpu_idle_timer.unsupported" ]; then
  echo "GPU|rejected|$(cat "$SD/gpu_idle_timer.unsupported")"
elif [ -e "$GPU" ]; then
  if [ -r "$GPU" ] && [ -w "$GPU" ]; then echo "GPU|supported"
  elif [ -r "$GPU" ]; then echo "GPU|unwritable"
  else echo "GPU|unreadable|"
  fi
else echo "GPU|unsupported|"
fi`);
    return r.stdout;
  },
  async live() {
    const r = await sh(`S=/sys/devices/system/cpu/cpufreq
for p in $S/policy*; do [ -d "$p" ] || continue; n=\${p##*policy}; echo "L|$n|$(cat $p/scaling_cur_freq)|$(cat $p/scaling_max_freq)|$(cat $p/scaling_governor)"; done
echo "M|$(cat ${SD}/config.txt 2>/dev/null)"
echo "B|$(cat /sys/class/power_supply/battery/capacity)|$(cat /sys/class/power_supply/battery/temp)|$(cat /sys/class/power_supply/battery/status)"
echo "D|$(pidof MW_CpuSpeedController)"`, 8000);
    return r.stdout;
  },
  async readConfig() { const r = await sh(`cat ${SD}/config.ini`); return r.errno === 0 && r.stdout ? r.stdout : null; },
  async writeConfig(text) {
    const n = new TextEncoder().encode(text).length;
    const r = await sh(`cd ${SD} && echo '${b64(text)}' | base64 -d > config.ini.tmp && [ -s config.ini.tmp ] && cp -f config.ini config.ini.last 2>/dev/null; mv -f config.ini.tmp config.ini && echo size=$(wc -c < config.ini)`);
    return r.errno === 0 && /size=\d+/.test(r.stdout);
  },
  async setMode(m) {
    const r = await sh(`sh /data/powercfg.sh '${m}'`);
    const lines = (r.stdout || '').trim().split('\n').filter(Boolean);
    const modeLine = lines.find(line => line.startsWith('MODE|'));
    const gpuLine = lines.find(line => line.startsWith('GPU|'));
    const fields = modeLine ? modeLine.split('|') : [];
    return {
      requested: r.errno === 0 && fields[1] === m && fields[2] === 'written',
      gpu: gpuLine ? gpuLine.slice(4) : '',
      error: r.stderr || (r.errno ? `powercfg.sh exit ${r.errno}` : ''),
    };
  },
  async readLog() { return (await sh(`tail -n 400 ${SD}/log.txt 2>/dev/null`)).stdout; },
  async clearLog() { return (await sh(`: > ${SD}/log.txt`)).errno === 0; },
  async backup() { const r = await sh(`n=config.ini.bak.$(date +%Y%m%d-%H%M%S); cp -f ${SD}/config.ini ${SD}/$n && echo $n`); return r.errno === 0 ? r.stdout.trim() : null; },
  async backups() { return (await sh(`ls -t ${SD} 2>/dev/null | grep -E '^config\\.ini\\.(bak\\.[0-9-]+|last)$'`)).stdout.split('\n').filter(Boolean); },
  async restore(name) { if (!/^config\.ini\.(bak\.[0-9-]+|last)$/.test(name)) return false; return (await sh(`cp -f ${SD}/${name} ${SD}/config.ini`)).errno === 0; },
  async restoreDefault() { return (await sh(`cp -f ${MOD}/config.default.ini ${SD}/config.ini`)).errno === 0; },
  async restart() {
    const r = await sh(`sh ${MOD}/vtools/restart.sh`, 20000);
    const running = r.errno === 0 && (r.stdout || '').trim().split('\n').includes('running');
    return { running, error: running ? '' : (r.stderr || r.stdout || `restart.sh exit ${r.errno}`) };
  },
};


let api = real;

/* ───────── INI 模型：就地改值，保留引号/空格/行尾 ───────── */
class Ini {
  constructor(text) {
    this.eol = text.includes('\r\n') ? '\r\n' : '\n';
    this.lines = text.replace(/\r\n/g, '\n').split('\n');
    this.tail = this.lines[this.lines.length - 1] === '';
    if (this.tail) this.lines.pop();
    this.map = {}; this.order = []; this.secs = [];
    let sec = null;
    this.lines.forEach((ln, i) => {
      const ms = ln.match(/^\s*\[([^\]]+)\]\s*$/);
      if (ms) { sec = ms[1].trim(); this.secs.push(sec); return; }
      const m = sec && ln.match(/^(\s*([^=\s][^=]*?)\s*=\s*)(.*?)\s*$/);
      if (!m) return;
      const raw = m[3], quoted = /^".*"$/.test(raw), v = quoted ? raw.slice(1, -1) : raw;
      const id = sec + '/' + m[2];
      this.map[id] = { i, sec, key: m[2], left: m[1], quoted, v, o: v };
      this.order.push(id);
    });
  }
  has(s, k) { return (s + '/' + k) in this.map; }
  get(s, k, d = '') { const e = this.map[s + '/' + k]; return e ? e.v : d; }
  set(s, k, v) { const e = this.map[s + '/' + k]; if (e) e.v = String(v); }
  keys(s) { return this.order.filter(id => this.map[id].sec === s).map(id => this.map[id].key); }
  changes() { return this.order.filter(id => this.map[id].v !== this.map[id].o).map(id => this.map[id]); }
  mod(s, k) { const e = this.map[s + '/' + k]; return !!e && e.v !== e.o; }
  commit() { this.order.forEach(id => { this.map[id].o = this.map[id].v; }); }
  toString() {
    const out = this.lines.slice();
    this.order.forEach(id => { const e = this.map[id]; out[e.i] = e.left + (e.quoted ? `"${e.v}"` : e.v); });
    return out.join(this.eol) + (this.tail ? this.eol : '');
  }
}

/* ───────── 全局状态 ───────── */
const S = {
  info: null, ini: null, mode: 'balance', running: false, demo: false, ready: false, error: null,
  page: 'home', tab: 'mode', edit: 'balance', live: null, busy: false, saving: false,
  logs: null, logLv: 'ALL', logQ: '', open: { freq: true }, gpuApply: null,
  clusters: [], profile: '', soc: null,
};

/* ───────── 数据解析 ───────── */
const fmtG = k => (k / 1e6).toFixed(2);
const rangeStr = a => { if (!a.length) return ''; const s = [...a].sort((x, y) => x - y), o = []; let i = 0;
  while (i < s.length) { let j = i; while (j + 1 < s.length && s[j + 1] === s[j] + 1) j++; o.push(j > i ? `${s[i]}-${s[j]}` : `${s[i]}`); i = j + 1; } return o.join(','); };
const parseCpus = t => { const o = []; String(t).split(',').forEach(p => { const m = p.trim().match(/^(\d+)(?:-(\d+))?$/); if (m) for (let i = +m[1]; i <= +(m[2] ?? m[1]); i++) o.push(i); }); return o; };

function parseInfo(t) {
  const o = {
    prop: {}, mod: {}, pol: {}, ios: [], idle: [],
    ioc: { queues: 0, scheduler: false, tuning: false, tuned: 0 },
    idleWritable: false, bus: { supported: false, nodes: 0 }, gpu: { status: 'unknown' },
  };
  t.split('\n').forEach(ln => {
    const f = ln.replace(/\r/g, '').split('|');
    if (f[0] === 'PROP') o.prop = { dev: f[1] || f[2], soc: f[3], plat: f[4], and: f[5], kern: f[6] };
    else if (f[0] === 'MOD') o.mod = { ver: f[1], profile: (f[2] || '').trim() };
    else if (f[0] === 'POL') o.pol[+f[1]] = { cpus: (f[2] || '').trim().split(/\s+/).filter(Boolean).map(Number), max: +f[3] || 0,
      freqs: (f[4] || '').trim().split(/\s+/).filter(Boolean).map(Number).sort((a, b) => a - b), govs: (f[5] || '').trim().split(/\s+/).filter(Boolean) };
    else if (f[0] === 'IOS') o.ios = (f[1] || '').replace(/[\[\]]/g, '').trim().split(/\s+/).filter(Boolean);
    else if (f[0] === 'IOCAP') o.ioc = { queues: +f[1] || 0, scheduler: f[2] === '1', tuning: f[3] === '1', tuned: +f[4] || 0 };
    else if (f[0] === 'IDLE') {
      o.idle = (f[1] || '').trim().split(/\s+/).filter(Boolean);
      o.idleCurrent = (f[2] || '').trim();
      o.idleWritable = f[3] === '1';
    }
    else if (f[0] === 'BUS') o.bus = { supported: f[1] === '1', nodes: +f[2] || 0 };
    else if (f[0] === 'GPU') o.gpu = { status: f[1] || 'unknown', detail: f[2] || '' };
  });
  if (!o.ioc.scheduler) o.ios = [];
  if (!o.idleWritable) o.idle = [];
  return o;
}
function buildContext() {
  const ini = S.ini, info = S.info;
  const name = ini.get('meta', 'name');
  let prof = info.mod.profile;
  if (!window.SOC_DATA[prof]) prof = Object.keys(window.SOC_DATA).find(k => window.SOC_DATA[k].name === name) || '';
  S.profile = prof; S.soc = window.SOC_DATA[prof] || null;
  S.clusters = [];
  const usedPol = new Set();
  // 只挂载本机真实存在的 cpufreq policy，避免 8Gen2 等机型缺少 policy5 时画出「大核 上限 -」
  CL.forEach(([key, nm]) => {
    if (!ini.has('CoreFramework', key + 'CorePath')) return;
    let p = +ini.get('CoreFramework', key + 'CorePath');
    if (!info.pol[p]) {
      const si = CL.findIndex(([k]) => k === key);
      const alt = S.soc?.paths?.[si];
      if (alt != null && info.pol[+alt] && !usedPol.has(+alt)) p = +alt;
      else return;
    }
    if (usedPol.has(p)) return;
    usedPol.add(p);
    const pol = info.pol[p];
    const si = (S.soc?.paths || []).map(Number).indexOf(p);
    const idx = si >= 0 ? si : S.clusters.length;
    const hw = pol.freqs?.length ? pol.freqs[pol.freqs.length - 1] : (pol.max || S.soc?.max?.[idx] || 0);
    const cpusStr = pol.cpus?.length ? rangeStr(pol.cpus) : (S.soc?.cpus?.[idx] || '');
    let arch = S.soc?.cores?.[idx] || '';
    // 8Gen2：若本机把 A715+A710 并到同一 policy（如 cpu3-6），文案显示 A715+A710
    if (S.profile === 'SDM8G2' && pol.cpus?.length) {
      const set = new Set(pol.cpus);
      const has715 = [3, 4].some(c => set.has(c));
      const has710 = [5, 6].some(c => set.has(c));
      if (has715 && has710) arch = 'A715+A710';
      else if (has715) arch = 'A715';
      else if (has710) arch = 'A710';
    }
    // 8Gen3：中大核均为 A720 时区分显示
    if (S.profile === 'SDM8G3' && pol.cpus?.length && arch === 'A720') {
      const set = new Set(pol.cpus);
      if ([2, 3, 4].some(c => set.has(c)) && ![5, 6].some(c => set.has(c))) arch = 'A720';
      else if ([5, 6].some(c => set.has(c))) arch = 'A720';
    }
    S.clusters.push({
      key, name: (pol.cpus?.length === 1 && (key === 'Big' || key === 'SuperBig')) ? '超大核' : nm, policy: p,
      cpus: cpusStr,
      arch,
      freqs: pol.freqs || [], hw, govs: pol.govs || []
    });
  });
  S.clusters.sort((a, b) => a.policy - b.policy);
  const cpuNums = Object.values(info.pol).flatMap(x => x.cpus || []);
  S.ncpu = Math.max(8, ...(cpuNums.map(c => c + 1)), 0);
}
const capOf = (m, c) => +S.ini.get(m, c.key + 'CoreMaxFreq', 0);
function parseLive(t) {
  const o = { pol: {}, mode: null, bat: null, pid: '' };
  t.split('\n').forEach(ln => {
    const f = ln.replace(/\r/g, '').split('|');
    if (f[0] === 'L') o.pol[+f[1]] = { cur: +f[2] || 0, max: +f[3] || 0, gov: f[4] };
    else if (f[0] === 'M') o.mode = (f[1] || '').trim();
    else if (f[0] === 'B') o.bat = { cap: +f[1], temp: +f[2] / 10, st: f[3] };
    else if (f[0] === 'D') o.pid = (f[1] || '').trim();
  });
  return o;
}

/* ───────── 弹层、Toast（返回键可关闭） ───────── */
const layers = [];
addEventListener('popstate', () => { const c = layers.pop(); if (c) c(); });
const layerRoot = () => $('#layer');
function pushLayer(el, onClose) {
  layers.push(() => { el.remove(); scrim?.remove(); onClose?.(); });
  const scrim = document.createElement('div'); scrim.className = 'scrim'; scrim.onclick = () => history.back();
  layerRoot().append(scrim, el); history.pushState({ g: layers.length }, '');
}
function dialog({ title, body, acts }) {
  return new Promise(res => {
    const el = document.createElement('div'); el.className = 'dialog'; el.setAttribute('role', 'dialog');
    el.innerHTML = `<h2>${esc(title)}</h2><div>${body || ''}</div><div class="acts"></div>`;
    let val = null;
    acts.forEach(a => { const b = document.createElement('button'); b.className = `btn press ${a.k || 'text'}`; b.textContent = a.t;
      b.onclick = () => { val = typeof a.v === 'function' ? a.v(el) : a.v; history.back(); }; $('.acts', el).append(b); });
    $$('[data-pick]', el).forEach(b => { b.onclick = () => { val = b.dataset.pick; history.back(); }; });
    pushLayer(el, () => res(val));
  });
}
const confirmD = (title, body, ok = '确定', danger = false) =>
  dialog({ title, body: `<p>${body}</p>`, acts: [{ t: '取消', v: false }, { t: ok, v: true, k: danger ? 'text danger' : 'filled' }] });
let toastT;
function toast(msg, act) {
  $('.snack')?.remove(); clearTimeout(toastT);
  const el = document.createElement('div'); el.className = 'snack' + (S.dirtyCount ? ' up' : ''); el.setAttribute('role', 'status');
  el.innerHTML = `<span class="grow">${esc(msg)}</span>` + (act ? `<button class="btn text press">${esc(act.t)}</button>` : '');
  if (act) $('button', el).onclick = () => { el.remove(); act.fn(); };
  $('#app').append(el); toastT = setTimeout(() => el.remove(), act ? 6000 : 3200);
}

/* ───────── 通用片段 ───────── */
const card = (id, title, sub, body, { collapsible = true, open } = {}) => {
  const o = open ?? !!S.open[id];
  return `<section class="card ${collapsible ? (o ? 'open' : '') : 'flat'}" data-card="${id}">
    <${collapsible ? 'button' : 'div'} class="hd ${collapsible ? 'press' : ''}" ${collapsible ? `data-acc="${id}" aria-expanded="${o}"` : ''}>
      <span class="grow"><div class="t">${title}</div>${sub ? `<div class="s" data-sub>${sub}</div>` : ''}</span>${collapsible ? ic('chev', 'chev') : ''}
    </${collapsible ? 'button' : 'div'}><div class="bd">${body}</div></section>`;
};
const modCls = (s, k) => (S.ini.mod(s, k) ? ' mod' : '');
function fSwitch(s, k, title, desc, on = 'true', off = 'false') {
  const v = S.ini.get(s, k) === on;
  return `<div class="item fld${modCls(s, k)}"><div class="grow"><div class="t">${title}</div>${desc ? `<div class="s">${desc}</div>` : ''}</div>
    <button class="switch" role="switch" aria-checked="${v}" aria-label="${esc(title)}" data-t="sw" data-s="${s}" data-k="${k}" data-on="${on}" data-off="${off}"></button></div>`;
}
function fSlider({ s, k, label, sub, min, max, step = 1, unit = '', t = 'sl', c = '', kind = '', stops, ticks = [], dec = 0 }) {
  const raw = +S.ini.get(s, k, 0); let idx, lo, hi, val;
  if (stops) { idx = 0; stops.forEach((f, i) => { if (f <= raw) idx = i; }); min = 0; max = stops.length - 1; step = 1; val = idx; lo = fmtStop(stops[0], kind); hi = fmtStop(stops[max], kind); }
  else { val = clamp(raw, min, max); lo = min + unit; hi = max + unit; }
  const p = max > min ? ((val - min) / (max - min)) * 100 : 0;
  const tk = ticks.map(x => `<i class="tick ${x.cls || ''}" style="left:${max > min ? ((x.v - min) / (max - min)) * 100 : 0}%"></i>`).join('');
  const shown = stops ? fmtStop(stops[idx], kind, true) : (+val).toFixed(dec) + `<u>${unit}</u>`;
  const locked = s === 'fast' && kind === 'Max' && /CoreMaxFreq$/.test(k);
  return `<div class="fld${modCls(s, k)}"><div class="top"><div class="lbl">${label}${sub ? `<small>${sub}</small>` : ''}</div><div class="val" data-v>${shown}</div></div>
    <button type="button" class="slider-display" aria-label="${esc(label)}${locked ? '，极速档自动最高频' : '，点击选择'}" ${locked ? 'disabled' : 'data-t="sliderpick"'} data-s="${s}" data-k="${k}" data-c="${c}" data-kind="${kind}" data-min="${min}" data-max="${max}" data-step="${step}" data-unit="${esc(unit)}" data-dec="${dec}">
      <span class="slider" style="--p:${p}%"><span class="trk"><span class="fill"></span></span>${tk}<span class="thumb"></span></span>
    </button>
    <div class="legend"><span>${lo}</span><span>${hi}</span></div></div>`;
}
const fmtStop = (f, kind, html) => (kind === 'Min' && f === 0) ? '不限制' : (html ? `${fmtG(f)}<u>GHz</u>` : `${fmtG(f)} GHz`);
const stopsFor = (c, kind) => { const f = S.clusters[c].freqs; return kind === 'Min' ? [0, ...f] : f; };
function fSelect(s, k, label, opts, sub) {
  const cur = S.ini.get(s, k);
  const list = [...new Set(opts.filter(Boolean))];
  const shown = list.includes(cur) ? cur : (list.length ? '请选择可用项' : '未检测到可用项');
  return `<div class="fld${modCls(s, k)}"><div class="lbl">${label}${sub ? `<small>${esc(sub)}</small>` : ''}</div>
    <button type="button" class="field-sel press nm" data-t="pick" data-s="${s}" data-k="${k}" data-opts="${esc(list.join('\u001f'))}" aria-label="${esc(label)}" ${list.length ? '' : 'disabled'}><span class="grow sel-val">${esc(shown)}</span>${ic('chev', 'sel-chev')}</button></div>`;
}
async function openPicker(s, k, label, opts) {
  const cur = S.ini.get(s, k);
  const body = opts.map(o => {
    const on = o === cur;
    return `<button type="button" class="opt press${on ? ' on' : ''}" data-pick="${esc(o)}" role="option" aria-selected="${on}">
      <span class="grow">${esc(o)}</span>${on ? ic('check') : '<span class="ic"></span>'}</button>`;
  }).join('');
  const v = await dialog({ title: label, body: `<div class="opt-list" role="listbox">${body}</div>`, acts: [{ t: '取消', v: null }] });
  if (v != null && v !== cur) {
    setVal(s, k, v);
    if (S.page === 'tune') renderTune();
    else if (S.page === 'log') renderLog();
  }
}
function sliderChoices(d) {
  if (d.kind) return stopsFor(+d.c, d.kind).map(v => ({
    value: String(v),
    label: d.kind === 'Min' && v === 0 ? '不限制' : `${fmtG(v)} GHz`,
  }));
  const min = +d.min, max = +d.max, step = +d.step || 1, dec = +d.dec || 0;
  const precision = Math.min(6, Math.max(dec, ...[min, max, step].map(v => (String(v).split('.')[1] || '').length)));
  const scale = 10 ** precision, start = Math.ceil(min * scale), end = Math.floor(max * scale);
  const increment = Math.max(1, Math.round(step * scale)), choices = [];
  for (let value = start; value <= end; value += increment) {
    const n = Number((value / scale).toFixed(precision));
    choices.push({ value: dec ? n.toFixed(dec) : String(n), label: `${n.toFixed(dec)}${d.unit || ''}` });
  }
  return choices;
}
async function openSliderPicker(d, label) {
  const s = d.s, k = d.k, cur = S.ini.get(s, k), choices = sliderChoices(d);
  const body = choices.map(({ value, label: text }) => {
    const on = Number(value) === Number(cur);
    return `<button type="button" class="opt press${on ? ' on' : ''}" data-pick="${esc(value)}" role="option" aria-selected="${on}">
      <span class="grow">${esc(text)}</span>${on ? ic('check') : '<span class="ic"></span>'}</button>`;
  }).join('');
  const value = await dialog({ title: label, body: `<div class="opt-list" role="listbox">${body}</div>`, acts: [{ t: '取消', v: null }] });
  if (value != null && Number(value) !== Number(cur)) {
    setVal(s, k, value);
    if (S.page === 'tune') renderTune();
  }
}
async function openNumberPicker(d, label) {
  const inputId = `number-choice-${Date.now()}`;
  const current = S.ini.get(d.s, d.k);
  const value = await dialog({
    title: label,
    body: `<label class="number-choice">数值<input id="${inputId}" type="number" inputmode="decimal" min="${d.min}" max="${d.max}" step="any" value="${esc(current)}"></label>`,
    acts: [
      { t: '取消', v: null },
      { t: '确定', k: 'filled', v: el => {
        const input = $(`#${inputId}`, el);
        const number = input && input.value.trim() ? Number(input.value) : NaN;
        return Number.isFinite(number) ? String(clamp(Math.round(number), +d.min, +d.max)) : 'invalid';
      } },
    ],
  });
  if (value === 'invalid') { toast('请输入有效数值'); return; }
  if (value != null && value !== current) {
    setVal(d.s, d.k, value);
    if (S.page === 'tune') renderTune();
  }
}
function fNum(s, k, label, sub, min, max, locked = false) {
  const value = S.ini.get(s, k);
  return `<div class="fld${modCls(s, k)}"><div class="lbl">${label}${sub ? `<small>${esc(sub)}</small>` : ''}</div>
    <button type="button" class="field-sel press nm" ${locked ? 'disabled' : 'data-t="numpick"'} data-s="${s}" data-k="${k}" data-min="${min}" data-max="${max}" aria-label="${esc(label)}${locked ? '，极速档自动最高频' : ''}"><span class="grow sel-val">${esc(value)}</span>${locked ? '' : ic('chev', 'sel-chev')}</button></div>`;
}
function fCores(s, k, label) {
  const sel = new Set(parseCpus(S.ini.get(s, k)));
  const chips = Array.from({ length: S.ncpu }, (_, i) => `<button class="core press ${sel.has(i) ? 'on' : ''}" data-t="core" data-s="${s}" data-k="${k}" data-n="${i}" aria-pressed="${sel.has(i)}">${i}</button>`).join('');
  return `<div class="fld${modCls(s, k)}"><div class="top"><div class="lbl">${label}</div><div class="val" data-v>${esc(S.ini.get(s, k))}</div></div><div class="cores">${chips}</div></div>`;
}

/* ───────── 首页 ───────── */
const topCluster = () => S.clusters[S.clusters.length - 1];
function modeFoot(m) {
  const c = topCluster(); if (!c) return '';
  const cap = capOf(m, c); return `${c.name} ${cap && c.hw && cap >= c.hw ? '不限频' : '≤ ' + fmtG(cap) + ' GHz'}`;
}
function renderHome() {
  const p = $('#page-home');
  if (!S.ready) { p.innerHTML = `<div class="skel" style="height:196px;border-radius:28px"></div><div class="mode-grid" style="margin-top:16px">${'<div class="skel" style="height:104px;border-radius:24px"></div>'.repeat(4)}</div>`; return; }
  if (S.error) { p.innerHTML = `<div class="note err">${ic('warn')}<div class="grow"><b>${esc(S.error.t)}</b><div>${esc(S.error.d)}</div></div></div><button class="btn tonal press" data-act="reload">${ic('refresh')}重试</button>`; return; }
  const m = MID[S.mode] || MID.balance, soc = S.ini.get('meta', 'name'), pr = S.info.prop;
  p.innerHTML = `
  ${S.running ? '' : `<div class="note err">${ic('warn')}<div class="grow"><b>调度守护进程未运行</b><div>档位设置暂未生效。</div></div><button class="btn text press" data-act="restart">重启</button></div>`}
  <section class="hero mode" style="--mh:${m.hue}" id="hero">
    <div class="row"><div class="grow"><div class="name">${esc(soc)}</div><div class="soc">${esc([pr.soc, pr.dev, pr.and && 'Android ' + pr.and].filter(Boolean).join(' · '))}</div></div></div>
    <div class="big">${ic(m.icon)}<div><div class="lbl">当前模式</div><div class="mname" data-hero-name>${m.name}</div></div></div>
  </section>
  <h2 class="sec">切换模式</h2>
  <div class="mode-grid" role="radiogroup" aria-label="调度模式">${MODES.map(x => `
    <button class="mode-card mode press" style="--mh:${x.hue}" role="radio" aria-checked="${x.id === S.mode}" data-mode="${x.id}" ${S.busy ? 'disabled' : ''}>
      ${ic(x.icon)}${ic('check', 'ck')}<div class="n">${x.name}</div><div class="g">${x.tag}</div><div class="f">${modeFoot(x.id)}</div></button>`).join('')}</div>
  <h2 class="sec">实时频率</h2>
  <section class="card" id="live">${S.clusters.map((c, i) => `
    <div class="cl" data-cl="${i}"><div class="hd"><div class="nm">${c.name}<small>cpu${c.cpus}${c.arch ? ' · ' + c.arch : ''} · p${c.policy}</small></div><div class="cf"><span data-cur>–</span><u>GHz</u></div></div>
      <div class="bar"><div class="cur" data-barcur style="width:0"></div><div class="tk" data-tk style="left:${pct(capOf(S.mode, c), c.hw)}%"></div></div>
      <div class="meta"><span>模式上限 <b data-cap>${fmtG(capOf(S.mode, c))}</b></span><span>硬件 ${fmtG(c.hw)}</span><span data-gov></span></div></div>`).join('')}
    <div class="legend-row"><span><b></b>当前</span><span><b class="l"></b>系统允许上限</span><span><b class="d"></b>模式上限</span></div>
    <div class="chips" style="margin-top:12px" id="chips"></div>
  </section>`;
  tickPaint();
}
const pct = (v, max) => (max ? clamp((v / max) * 100, 0, 100) : 0).toFixed(1);
function tickPaint() {
  const L = S.live; if (!L || S.page !== 'home') return;
  S.clusters.forEach((c, i) => {
    const el = $(`[data-cl="${i}"]`); const d = L.pol[c.policy]; if (!el || !d) return;
    const modeCap = capOf(S.mode, c) || d.max;
    $('[data-cur]', el).textContent = fmtG(d.cur);
    $('[data-cap]', el).textContent = fmtG(modeCap);
    $('[data-barcur]', el).style.width = pct(d.cur, c.hw) + '%';
    $('[data-tk]', el).style.left = pct(modeCap, c.hw) + '%';
    $('[data-gov]', el).textContent = d.gov || '';
  });
  const ch = $('#chips'); if (!ch) return; const b = L.bat;
  const charging = b && /^(Charging|Full)$/i.test(String(b.st || '').trim());
  ch.innerHTML = (b && !isNaN(b.cap) ? `<span class="chip static">${ic('battery')}${b.cap}%${charging ? ' 充电中' : ''}</span><span class="chip static">${ic('thermo')}${b.temp.toFixed(1)} °C</span>` : '') +
    `<span class="chip static">${ic('cpu')}${esc(S.clusters[0] && L.pol[S.clusters[0].policy]?.gov || '')}</span>`;
}
function paintConn() {
  const c = $('#conn'); const ok = S.running;
  c.className = 'chip ' + (S.demo ? 'static' : ok ? 'ok' : 'bad');
  c.innerHTML = `<i></i><span>${S.demo ? '演示模式' : S.error ? '未连接' : ok ? '运行中' : '未运行'}</span>`;
  $('#subtitle').textContent = S.ini ? [S.ini.get('meta', 'name'), S.info?.mod?.ver].filter(Boolean).join(' · ') : '正在连接…';
}
async function pollLive() {
  if (!S.ready || S.error || document.hidden || S.page !== 'home') return;
  const L = parseLive(await api.live()); S.live = L;
  const run = !!L.pid; let again = false;
  if (run !== S.running) { S.running = run; again = true; }
  if (L.mode && L.mode !== S.mode && !S.busy && MID[L.mode]) { S.mode = L.mode; S.edit = L.mode; again = true; }
  if (again) { applyTheme(); paintConn(); renderHome(); } else tickPaint();
}
async function setMode(id) {
  if (S.busy) return;
  if (id === S.mode) { renderHome(); return; }
  const prev = S.mode; S.busy = true; S.mode = id; S.edit = id; applyTheme(); renderHome();
  let result;
  try { result = await api.setMode(id); } catch (e) { result = { requested: false, error: String(e) }; }
  S.busy = false;
  if (!result.requested) {
    S.mode = prev; S.edit = prev; applyTheme(); renderHome();
    toast(`切换未写入：${result.error || '请确认模块已启用且接口可用'}`); return;
  }
  const [gpuStatus = '', gpuDetail = ''] = String(result.gpu || '').split('|', 2);
  S.gpuApply = gpuStatus ? { mode: id, status: gpuStatus, detail: gpuDetail } : null;
  if (gpuStatus === 'unsupported') S.info.gpu = { status: 'rejected', detail: gpuDetail };
  // 立刻按配置刷新模式上限（不等待 sysfs）
  renderHome(); renderTune(); tickPaint();
  const checks = [250, 450, 700, 1000];
  let live = null;
  let measured = [];
  let violations = [];
  for (const delay of checks) {
    await new Promise(resolve => setTimeout(resolve, delay));
    live = parseLive(await api.live());
    measured = S.clusters.map(c => {
      const expected = capOf(id, c), actual = live.pol[c.policy]?.max || 0;
      return { expected, actual };
    }).filter(x => x.expected > 0 && x.actual > 0);
    violations = measured.filter(x => x.actual > x.expected);
    if (live.pid && live.mode === id && measured.length && !violations.length) break;
  }
  S.live = live;
  S.running = !!live?.pid;
  if (live?.mode && MID[live.mode]) S.mode = live.mode;
  applyTheme(); renderHome(); tickPaint(); paintConn();
  let cpuResult;
  if (!S.running) cpuResult = '守护进程未运行';
  else if (live.mode !== id) cpuResult = `档位未同步（当前 ${live.mode || '未知'}）`;
  else if (!measured.length) cpuResult = '运行态频率上限不可读取';
  else if (violations.length) cpuResult = `上限校验未通过 ${violations.length}/${measured.length}`;
  else {
    const lower = measured.filter(x => x.actual < x.expected).length;
    cpuResult = `上限校验通过 ${measured.length}/${measured.length}${lower ? `（${lower} 簇受更低系统上限约束）` : ''}`;
  }
  const gpuResult = result.gpu ? `；GPU ${result.gpu.replace('|', '：')}` : '；GPU 状态未返回';
  const commandWarning = result.error ? `；提示 ${result.error}` : '';
  toast(`${MID[id].name}：模式已写入；${cpuResult}${gpuResult}${commandWarning}`, { t: '撤销', fn: () => setMode(prev) });
}

/* ───────── 调校页 ───────── */
function renderTune() {
  const p = $('#page-tune'); if (!S.ready || S.error) { p.innerHTML = ''; return; }
  p.innerHTML = `<div class="tabs" role="tablist"><button class="press ${S.tab === 'mode' ? 'on' : ''}" data-tab="mode" role="tab">模式参数</button><button class="press ${S.tab === 'global' ? 'on' : ''}" data-tab="global" role="tab">全局功能</button></div>` +
    (S.tab === 'mode' ? modeTab() : globalTab());
}
function modeTab() {
  const m = S.edit, I = S.ini;
  const chips = MODES.map(x => `<button class="chip press ${x.id === m ? 'sel' : ''}" data-edit="${x.id}">${ic(x.icon)}${x.name}${x.id === S.mode ? ' · 当前' : ''}</button>`).join('');
  const freq = S.clusters.map((c, i) => c.freqs.length ? fSlider({ s: m, k: c.key + 'CoreMaxFreq', t: 'fq', c: i, kind: 'Max', stops: c.freqs,
      label: c.name, sub: `cpu${c.cpus}${c.arch ? ' · ' + c.arch : ''}`,
      ticks: [] })
    : fNum(m, c.key + 'CoreMaxFreq', c.name + ' 模式上限', 'kHz', 0, 5000000, m === 'fast')).join('');
  const sum = S.clusters.map(c => fmtG(capOf(m, c))).join(' / ');
  const gv = I.get(m, 'scaling_governor');
  const govs = S.clusters.length ? S.clusters[0].govs.filter(g => S.clusters.every(c => c.govs.includes(g))) : [];
  const pars = []; for (let n = 1; n <= 12; n++) { const nm = I.get('ParamSchedPath', 'ParamSchedPath' + n); if (nm) pars.push([n, nm]); }
  const gov = fSelect(m, 'scaling_governor', '调速器', govs, '决定 CPU 频率如何跟随负载变化') +
    (pars.length ? `<div class="param-stack">${pars.map(([n, nm]) => {
      const meta = PARAM[nm] || [nm, ''];
      if (nm === 'up_rate_limit_us' || nm === 'down_rate_limit_us')
        return fSlider({ s: m, k: 'ParamSched' + n, label: meta[0], sub: meta[1], min: 0, max: 30000, step: 250, unit: ' µs' });
      return fNum(m, 'ParamSched' + n, meta[0], meta[1], 0, 1000000);
    }).join('')}</div>` : '');
  const uc = (lbl, a, b) => fSlider({ s: m, k: a, label: lbl + ' uclamp.min', min: 0, max: 100, unit: '%' }) + fSlider({ s: m, k: b, label: lbl + ' uclamp.max', min: 0, max: 100, unit: '%' });
  const g = k => I.get(m, k);
  const usum = `前台应用 ${g('UclampTopAppMin')}–${g('UclampTopAppMax')} · 前台 ${g('UclampForeGroundMin')}–${g('UclampForeGroundMax')} · 后台 ${g('UclampBackGroundMin')}–${g('UclampBackGroundMax')}`;
  const mins = S.clusters.filter(c => I.has(m, c.key + 'CoreMinFreq') && c.freqs.length).map((c, i) => fSlider({ s: m, k: c.key + 'CoreMinFreq', t: 'fq', c: S.clusters.indexOf(c), kind: 'Min', stops: [0, ...c.freqs], label: c.name + ' 频率下限' })).join('');
  const busKeys = ['CPUllccmin','CPUllccmax','CPUddrmin','CPUddrmax'];
  const hasBusConfig = busKeys.every(k => I.has('Bus_dcvs', k)) && busKeys.some(k => I.has(m, k));
  const busFields = busKeys.filter(k => I.has(m, k)).map(k => [k, ({CPUllccmin:'LLCC 最低频率',CPUllccmax:'LLCC 最高频率',CPUddrmin:'DDR 最低频率',CPUddrmax:'DDR 最高频率'})[k]])
    .map(([k, label]) => fNum(m, k, label, 'Hz · 0=自动', 0, 10000000000)).join('');
  return `<div class="chips">${chips}</div>
  ${m !== S.mode ? `<button class="btn tonal press" style="margin-bottom:12px" data-mode="${m}">设为当前模式</button>` : ''}
  ${card('freq', '频率上限', sum + ' GHz', (m === 'fast' ? '<p class="hint">极速档安装时按设备可读取的最高频点自动校准；信息不可读时保留配置值。</p>' : '') + freq)}
  ${card('gov', '调速器与响应', gv, gov)}
  ${card('uclamp', '负载约束 (uclamp)', usum,
    uc('前台应用', 'UclampTopAppMin', 'UclampTopAppMax') + fSwitch(m, 'UclampTopApplatency_sensitive', '前台应用延迟敏感', '优先低延迟唤醒，更跟手但更耗电', '1', '0') +
    uc('前台', 'UclampForeGroundMin', 'UclampForeGroundMax') + uc('后台', 'UclampBackGroundMin', 'UclampBackGroundMax'))}
  ${(() => {
    const gpu = S.info.gpu || {};
    const configured = I.has(m, 'GpuIdleTimerMs');
    const lastApply = S.gpuApply?.mode === m ? S.gpuApply : null;
    let status;
    if (lastApply?.status === 'failed') status = `节点可读写，但本档应用失败：${lastApply.detail}`;
    else if (lastApply?.status === 'unavailable') status = `节点存在但不可读/写，未修改：${lastApply.detail}`;
    else if (gpu.status === 'rejected' || lastApply?.status === 'unsupported')
      status = `本次启动中内核未接受 idle_timer 写入：${gpu.detail || lastApply?.detail || '读回值没有变化'}；本次启动不再尝试，下次开机重新检测。`;
    else if (lastApply) status = `本档最近应用结果：${lastApply.detail || lastApply.status}`;
    else if (gpu.status === 'supported')
      status = '检测到 KGSL idle_timer 节点且当前权限可读写；内核是否接受具体值以切档读回结果为准。';
    else if (gpu.status === 'unwritable') status = '检测到 KGSL idle_timer，但节点不可写；不会尝试修改。';
    else if (gpu.status === 'unreadable') status = '检测到 KGSL idle_timer 节点，但当前不可读；为避免误写，暂不提供调节。';
    else if (gpu.status === 'unsupported') status = '本机未提供 KGSL idle_timer；不会尝试写入。';
    else status = '尚未检测到 KGSL idle_timer 状态。';
    const control = configured && gpu.status === 'supported' && lastApply?.status !== 'unsupported'
      ? fSlider({ s: m, k: 'GpuIdleTimerMs', label: 'GPU 空闲保持时间', sub: 'ms · 0 表示恢复驱动原始值', min: 0, max: 1000, step: 25, unit: ' ms' })
      : `<p class="hint">${esc(configured ? status : `${status} · 当前 SoC 配置未定义此项，不会改写。`)}</p>`;
    return card('gpu-link', 'GPU / CPU 场景协同', status, control);
  })()}
  ${hasBusConfig ? card('bus-link', 'Qualcomm DDR / LLCC 联动',
    S.info.bus.supported ? '已检测到配置引用的 4 个 devfreq 节点；实际是否接受写入仍以运行时为准。' : '不支持：配置所需 devfreq 节点缺失或不可读写，已隐藏频率调节项。',
    S.info.bus.supported ? busFields : `<p class="hint">未应用本档总线频率值。</p>`) : ''}
  ${card('io', '存储与网络', '', fSwitch(m, 'ufsClkGate', 'UFS 时钟门控', '空闲时关闭 UFS 时钟省电，高负载档建议关闭') + fSwitch(m, 'NetWorkOpt', '网络优化', '降低网络收发延迟，略增功耗'))}
  ${mins ? card('min', '频率下限（高级）', '一般保持“不限制”', mins) : ''}`;
}
function globalTab() {
  const I = S.ini;
  const sw = SWITCHES.filter(x => I.has(x[0], x[1]) &&
    (x[1] !== 'AdjIOScheduler' || S.info.ioc.scheduler && S.info.ios.length) &&
    (x[1] !== 'CpuIdleScaling_Governor' || S.info.idleWritable && S.info.idle.length)).map(x => fSwitch(...x)).join('');
  const lb = I.get('function', 'LaunchBoost') === 'true';
  const io = S.info.ios;
  const idle = S.info.idle;
  const ioc = S.info.ioc;
  const busSupported = S.info.bus.supported;
  const ioInvalid = I.get('function', 'AdjIOScheduler') === 'true' && (!io.length || !io.includes(I.get('IO_Settings', 'Scheduler')));
  const idleInvalid = I.get('function', 'CpuIdleScaling_Governor') === 'true' &&
    (!S.info.idleWritable || !idle.length || !idle.includes(I.get('CpuIdle', 'current_governor')));
  const ioHint = ioInvalid ? '当前配置在本机不可用；请选择检测到的选项，或关闭 I/O 调度优化。' :
    io.length ? `本机 ${ioc.queues} 个队列共同支持：${io.join('、')}` : '未检测到所有 I/O 队列共同支持且可写的调度器；该功能开关已隐藏。';
  const idleHint = idleInvalid ? '当前配置在本机不可用；请选择检测到的选项，或关闭自定义 CPU 空闲调速器。' :
    idle.length ? `可用：${idle.join('、')}；当前：${S.info.idleCurrent || '未知'}。切换是否生效仍以设备内核为准。` : '未检测到可写的 CPUIdle governor 接口；该功能开关已隐藏。';
  const ioField = io.length ? fSelect('IO_Settings', 'Scheduler', 'I/O 调度器', io, ioHint) :
    `<div class="fld"><div class="lbl">I/O 调度器</div><small class="hint">${esc(ioHint)}</small></div>`;
  const ioTuneField = ioc.scheduler && ioc.tuning
    ? fSwitch('IO_Settings', 'IO_optimization', 'I/O 队列优化', `检测到 ${ioc.tuned}/${ioc.queues} 个队列的 iostats / nomerges 节点可读写；实际写入仍受内核权限策略约束。`)
    : `<div class="fld"><div class="lbl">I/O 队列优化<small>${!ioc.scheduler ? '不支持：没有所有队列共同支持且可写的 I/O scheduler，开关已隐藏。' : '不支持：缺少可读写的 iostats / nomerges 节点，开关已隐藏。'}</small></div></div>`;
  const idleField = idle.length && S.info.idleWritable ? fSelect('CpuIdle', 'current_governor', 'CPU 空闲调速器', idle, idleHint) :
    `<div class="fld"><div class="lbl">CPU 空闲调速器<small>${esc(idleHint)}</small></div></div>`;
  const busField = S.profile?.startsWith('SDM')
    ? busSupported
      ? fSwitch('Other', 'AdjQcomBus_dcvs', 'Qualcomm DDR/LLCC 总线联动', '配置节点可读写；实际值是否应用仍以运行时写入结果为准。')
      : `<div class="fld"><div class="lbl">Qualcomm DDR/LLCC 总线联动<small>不支持：配置所需 devfreq 节点未全部检测到或不可读写；开关已隐藏。</small></div></div>`
    : '';
  const grp = [['top_app', '前台应用'], ['foreground', '前台'], ['restricted', '受限'], ['system_background', '系统后台'], ['background', '后台']]
    .filter(x => I.has('Cpuset', x[0])).map(x => fCores('Cpuset', x[0], x[1])).join('');
  const topo = S.clusters.map(c => `${c.name} ${c.cpus}`).join(' · ');
  return `${card('sw', '核心功能', '', sw, { collapsible: false })}
  ${lb ? card('lb', '应用启动加速', '启动应用时短暂提频', fSlider({ s: 'LaunchBoost', k: 'BoostRateMs', label: '加速时长', min: 200, max: 3000, step: 100, unit: ' ms' }) +
    fSlider({ s: 'LaunchBoost', k: 'FreqMulti', label: '频率倍数', min: 1, max: 2, step: 0.05, dec: 2, unit: '×' }) +
    fSlider({ s: 'LaunchBoost', k: 'UclampTopAppBoostMin', label: '前台应用 uclamp 下限', min: 0, max: 100, unit: '%' }), { open: true }) : ''}
  ${card('cpuset', '核心分组 (cpuset)', '决定各类进程可使用哪些核心', grp + `<p class="hint" style="margin-top:8px">${esc(topo)}</p>`)}
  ${card('io2', 'I/O 与空闲', '', ioField + ioTuneField + idleField + busField)}
  ${card('eas', 'CFS / EAS 参数（高级）', '一般无需改动', I.keys('EasSchedulerValue').map(k => fNum('EasSchedulerValue', k, k, '', 0, 100000000)).join(''))}`;
}

/* ───────── 字段事件 ───────── */
const dirtyN = () => (S.ini ? S.ini.changes().length : 0);
let raf = 0;
const soonDirty = () => { cancelAnimationFrame(raf); raf = requestAnimationFrame(renderDirty); };
function setVal(s, k, v, el) {
  S.ini.set(s, k, v); el?.closest('.fld')?.classList.toggle('mod', S.ini.mod(s, k)); soonDirty();
  if (s === 'function' && k === 'LaunchBoost') renderTune();
}
function toggleCore(el) {
  const s = el.dataset.s, k = el.dataset.k, n = +el.dataset.n, set = new Set(parseCpus(S.ini.get(s, k)));
  set.has(n) ? set.delete(n) : set.add(n);
  if (!set.size) { toast('至少保留一个核心'); return; }
  const v = rangeStr([...set]); el.classList.toggle('on'); el.setAttribute('aria-pressed', set.has(n));
  $('[data-v]', el.closest('.fld')).textContent = v; setVal(s, k, v, el);
}

/* ───────── 保存条 / 保存 / 放弃 ───────── */
function renderDirty() {
  const n = dirtyN(); S.dirtyCount = n; const box = $('#dirty');
  $('#nav [data-nav="tune"] .badge')?.toggleAttribute('hidden', !n);
  $$('.page').forEach(p => p.classList.toggle('has-bar', n > 0));
  if (!n) { box.innerHTML = ''; return; }
  const txt = `${n} 项未保存`;
  if ($('.dirtybar', box)) { $('.dirtybar .grow', box).textContent = txt; return; }
  box.innerHTML = `<div class="dirtybar"><span class="grow">${txt}</span><button class="btn text press" data-act="discard">放弃</button><button class="btn filled press" data-act="save" ${S.saving ? 'disabled' : ''}>保存并应用</button></div>`;
}
async function save() {
  if (S.saving) return;
  if (!dirtyN()) { toast('没有需要保存的更改'); return; }
  if (S.ini.get('function', 'AdjIOScheduler') === 'true' &&
      (!S.info.ios.length || !S.info.ios.includes(S.ini.get('IO_Settings', 'Scheduler')))) {
    toast('I/O 调度器配置在本机不可用；请选择设备支持项或关闭 I/O 调度器。'); return;
  }
  if (S.ini.get('IO_Settings', 'IO_optimization') === 'true' && (!S.info.ioc.scheduler || !S.info.ioc.tuning)) {
    toast('I/O scheduler 或队列优化节点在本机不可用；请关闭该功能后再保存。'); return;
  }
  if (S.ini.get('function', 'CpuIdleScaling_Governor') === 'true' &&
      (!S.info.idleWritable || !S.info.idle.length || !S.info.idle.includes(S.ini.get('CpuIdle', 'current_governor')))) {
    toast('CPU 空闲调速器配置在本机不可用；请选择设备支持项或关闭该功能。'); return;
  }
  if (S.ini.get('Other', 'AdjQcomBus_dcvs') === 'true' && !S.info.bus.supported) {
    toast('Qualcomm DDR/LLCC devfreq 节点在本机不可用；请关闭该功能后再保存。'); return;
  }
  S.saving = true; renderDirty();
  try {
    const text = S.ini.toString();
    const ok = await api.writeConfig(text);
    if (!ok) { toast('保存失败：无法写入 config.ini'); return; }
    S.ini.commit(); S.iniText = text;
    let restartResult;
    try { restartResult = await api.restart(); }
    catch (e) { restartResult = { running: false, error: String(e) }; }
    S.running = restartResult.running;
    paintConn(); renderDirty(); rerenderAll();
    toast(restartResult.running ? '已保存并应用' :
      `已保存，但守护进程重启失败${restartResult.error ? `：${restartResult.error}` : ''}`);
    setTimeout(pollLive, 600);
    setTimeout(pollLive, 1500);
  } catch (e) {
    toast('保存出错：' + (e && e.message ? e.message : e));
  } finally {
    S.saving = false; renderDirty();
  }
}
async function discard() {
  if (!await confirmD('放弃更改？', `将丢弃 ${dirtyN()} 项未保存的修改。`, '放弃', true)) return;
  S.ini = new Ini(S.iniText); rerenderAll(); renderDirty();
}

/* ───────── 日志页 ───────── */
const LV = [['ALL', '全部'], ['ERROR', '错误'], ['WARNING', '警告'], ['INFO', '信息'], ['DEBUG', '调试']];
function parseLog(t) {
  return t.split('\n').map(l => l.replace(/\r/g, '')).filter(Boolean).map(l => {
    const m = l.match(/^\[?(\d{4}-\d\d-\d\d[ T](\d\d:\d\d:\d\d))\]?\s*(DEBUG|INFO|WARN(?:ING)?|ERROR)?\s*:?\s*(.*)$/i);
    if (!m) return { lv: 'INFO', t: '', m: l };
    let lv = (m[3] || 'INFO').toUpperCase(); if (lv === 'WARN') lv = 'WARNING';
    return { lv, t: m[2], m: m[4] };
  });
}
async function loadLog(scroll) {
  S.logs = parseLog(await api.readLog()); if (S.page === 'log') { renderLog(); if (scroll) $('#main').scrollTop = 1e9; }
}
function renderLog() {
  const p = $('#page-log'); if (!S.ready || S.error) { p.innerHTML = ''; return; }
  if (!S.logs) { p.innerHTML = '<div class="skel" style="height:320px;border-radius:16px"></div>'; return; }
  const cnt = k => (k === 'ALL' ? S.logs.length : S.logs.filter(x => x.lv === k).length);
  const q = S.logQ.trim().toLowerCase();
  const rows = S.logs.filter(x => (S.logLv === 'ALL' || x.lv === S.logLv) && (!q || x.m.toLowerCase().includes(q)));
  p.innerHTML = `
  <div class="logbar"><label class="search">${ic('search')}<input id="q" type="search" placeholder="搜索日志" value="${esc(S.logQ)}" aria-label="搜索日志"></label>
    <button class="icon-btn press" data-act="refreshlog" aria-label="刷新">${ic('refresh')}</button>
    <button class="icon-btn press" data-act="copylog" aria-label="复制">${ic('copy')}</button>
    <button class="icon-btn press" data-act="clearlog" aria-label="清空">${ic('trash')}</button></div>
  <div class="chips" style="margin-bottom:12px">${LV.map(([k, n]) => `<button class="chip press ${S.logLv === k ? 'sel' : ''}" data-lv="${k}">${n} ${cnt(k)}</button>`).join('')}</div>
  ${rows.length ? `<div class="logs mono">${rows.map(x => `<div class="ln ${x.lv}">${x.t ? `<time>${x.t.slice(0, 8)}</time>` : ''}<span>${esc(x.m)}</span></div>`).join('')}</div>`
    : `<div class="empty">${ic('doc')}<div>${S.logs.length ? '没有符合条件的日志' : '暂无日志'}</div><div class="hint">${S.logs.length ? '' : '将日志级别调到 DEBUG 可记录更多细节'}</div></div>`}
  <h2 class="sec">日志设置</h2>${card('lvl', '日志级别', S.ini.get('meta', 'loglevel'), fSelect('meta', 'loglevel', '记录级别', ['DEBUG', 'INFO', 'WARNING', 'ERROR'], '修改后需“保存并应用”'))}`;
  const qi = $('#q'); if (qi && S.keepFocus) { qi.focus(); qi.setSelectionRange(qi.value.length, qi.value.length); }
}

/* ───────── 设置页 ───────── */
function renderSet() {
  const p = $('#page-set'); if (!S.ready || S.error) { p.innerHTML = ''; return; }
  const th = [['auto', '跟随系统', 'auto'], ['light', '浅色', 'sun'], ['dark', '深色', 'moon']];
  const dark = document.documentElement.classList.contains('dark');
  p.innerHTML = `
  <h2 class="sec">外观</h2>
  <section class="card"><div class="seg" role="radiogroup">${th.map(([k, n, i]) => `<button class="press ${prefs.theme === k ? 'on' : ''}" data-theme="${k}" role="radio" aria-checked="${prefs.theme === k}">${ic(i)}${n}</button>`).join('')}</div>
    ${dark ? `<div class="item"><div class="grow"><div class="t">纯黑背景</div><div class="s">OLED 屏幕更省电</div></div><button class="switch" role="switch" aria-checked="${prefs.amoled}" data-pref="amoled" aria-label="纯黑背景"></button></div>` : ''}
    <div class="item" style="margin-top:8px"><div class="grow"><div class="t">主题色跟随调度模式</div><div class="s">开启后界面主色随省电/均衡/性能/极速变化</div></div>
      <button class="switch" role="switch" aria-checked="${prefs.seedMode}" data-pref="seedMode" aria-label="主题色跟随调度模式"></button></div>
    <div class="lbl" style="margin-top:12px;font-weight:500">固定主题色</div><div class="hint">关闭上方开关后生效</div>
    <div class="swatches">${HUES.map(([h, n]) => `<button class="sw-dot ${!prefs.seedMode && prefs.seed === h ? 'on' : ''}" style="--sh:${h}" data-seed="${h}" aria-label="${n}" ${prefs.seedMode ? 'disabled' : ''}>${ic('check')}</button>`).join('')}</div></section>
  <h2 class="sec">配置</h2>
  <section class="card" style="padding-top:4px;padding-bottom:4px">
    <button class="item press" data-act="backup">${ic('down')}<div class="grow"><div class="t">备份当前配置</div><div class="s">保存一份带时间戳的副本</div></div></button>
    <button class="item press" data-act="restore">${ic('history')}<div class="grow"><div class="t">从备份恢复</div><div class="s">选择备份或上次保存前的版本</div></div></button>
    <button class="item press" data-act="restoreDefault">${ic('undo')}<div class="grow"><div class="t">恢复出厂配置</div><div class="s">还原为模块为本机生成的默认档位</div></div></button>
    <button class="item press" data-act="restart">${ic('power')}<div class="grow"><div class="t">重启调度守护进程</div><div class="s">${S.running ? '当前运行中' : '当前未运行'}</div></div></button></section>
  <h2 class="sec">关于</h2>
  <section class="card">
    <div class="kv"><span>模块</span><span>G_CTS ${esc(S.info.mod.ver || '')}</span></div>
    <div class="kv"><span>处理器</span><span>${esc(S.ini.get('meta', 'name'))}${S.profile ? ' · ' + S.profile : ''}</span></div>
    <div class="kv"><span>内核</span><span>${esc(S.info.prop.kern || '')}</span></div>
    <div class="kv"><span>作者</span><span>Ghost（基于 MoWei 二改）</span></div>
    <p class="hint" style="margin:8px 0 0">本模块不再内置控制端 App。可在 Scene 中直接切换模式（通过 /data/powercfg.sh 联动），也可使用本页面。</p></section>`;
}

/* ───────── 导航与分发 ───────── */
const NAV = [['home', '调度', 'cpu'], ['tune', '调校', 'tune'], ['log', '日志', 'doc'], ['set', '设置', 'gear']];
function renderNav() {
  const nav = $('#nav');
  const existing = $$('[data-nav]', nav);
  if (existing.length === NAV.length) {
    // 就地更新 class，保留药丸过渡动画
    existing.forEach((btn, i) => {
      const [id] = NAV[i];
      const on = S.page === id;
      btn.classList.toggle('on', on);
      btn.setAttribute('aria-selected', on);
    });
  } else {
    nav.innerHTML = NAV.map(([id, n, i]) => `<button class="${S.page === id ? 'on' : ''}" data-nav="${id}" role="tab" aria-selected="${S.page === id}"><span class="pill">${ic(i)}</span>${n}${id === 'tune' ? '<i class="badge" hidden></i>' : ''}</button>`).join('');
  }
  renderDirty();
}
function showPage(id) {
  S.page = id; NAV.forEach(([k]) => { $('#page-' + k).hidden = k !== id; });
  renderNav(); $('#main').scrollTop = 0;
  ({ home: () => { renderHome(); pollLive(); }, tune: renderTune, log: () => { S.logs ? renderLog() : loadLog(true); }, set: renderSet })[id]();
}
function rerenderAll() { renderHome(); renderTune(); renderLog(); renderSet(); paintConn(); }
async function loadConfig() {
  const text = await api.readConfig(); if (!text) throw new Error('config');
  S.iniText = text; S.ini = new Ini(text); buildContext();
}
async function doAct(a, el) {
  switch (a) {
    case 'save': return save();
    case 'discard': return discard();
    case 'reload': return boot();
    case 'restart': {
      toast('正在重启守护进程…');
      const result = await api.restart();
      S.running = result.running; paintConn(); rerenderAll();
      return toast(result.running ? '守护进程已启动' :
        `重启失败${result.error ? `：${result.error}` : ''}`);
    }
    case 'refreshlog': return loadLog(true);
    case 'copylog': { const t = (S.logs || []).map(x => `${x.t} ${x.lv} ${x.m}`).join('\n'); try { await navigator.clipboard.writeText(t); } catch { const ta = document.createElement('textarea'); ta.value = t; document.body.append(ta); ta.select(); document.execCommand('copy'); ta.remove(); } return toast('已复制日志'); }
    case 'clearlog': if (await confirmD('清空日志？', '将清空 log.txt，此操作无法撤销。', '清空', true)) { await api.clearLog(); S.logs = []; renderLog(); toast('日志已清空'); } return;
    case 'backup': { const n = await api.backup(); return toast(n ? '已备份：' + n.replace('config.ini.', '') : '备份失败'); }
    case 'restore': {
      const l = await api.backups(); if (!l.length) return toast('没有可用的备份');
      const v = await dialog({ title: '从备份恢复', body: l.slice(0, 6).map(n => `<button class="opt press" data-pick="${esc(n)}">${ic('history')}<span>${n === 'config.ini.last' ? '上次保存前的版本' : esc(n.replace('config.ini.bak.', ''))}</span></button>`).join(''), acts: [{ t: '取消', v: null }] });
      if (v && await api.restore(v)) {
        await loadConfig();
        const result = await api.restart();
        S.running = result.running; rerenderAll();
        toast(result.running ? '已恢复并应用' :
          `配置已恢复，但守护进程重启失败${result.error ? `：${result.error}` : ''}`);
      } else if (v) toast('恢复失败');
      return;
    }
    case 'restoreDefault': if (await confirmD('恢复出厂配置？', '将用模块为本机生成的默认档位覆盖当前配置（当前配置会保存为“上次保存前的版本”）。', '恢复', true)) {
      await api.backup();
      if (await api.restoreDefault()) {
        await loadConfig();
        const result = await api.restart();
        S.running = result.running; rerenderAll(); applyTheme();
        toast(result.running ? '已恢复出厂配置并应用' :
          `配置已恢复，但守护进程重启失败${result.error ? `：${result.error}` : ''}`);
      } else toast('恢复失败');
    }
    return;
  }
}
document.addEventListener('click', e => {
  const t = e.target.closest('[data-nav],[data-mode],[data-acc],[data-tab],[data-edit],[data-act],[data-lv],[data-theme],[data-seed],[data-pref],[data-t="sw"],[data-t="core"],[data-t="pick"],[data-t="sliderpick"],[data-t="numpick"]');
  if (!t) return; const d = t.dataset;
  if (d.nav) showPage(d.nav);
  else if (d.mode) setMode(d.mode);
  else if (d.acc) { S.open[d.acc] = !S.open[d.acc]; const c = t.closest('.card'); c.classList.toggle('open', S.open[d.acc]); t.setAttribute('aria-expanded', S.open[d.acc]); }
  else if (d.tab) { S.tab = d.tab; renderTune(); }
  else if (d.edit) { S.edit = d.edit; renderTune(); }
  else if (d.act) doAct(d.act, t);
  else if (d.lv) { S.logLv = d.lv; renderLog(); }
  else if (d.theme) { prefs.theme = d.theme; savePrefs(); applyTheme(); renderSet(); }
  else if (d.seed) { prefs.seed = +d.seed; prefs.seedMode = false; savePrefs(); applyTheme(); renderSet(); }
  else if (d.pref) { prefs[d.pref] = !prefs[d.pref]; savePrefs(); applyTheme(); renderSet(); }
  else if (d.t === 'sw') { const on = t.getAttribute('aria-checked') !== 'true'; t.setAttribute('aria-checked', on); setVal(d.s, d.k, on ? d.on : d.off, t); }
  else if (d.t === 'core') toggleCore(t);
  else if (d.t === 'sliderpick') openSliderPicker(d, t.getAttribute('aria-label').replace(/，点击选择$/, ''));
  else if (d.t === 'numpick') openNumberPicker(d, t.getAttribute('aria-label'));
  else if (d.t === 'pick') {
    const opts = (d.opts || '').split('\u001f').filter(Boolean);
    const lbl = t.getAttribute('aria-label') || '选择';
    openPicker(d.s, d.k, lbl, opts);
  }
});
document.addEventListener('input', e => {
  if (e.target.id === 'q') { S.logQ = e.target.value; S.keepFocus = true; renderLog(); S.keepFocus = false; }
});
$('#main').addEventListener('scroll', e => $('#appbar').classList.toggle('scrolled', e.target.scrollTop > 4), { passive: true });
document.addEventListener('visibilitychange', () => { if (!document.hidden) pollLive(); });
addEventListener('beforeunload', e => { if (dirtyN()) { e.preventDefault(); e.returnValue = ''; } });

/* ───────── 启动 ───────── */
const loadScript = src => new Promise((ok, no) => { const s = document.createElement('script'); s.src = src; s.onload = ok; s.onerror = no; document.head.append(s); });
async function boot() {
  S.ready = false; S.error = null; applyTheme(); renderNav(); renderHome();
  if (!window.ksu) { S.demo = true; try { await loadScript('demo.js'); api = window.__demoApi; } catch {} }
  try {
    S.info = parseInfo(await api.info());
    if (!Object.keys(S.info.pol).length) throw Object.assign(new Error('pol'), { d: '读取不到 CPU 频率信息，请确认已授予 root 权限。' });
    await loadConfig();
    const L = parseLive(await api.live()); S.live = L; S.running = !!L.pid;
    S.mode = MID[L.mode] ? L.mode : 'balance'; S.edit = S.mode; S.ready = true;
  } catch (e) {
    S.error = { t: '无法读取模块配置', d: e.d || `未找到 ${SD}/config.ini。请确认模块已启用并重启一次手机，或重新刷入模块。` };
    S.ready = true;
  }
  applyTheme(); rerenderAll(); renderNav();
}
boot();
setInterval(pollLive, 5000);
})();
