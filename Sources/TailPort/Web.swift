// 單頁網頁 UI:冷灰 + 琥珀金配色。為了節省手機 GPU,不使用 backdrop-filter 與光暈陰影。
let webPage = #"""
<!doctype html>
<html lang="zh-Hant">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">
<meta name="theme-color" content="#2E2F31">
<title>TailPort</title>
<style>
:root {
  --bg: #3C3F41; --surface: #2E2F31; --surface-hi: #4D5053; --border: rgba(255,255,255,0.12);
  --text: #FFFFFF; --muted: #BFC3C5; --gray: #747474;
  --accent: #FFD700; --accent-hover: #E6C200;
  --green: #4caf50; --red: #ef9a9a; --red-bg: rgba(229,57,53,0.16);
}
* { box-sizing: border-box; margin: 0; padding: 0; -webkit-tap-highlight-color: transparent; }
html { background: var(--bg); touch-action: manipulation; }   /* 禁止雙擊放大(仍可正常捲動) */
/* 禁止選取文字與長按選單;輸入框例外,否則無法輸入 */
body { -webkit-user-select: none; user-select: none; -webkit-touch-callout: none; }
input { -webkit-user-select: text; user-select: text; }
a, img { -webkit-user-drag: none; }
body {
  min-height: 100vh; color: var(--text); font-size: 15px; line-height: 1.45;
  font-family: -apple-system, BlinkMacSystemFont, 'SF Pro', 'PingFang TC', 'Inter', 'Roboto', 'Microsoft JhengHei UI', sans-serif;
  background: linear-gradient(160deg, #9E9E9E 0%, #6F7174 40%, #4A4B4D 100%);
  background-attachment: fixed;
  padding: 0 0 calc(80px + env(safe-area-inset-bottom));
}
header {
  position: sticky; top: 0; z-index: 50; display: flex; align-items: center; gap: 8px;
  padding: calc(env(safe-area-inset-top) + 16px) calc(16px + env(safe-area-inset-right)) 12px calc(16px + env(safe-area-inset-left));
  background: var(--surface); border-bottom: 1px solid var(--border);
}
header h1 { flex: 1; font-size: 18px; font-weight: 700; letter-spacing: -0.3px; }
main { max-width: 720px; margin: 0 auto; padding: 14px max(12px, env(safe-area-inset-right)) 0 max(12px, env(safe-area-inset-left)); display: flex; flex-direction: column; gap: 14px; }

button, input { font-family: inherit; }
.btn {
  height: 38px; padding: 0 14px; border-radius: 12px; cursor: pointer; font-size: 14px; font-weight: 500;
  color: var(--accent); background: var(--surface-hi); border: 1px solid var(--border);
}
.btn:active { background: #5a5e61; }
.btn:disabled { opacity: .45; cursor: default; }
.btn.primary { background: var(--accent); color: #1a1a1a; border-color: transparent; font-weight: 600; }
.btn.primary:active { background: var(--accent-hover); }
.btn.danger { color: var(--red); background: var(--red-bg); border-color: rgba(239,154,154,0.25); }
.btn.icon { width: 42px; height: 42px; padding: 0; display: flex; align-items: center; justify-content: center; }
.btn.icon svg { width: 22px; height: 22px; fill: currentColor; }
.btn.icon.spin svg { animation: spin 1s linear infinite; }
@keyframes spin { to { transform: rotate(360deg); } }

.card { background: var(--surface); border: 1px solid var(--border); border-radius: 16px; padding: 14px; }
details.card > summary { list-style: none; cursor: pointer; display: flex; align-items: center; gap: 10px; }
details.card > summary::-webkit-details-marker { display: none; }
.dot { width: 10px; height: 10px; border-radius: 50%; flex: none; background: var(--green); }
.name { flex: 1; min-width: 0; font-size: 16px; font-weight: 700; overflow-wrap: anywhere; }
.chip { flex: none; font-size: 12px; color: var(--muted); background: var(--surface-hi); padding: 2px 10px; border-radius: 10px; }
.chip.count { color: var(--accent); background: rgba(255,215,0,0.12); }
.copy { width: 32px; height: 32px; border-radius: 8px; flex: none; display: flex; align-items: center; justify-content: center;
  cursor: pointer; padding: 0; color: var(--accent); background: var(--surface-hi); border: 1px solid var(--border); }
.copy svg { width: 16px; height: 16px; fill: currentColor; }
.copy.done { color: var(--green); }
.caret { width: 28px; height: 28px; border-radius: 8px; flex: none; display: flex; align-items: center; justify-content: center;
  color: var(--accent); background: var(--surface-hi); }
.caret svg { width: 20px; height: 20px; fill: currentColor; transition: transform .2s ease; }
details[open] > summary .caret svg { transform: rotate(180deg); }
.ip { margin-top: 10px; font-size: 12px; color: var(--muted); }
.links { margin-top: 10px; display: flex; flex-direction: column; gap: 8px; }
a.link {
  display: flex; align-items: center; gap: 10px; padding: 10px 12px; border-radius: 12px; text-decoration: none;
  color: var(--text); background: var(--bg); border: 1px solid var(--border);
}
a.link:active { background: var(--surface-hi); }
a.link b { flex: 1; min-width: 0; font-weight: 600; overflow-wrap: anywhere; }
a.link span { font-size: 12px; color: var(--accent); }

.empty, .note { text-align: center; font-size: 13px; color: var(--muted); padding: 24px 8px; }
.note { padding: 0 4px; font-size: 12px; text-align: left; }
.err { color: var(--red); background: var(--red-bg); border-radius: 12px; padding: 12px 14px; font-size: 14px; }

/* 設定對話框 */
#overlay { position: fixed; inset: 0; z-index: 100; display: flex; align-items: center; justify-content: center;
  padding: 24px; background: rgba(0,0,0,0.6); }
.dialog { width: min(460px, 100%); max-height: calc(100vh - 48px); overflow-y: auto; background: var(--bg);
  border: 1px solid var(--border); border-radius: 16px; padding: 22px 18px 18px; }
.dialog h2 { font-size: 20px; margin-bottom: 4px; }
.dialog p { font-size: 13px; color: var(--muted); margin-bottom: 14px; }
.prow { display: flex; flex-wrap: wrap; gap: 8px; margin-bottom: 14px; align-items: center; }
.prow input.f { width: 24px; height: 24px; flex: none; accent-color: var(--accent); cursor: pointer; padding: 0; }
.prow input { height: 40px; padding: 0 10px; border-radius: 10px; color: var(--text); font-size: 16px;
  background: rgba(0,0,0,0.2); border: 1px solid rgba(255,255,255,0.16); outline: none; min-width: 0; }
.prow input:focus { border-color: var(--accent); }
.prow input.p { width: 84px; flex: none; }
.prow input.n { flex: 1 0 100%; order: 5; }   /* 名稱獨佔第二行,手機寬度才放得下 */
.prow .grow { flex: 1; }
.prow select { height: 40px; width: 88px; padding: 0 26px 0 12px; border-radius: 10px; color: var(--text); font-size: 16px; flex: none;
  -webkit-appearance: none; appearance: none; cursor: pointer; outline: none;
  background: rgba(0,0,0,0.2) url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%23BFC3C5'%3E%3Cpath d='M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6z'/%3E%3C/svg%3E") no-repeat right 4px center / 20px;
  border: 1px solid rgba(255,255,255,0.16); }
.prow select:focus { border-color: var(--accent); }
.prow select option { background: var(--surface); }
.foot { display: flex; flex-direction: column; gap: 10px; margin-top: 16px; }
.foot .btn { height: 45px; font-size: 16px; font-weight: 700; border-radius: 10px; }
</style>
</head>
<body>
<header>
  <h1>TailPort</h1>
  <button class="btn icon" onclick="openSettings()" aria-label="設定埠" title="設定要尋找的埠">
    <svg viewBox="0 0 24 24"><path d="M19.14 12.94c.04-.3.06-.61.06-.94s-.02-.64-.07-.94l2.03-1.58a.49.49 0 0 0 .12-.61l-1.92-3.32a.49.49 0 0 0-.59-.22l-2.39.96a7.03 7.03 0 0 0-1.62-.94l-.36-2.54a.48.48 0 0 0-.48-.41h-3.84a.48.48 0 0 0-.48.41l-.36 2.54c-.59.24-1.13.57-1.62.94l-2.39-.96a.48.48 0 0 0-.59.22L2.74 8.87a.48.48 0 0 0 .12.61l2.03 1.58c-.05.3-.09.63-.09.94s.02.64.07.94l-2.03 1.58a.49.49 0 0 0-.12.61l1.92 3.32c.12.22.37.29.59.22l2.39-.96c.5.38 1.03.7 1.62.94l.36 2.54c.05.24.24.41.48.41h3.84c.24 0 .44-.17.47-.41l.36-2.54c.59-.24 1.13-.56 1.62-.94l2.39.96c.22.08.47 0 .59-.22l1.92-3.32a.49.49 0 0 0-.12-.61l-2.01-1.58zM12 15.6a3.6 3.6 0 1 1 0-7.2 3.6 3.6 0 0 1 0 7.2z"/></svg>
  </button>
  <button class="btn icon" id="refresh" onclick="load()" aria-label="重新整理" title="重新整理">
    <svg viewBox="0 0 24 24"><path d="M17.65 6.35A7.958 7.958 0 0 0 12 4c-4.42 0-7.99 3.58-7.99 8s3.57 8 7.99 8c3.73 0 6.84-2.55 7.73-6h-2.08A5.99 5.99 0 0 1 12 18c-3.31 0-6-2.69-6-6s2.69-6 6-6c1.66 0 3.14.69 4.22 1.78L13 11h7V4l-2.35 2.35z"/></svg>
  </button>
</header>
<main>
  <div id="err" class="err" hidden></div>
  <div id="list" style="display:flex;flex-direction:column;gap:14px"></div>
  <div id="empty" class="empty" hidden></div>
  <div id="note" class="note"></div>
</main>
<script>
const $ = id => document.getElementById(id);
const CARET = '<svg viewBox="0 0 24 24"><path d="M7.41 8.59 12 13.17l4.59-4.58L18 10l-6 6-6-6z"/></svg>';
const openCards = new Set();
let loading = false;

const COPY_SVG = '<svg viewBox="0 0 24 24"><path d="M16 1H4c-1.1 0-2 .9-2 2v14h2V3h12V1zm3 4H8c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h11c1.1 0 2-.9 2-2V7c0-1.1-.9-2-2-2zm0 16H8V7h11v14z"/></svg>';
const CHECK_SVG = '<svg viewBox="0 0 24 24"><path d="M9 16.17 4.83 12l-1.42 1.41L9 19 21 7l-1.41-1.41z"/></svg>';

// 區網 http 不是 secure context,navigator.clipboard 不可用,所以用 textarea + execCommand 當後備
async function copyText(text) {
  try { if (navigator.clipboard && window.isSecureContext) { await navigator.clipboard.writeText(text); return true; } } catch (e) {}
  const t = el('textarea', { value: text });
  t.style.cssText = 'position:fixed;top:0;left:0;opacity:0';
  document.body.append(t); t.focus(); t.select();
  let ok = false;
  try { ok = document.execCommand('copy'); } catch (e) {}
  t.remove();
  return ok;
}

function el(tag, props, ...kids) {
  const e = Object.assign(document.createElement(tag), props || {});
  e.append(...kids);
  return e;
}

async function api(path, body) {
  const r = await fetch(path, body === undefined ? {} : {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  const j = await r.json();
  if (!r.ok) throw new Error(j.error || r.statusText);
  return j;
}

async function load() {
  if (loading) return;
  loading = true;
  $('refresh').classList.add('spin');
  try {
    const j = await api('/api/scan');
    render(j);
  } catch (e) {
    showError('掃描失敗:' + e.message);
  } finally {
    loading = false;
    $('refresh').classList.remove('spin');
  }
}

function copyBtn(text) {
  const b = el('button', { type: 'button', className: 'copy', title: '拷貝 Tailscale IP ' + text, innerHTML: COPY_SVG });
  b.setAttribute('aria-label', '拷貝 Tailscale IP');
  b.onclick = async e => {
    e.preventDefault(); e.stopPropagation();   // 不要觸發卡片展開
    const ok = await copyText(text);
    b.classList.toggle('done', ok);
    b.innerHTML = ok ? CHECK_SVG : COPY_SVG;
    b.title = ok ? '已拷貝 ' + text : '拷貝失敗,請手動複製 ' + text;
    setTimeout(() => { b.classList.remove('done'); b.innerHTML = COPY_SVG; }, 1500);
  };
  return b;
}

function showError(text) {
  $('err').hidden = !text;
  $('err').textContent = text || '';
}

function render(j) {
  showError(j.error);
  const list = $('list');
  list.replaceChildren();
  for (const d of j.devices) {
    const key = d.ip;
    // 這台 Mac 自己的服務,連結使用瀏覽器網址列的主機,例如用 192.168.x.x 連進來就用該位址開;其他裝置一律用 Tailscale IP
    const host = d.self ? location.hostname : d.ip;
    const card = el('details', { className: 'card', open: openCards.has(key) });
    card.ontoggle = () => { card.open ? openCards.add(key) : openCards.delete(key); };
    const sum = el('summary', {},
      el('span', { className: 'dot' }),
      el('span', { className: 'name', textContent: d.name }),
      el('span', { className: 'chip count', textContent: d.open.length + ' 個服務' }),
      copyBtn(d.ip),
      el('span', { className: 'caret', innerHTML: CARET }));
    const links = el('div', { className: 'links' });
    for (const o of d.open) {
      links.append(el('a', Object.assign({ className: 'link', href: o.scheme + '://' + host + ':' + o.port }, o.scheme.startsWith('http') ? { target: '_blank', rel: 'noopener' } : {}),
        el('b', { textContent: o.name }), el('span', { textContent: (o.scheme.startsWith('http') ? '' : o.scheme + ' ') + ':' + o.port })));
    }
    card.append(sum, el('div', { className: 'ip', textContent: d.ip + (d.os ? ' · ' + d.os : '') + (d.self ? ' · 這台 Mac(連結使用 ' + host + ')' : '') }), links);
    list.append(card);
  }
  const empty = $('empty');
  empty.hidden = j.devices.length > 0 || !!j.error;
  empty.textContent = j.scanned ? '沒有裝置開著指定的埠' : '';
  $('note').textContent = j.error ? '' : '已掃描 ' + j.scanned + ' 台上線裝置 · 點卡片展開,點服務名稱開新分頁';
}

async function openSettings() {
  let ports;
  try { ports = (await api('/api/ports')).ports; } catch (e) { showError(e.message); return; }
  const rows = el('div');
  const SCHEMES = ['http', 'https', 'vnc', 'ssh', 'smb'];
  const addRow = (p, n, sc = 'http', f = false) => {
    const row = el('div', { className: 'prow' },
      el('input', { className: 'f', type: 'checkbox', checked: f, title: '只顯示這個埠' }),
      el('input', { className: 'p', type: 'number', inputMode: 'numeric', min: 1, max: 65535, placeholder: '埠', value: p }),
      el('input', { className: 'n', type: 'text', placeholder: '名稱', value: n }),
      el('select', { className: 's', title: '連結協定' }, ...SCHEMES.map(x => el('option', { value: x, textContent: x, selected: x === sc }))),
      el('button', { className: 'btn danger', type: 'button', textContent: '✕', onclick: () => row.remove() }));
    row.querySelector('.p').after(el('span', { className: 'grow' }));
    rows.append(row);
    return row;
  };
  ports.forEach(p => addRow(p.port, p.name, p.scheme, p.filter));
  const msg = el('div', { className: 'err', hidden: true });
  const close = () => ov.remove();
  const save = async () => {
    const out = [...rows.children].map(r => ({ port: r.querySelector('.p').value.trim(), name: r.querySelector('.n').value, scheme: r.querySelector('.s').value, filter: r.querySelector('.f').checked }))
      .filter(r => r.port !== '');
    try {
      await api('/api/ports', { ports: out.map(r => ({ port: Number(r.port), name: r.name, scheme: r.scheme, filter: r.filter })) });
      close();
      load();
    } catch (e) { msg.hidden = false; msg.textContent = e.message; }
  };
  const ov = el('div', { id: 'overlay', onclick: e => { if (e.target === ov) close(); } },
    el('div', { className: 'dialog' },
      el('h2', { textContent: '要尋找的埠' }),
      el('p', { textContent: '裝置只要開著其中任一個埠,就會出現卡片。左邊的核取方塊用來篩選:全不勾(預設)或全勾顯示全部,只勾部分時就只顯示勾選的埠。' }),
      rows,
      el('button', { className: 'btn', type: 'button', textContent: '＋ 新增一個埠', onclick: () => addRow('', '').querySelector('.p').focus() }),
      msg,
      el('div', { className: 'foot' },
        el('button', { className: 'btn primary', type: 'button', textContent: '儲存並重新掃描', onclick: save }),
        el('button', { className: 'btn', type: 'button', textContent: '取消', onclick: close }))));
  document.body.append(ov);
}

// iOS Safari 忽略 user-scalable=no,另外擋掉雙指縮放手勢
document.addEventListener('gesturestart', e => e.preventDefault());
load();
setInterval(() => { if (!document.hidden && !$('overlay')) load(); }, 30000);
document.addEventListener('visibilitychange', () => { if (!document.hidden && !$('overlay')) load(); });
</script>
</body>
</html>
"""#
