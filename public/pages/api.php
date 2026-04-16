<?php
$apiKeys = Database::fetchAll("SELECT id,name,key_prefix,permissions,rate_limit,is_active,last_used,requests_count,created_at FROM api_keys ORDER BY created_at DESC");
$endpoints = [
  ['GET',    '/status',                 'حالة النظام العامة'],
  ['GET',    '/interfaces',             'قائمة جميع الواجهات'],
  ['POST',   '/interfaces',             'إضافة واجهة جديدة'],
  ['PUT',    '/interfaces/{id}',        'تحديث واجهة'],
  ['DELETE', '/interfaces/{id}',        'حذف واجهة'],
  ['GET',    '/vlans',                  'قائمة VLANs'],
  ['POST',   '/vlans',                  'إنشاء VLAN'],
  ['DELETE', '/vlans/{id}',             'حذف VLAN'],
  ['GET',    '/pppoe',                  'قائمة اتصالات PPPoE'],
  ['POST',   '/pppoe',                  'إضافة اتصال PPPoE'],
  ['POST',   '/pppoe/{id}/connect',     'بدء اتصال PPPoE'],
  ['POST',   '/pppoe/{id}/disconnect',  'قطع اتصال PPPoE'],
  ['DELETE', '/pppoe/{id}',             'حذف اتصال PPPoE'],
  ['GET',    '/dhcp',                   'قائمة DHCP Pools'],
  ['POST',   '/dhcp',                   'إنشاء DHCP Pool'],
  ['GET',    '/dhcp/leases',            'قائمة DHCP Leases'],
  ['GET',    '/routes',                 'جدول التوجيه'],
  ['POST',   '/routes',                 'إضافة مسار'],
  ['DELETE', '/routes/{id}',            'حذف مسار'],
  ['GET',    '/loadbalancer',           'إعدادات Load Balancer'],
  ['PUT',    '/loadbalancer/config',    'تحديث إعدادات LB'],
  ['PUT',    '/loadbalancer/weights',   'تحديث أوزان الخطوط'],
  ['POST',   '/loadbalancer/apply',     'تطبيق Load Balancer فوراً'],
  ['GET',    '/stats/summary',          'ملخص إحصائيات النظام'],
  ['GET',    '/stats/realtime',         'إحصائيات الواجهات لحظياً'],
  ['GET',    '/stats/traffic',          'بيانات الترافيك (مع فلاتر)'],
  ['GET',    '/logs',                   'سجلات النظام'],
  ['GET',    '/api-keys',               'قائمة مفاتيح API'],
  ['POST',   '/api-keys',               'إنشاء مفتاح API'],
  ['PUT',    '/api-keys/{id}',          'تفعيل/تعطيل مفتاح'],
  ['DELETE', '/api-keys/{id}',          'إلغاء مفتاح'],
  ['GET',    '/settings',               'قراءة الإعدادات'],
  ['PUT',    '/settings',               'تحديث الإعدادات'],
];
$methodColors = ['GET'=>'badge-green','POST'=>'badge-blue','PUT'=>'badge-amber','DELETE'=>'badge-red'];
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between">
    <div><h1>API Manager</h1><p>REST API v1 | Base URL: <span class="mono" style="color:var(--blue)">/api/v1</span></p></div>
    <button class="btn btn-primary" onclick="openModal('modal-api')">+ مفتاح جديد</button>
  </div>

  <div class="grid g2" style="margin-bottom:18px">
    <!-- API Keys -->
    <div class="card">
      <div class="card-title">مفاتيح API</div>
      <div class="table-wrap">
        <table class="table">
          <thead><tr><th>الاسم</th><th>المفتاح</th><th>الصلاحيات</th><th>الطلبات</th><th>آخر استخدام</th><th>فعّال</th><th></th></tr></thead>
          <tbody>
            <?php foreach ($apiKeys as $k): ?>
            <tr>
              <td><?= htmlspecialchars($k['name']) ?></td>
              <td class="mono" style="color:var(--text3)"><?= htmlspecialchars($k['key_prefix']) ?>***</td>
              <td style="font-size:10px;color:var(--cyan)"><?= htmlspecialchars($k['permissions']) ?></td>
              <td class="mono"><?= number_format($k['requests_count']) ?></td>
              <td style="color:var(--text3);font-size:11px"><?= $k['last_used'] ? substr($k['last_used'],0,16) : '—' ?></td>
              <td>
                <label class="toggle">
                  <input type="checkbox" <?= $k['is_active']?'checked':'' ?> onchange="toggleKey(<?= $k['id'] ?>, this.checked)">
                  <span class="toggle-slider"></span>
                </label>
              </td>
              <td><button class="btn btn-sm btn-danger" onclick="revokeKey(<?= $k['id'] ?>)">إلغاء</button></td>
            </tr>
            <?php endforeach; ?>
            <?php if(!$apiKeys): ?><tr><td colspan="7" style="text-align:center;color:var(--text3)">لا توجد مفاتيح</td></tr><?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>

    <!-- Auth info -->
    <div class="card">
      <div class="card-title">المصادقة</div>
      <div style="display:flex;flex-direction:column;gap:10px">
        <div class="endpoint">
          <div class="endpoint-top"><span class="tag tag-get">Header</span><span class="endpoint-path">X-API-Key: lbpro_xxxx</span></div>
          <div class="endpoint-desc">إرسال المفتاح في الهيدر مع كل طلب</div>
        </div>
        <div class="endpoint">
          <div class="endpoint-top"><span class="tag tag-get">Bearer</span><span class="endpoint-path">Authorization: Bearer lbpro_xxxx</span></div>
          <div class="endpoint-desc">أو استخدام Bearer token</div>
        </div>
        <div class="divider"></div>
        <div style="font-size:11px;color:var(--text3);line-height:1.9">
          <div>• Rate Limit: <span style="color:var(--amber)">100 طلب/دقيقة</span> لكل مفتاح</div>
          <div>• استجابة JSON دائماً مع <span style="color:var(--green)">success: true/false</span></div>
          <div>• HTTP Codes: 200, 201, 400, 401, 403, 404, 429, 500</div>
          <div>• CORS مفعّل لجميع الأصول</div>
        </div>
      </div>
    </div>
  </div>

  <!-- Endpoints reference -->
  <div class="card">
    <div class="card-title">نقاط النهاية — <?= count($endpoints) ?> endpoint</div>
    <div style="columns:2;column-gap:16px">
      <?php foreach ($endpoints as $ep): ?>
      <div class="endpoint" style="break-inside:avoid;margin-bottom:6px">
        <div class="endpoint-top">
          <span class="badge <?= $methodColors[$ep[0]] ?? 'badge-blue' ?>" style="font-size:10px;padding:2px 7px"><?= $ep[0] ?></span>
          <span class="endpoint-path"><?= htmlspecialchars($ep[1]) ?></span>
        </div>
        <div class="endpoint-desc"><?= htmlspecialchars($ep[2]) ?></div>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</div>

