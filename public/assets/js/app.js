// ============================================================
//  LoadBalancer Pro — Frontend JS
// ============================================================

// ---- API helper ----
const api = {
  async req(method, path, body = null) {
    const opts = { method, headers: { 'Content-Type': 'application/json' } };
    if (body) opts.body = JSON.stringify(body);
    const res = await fetch('/api/v1' + path, opts);
    return res.json();
  },
  get:    (p)    => api.req('GET',    p),
  post:   (p, b) => api.req('POST',   p, b),
  put:    (p, b) => api.req('PUT',    p, b),
  delete: (p)    => api.req('DELETE', p),
};

// ---- Modal helpers ----
function openModal(id)  { document.getElementById(id)?.classList.add('open'); }
function closeModal(id) { document.getElementById(id)?.classList.remove('open'); }
document.addEventListener('keydown', e => {
  if (e.key === 'Escape') document.querySelectorAll('.modal-overlay.open').forEach(m => m.classList.remove('open'));
});

// ---- Topbar live stats ----
async function refreshTopbar() {
  try {
    const { data } = await api.get('/stats/summary');
    if (!data) return;
    setText('stat-up-count', data.interfaces_up + '/' + data.interfaces_total);
    setText('stat-sess-val',  data.pppoe_sessions);
  } catch(e) {}
}

// ---- Sparklines ----
function buildSparkline(el, color = '#3b82f6') {
  if (!el) return;
  el.innerHTML = '';
  for (let i = 0; i < 14; i++) {
    const bar = document.createElement('div');
    bar.className = 'spark-bar';
    bar.style.height = (Math.random() * 22 + 4) + 'px';
    bar.style.background = color;
    el.appendChild(bar);
  }
  setInterval(() => {
    const b = document.createElement('div');
    b.className = 'spark-bar';
    b.style.height = (Math.random() * 22 + 4) + 'px';
    b.style.background = color;
    el.firstChild?.remove();
    el.appendChild(b);
  }, 1500);
}

// ---- Utility ----
function setText(id, val) { const el = document.getElementById(id); if (el) el.textContent = val; }
function formatBytes(b) {
  if (b < 1024) return b + ' B';
  if (b < 1048576) return (b/1024).toFixed(1) + ' KB';
  if (b < 1073741824) return (b/1048576).toFixed(1) + ' MB';
  return (b/1073741824).toFixed(2) + ' GB';
}
function formatSpeed(bps) {
  if (bps < 1000) return bps + ' bps';
  if (bps < 1e6) return (bps/1000).toFixed(1) + ' Kbps';
  if (bps < 1e9) return (bps/1e6).toFixed(1) + ' Mbps';
  return (bps/1e9).toFixed(2) + ' Gbps';
}

// ---- Confirm delete ----
function confirmDelete(msg, onConfirm) {
  if (confirm(msg || 'هل أنت متأكد من الحذف؟')) onConfirm();
}

// ---- Toast notifications ----
function toast(msg, type = 'info') {
  let wrap = document.getElementById('toast-wrap');
  if (!wrap) {
    wrap = document.createElement('div');
    wrap.id = 'toast-wrap';
    wrap.style.cssText = 'position:fixed;bottom:20px;left:20px;z-index:999;display:flex;flex-direction:column;gap:8px';
    document.body.appendChild(wrap);
  }
  const t = document.createElement('div');
  const colors = { info:'#3b82f6', success:'#22c55e', error:'#ef4444', warning:'#f59e0b' };
  t.style.cssText = `background:#13161e;border:1px solid ${colors[type]||colors.info};border-right:3px solid ${colors[type]||colors.info};color:#e2e8f0;padding:10px 16px;border-radius:8px;font-size:12px;max-width:300px;animation:fadeIn .2s ease`;
  t.textContent = msg;
  wrap.appendChild(t);
  setTimeout(() => t.remove(), 3500);
}

// ---- Page-specific inits ----
document.addEventListener('DOMContentLoaded', () => {
  refreshTopbar();
  setInterval(refreshTopbar, 15000);

  // Sparklines on dashboard
  document.querySelectorAll('.sparkline').forEach(el => {
    buildSparkline(el, el.dataset.color || '#3b82f6');
  });

  // Range sliders
  document.querySelectorAll('input[type=range]').forEach(inp => {
    const out = inp.nextElementSibling;
    if (out) inp.addEventListener('input', () => out.textContent = inp.value);
  });

  // Auto-close modal on overlay click
  document.querySelectorAll('.modal-overlay').forEach(mo => {
    mo.addEventListener('click', e => { if (e.target === mo) mo.classList.remove('open'); });
  });
});

// ---- Interface type form toggle ----
function ifaceTypeChange(sel) {
  const type = sel.value;
  document.getElementById('pppoe-fields') ?.style && (document.getElementById('pppoe-fields').style.display  = type === 'pppoe'   ? '' : 'none');
  document.getElementById('dhcp-fields')  ?.style && (document.getElementById('dhcp-fields').style.display   = type === 'dhcp'    ? '' : 'none');
  document.getElementById('static-fields')?.style && (document.getElementById('static-fields').style.display = type === 'static'  ? '' : 'none');
}

// ---- API key generator ----
async function generateApiKey(formId, resultId) {
  const form = document.getElementById(formId);
  if (!form) return;
  const name  = form.querySelector('[name=key_name]')?.value;
  const perms = [...form.querySelectorAll('[name=perm]:checked')].map(c => c.value);
  if (!name) return toast('أدخل اسم المفتاح', 'error');
  const { data } = await api.post('/api-keys', { name, permissions: perms });
  if (data?.key) {
    const box = document.getElementById(resultId);
    if (box) { box.textContent = data.key; box.closest('.api-key-result')?.style && (box.closest('.api-key-result').style.display = ''); }
    toast('تم إنشاء المفتاح — احفظه الآن!', 'success');
  }
}

// ---- PPPoE actions ----
async function pppoeAction(id, action) {
  const { data } = await api.post(`/pppoe/${id}/${action}`);
  toast(data?.ok ? (action === 'connect' ? 'جاري الاتصال...' : 'تم قطع الاتصال') : 'خطأ في العملية',
    data?.ok ? 'success' : 'error');
  setTimeout(() => location.reload(), 1200);
}

// ---- Load balancer apply ----
async function applyLB() {
  const { data } = await api.post('/loadbalancer/apply');
  toast(data?.applied ? 'تم تطبيق Load Balancer' : 'خطأ في التطبيق', data?.applied ? 'success' : 'error');
}

// ---- Save LB weights ----
async function saveLBWeights() {
  const weights = {};
  document.querySelectorAll('[data-iface-id]').forEach(el => {
    weights[el.dataset.ifaceId] = el.value;
  });
  await api.put('/loadbalancer/weights', { weights });
  toast('تم حفظ الأوزان وتطبيق التوزيع', 'success');
}

// ---- Delete route ----
async function deleteRoute(id) {
  confirmDelete('حذف هذا المسار؟', async () => {
    await api.delete('/routes/' + id);
    toast('تم الحذف', 'success');
    setTimeout(() => location.reload(), 800);
  });
}

// ---- Delete VLAN ----
async function deleteVlan(id) {
  confirmDelete('سيتم حذف الـ VLAN وإيقاف الواجهة. متأكد؟', async () => {
    await api.delete('/vlans/' + id);
    toast('تم حذف VLAN', 'success');
    setTimeout(() => location.reload(), 800);
  });
}