<!-- Add API Key Modal -->
<div class="modal-overlay" id="modal-api">
  <div class="modal">
    <div class="modal-header"><div class="modal-title">إنشاء مفتاح API</div><div class="modal-close" onclick="closeModal('modal-api')">✕</div></div>
    <form id="form-api" onsubmit="submitApiKey(event)">
      <div class="form-group" style="margin-bottom:14px">
        <label class="form-label">اسم المفتاح</label>
        <input class="form-input" name="key_name" placeholder="monitoring-system" required>
      </div>
      <div class="form-group" style="margin-bottom:14px">
        <label class="form-label">نطاقات الصلاحية</label>
        <div style="display:flex;flex-wrap:wrap;gap:10px;margin-top:6px">
          <?php foreach (['interfaces','vlans','pppoe','dhcp','routes','loadbalancer','stats','admin'] as $perm): ?>
          <label style="display:flex;align-items:center;gap:5px;font-size:12px;cursor:pointer">
            <input type="checkbox" name="perm" value="<?= $perm ?>" <?= in_array($perm,['interfaces','stats'])?'checked':'' ?>>
            <?= $perm ?>
          </label>
          <?php endforeach; ?>
        </div>
      </div>
      <div id="api-key-result" style="display:none;background:var(--bg3);border:1px solid var(--green);border-radius:var(--r);padding:12px;margin-bottom:12px">
        <div style="font-size:11px;color:var(--text3);margin-bottom:6px">⚠ احفظ المفتاح الآن — لن يظهر مجدداً</div>
        <div class="mono" id="generated-key" style="color:var(--green);font-size:12px;word-break:break-all"></div>
      </div>
      <div class="modal-footer">
        <button type="submit" class="btn btn-primary">إنشاء</button>
        <button type="button" class="btn" onclick="closeModal('modal-api')">إغلاق</button>
      </div>
    </form>
  </div>
</div>
<script>
async function submitApiKey(e) {
  e.preventDefault();
  const form = e.target;
  const name  = form.querySelector('[name=key_name]').value;
  const perms = [...form.querySelectorAll('[name=perm]:checked')].map(c => c.value);
  const { data, success } = await api.post('/api-keys', { name, permissions: perms });
  if (success && data?.key) {
    document.getElementById('generated-key').textContent = data.key;
    document.getElementById('api-key-result').style.display = '';
    toast('تم إنشاء المفتاح — احفظه الآن!', 'success');
  } else toast('خطأ في الإنشاء', 'error');
}
async function toggleKey(id, active) {
  await api.put('/api-keys/'+id, { is_active: active ? 1 : 0 });
  toast(active ? 'تم تفعيل المفتاح' : 'تم تعطيل المفتاح', 'info');
}
async function revokeKey(id) {
  confirmDelete('إلغاء هذا المفتاح نهائياً؟', async () => {
    await api.delete('/api-keys/'+id);
    toast('تم الإلغاء', 'success');
    setTimeout(() => location.reload(), 800);
  });
}
</script>
