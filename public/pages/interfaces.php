<?php
$ifaces = Database::fetchAll("SELECT * FROM interfaces ORDER BY name");
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between">
    <div><h1>الواجهات الشبكية</h1><p><?= count($ifaces) ?> واجهة مسجّلة</p></div>
    <button class="btn btn-primary" onclick="openModal('modal-iface')">+ إضافة واجهة</button>
  </div>
  <div class="iface-grid">
    <?php foreach ($ifaces as $iface):
      $cls = $iface['status']==='up' ? 'is-up' : ($iface['status']==='connecting'?'is-warn':'is-down');
    ?>
    <div class="iface-card <?= $cls ?>">
      <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
        <span class="iface-name"><?= htmlspecialchars($iface['name']) ?></span>
        <span class="badge badge-<?= $iface['status']==='up'?'green':($iface['status']==='connecting'?'amber':'red') ?>">
          <?= ['up'=>'نشط','down'=>'منقطع','connecting'=>'يتصل...','disabled'=>'معطّل'][$iface['status']] ?? $iface['status'] ?>
        </span>
      </div>
      <div class="iface-rows">
        <div class="iface-row"><span class="label">النوع</span><span class="val"><span class="tag tag-<?= $iface['type'] ?>"><?= strtoupper($iface['type']) ?></span></span></div>
        <div class="iface-row"><span class="label">IP</span><span class="val"><?= htmlspecialchars($iface['ip_address'] ?: '—') ?></span></div>
        <div class="iface-row"><span class="label">Gateway</span><span class="val"><?= htmlspecialchars($iface['gateway'] ?: '—') ?></span></div>
        <div class="iface-row"><span class="label">MTU</span><span class="val"><?= $iface['mtu'] ?></span></div>
        <div class="iface-row"><span class="label">الوزن</span><span class="val"><?= $iface['weight'] ?>/10</span></div>
        <?php if ($iface['last_seen']): ?><div class="iface-row"><span class="label">آخر ظهور</span><span class="val"><?= substr($iface['last_seen'],11,8) ?></span></div><?php endif; ?>
      </div>
      <div style="margin-top:10px;display:flex;gap:6px">
        <button class="btn btn-sm" onclick="openEditIface(<?= $iface['id'] ?>)">تعديل</button>
        <?php if ($iface['type']==='dhcp'): ?>
        <button class="btn btn-sm btn-success" onclick="applyDhcp('<?= htmlspecialchars($iface['name']) ?>')">تجديد DHCP</button>
        <?php endif; ?>
        <button class="btn btn-sm btn-danger" onclick="deleteIface(<?= $iface['id'] ?>)">حذف</button>
      </div>
    </div>
    <?php endforeach; ?>
  </div>
</div>

<!-- Add Interface Modal -->
<div class="modal-overlay" id="modal-iface">
  <div class="modal">
    <div class="modal-header"><div class="modal-title">إضافة واجهة شبكية</div><div class="modal-close" onclick="closeModal('modal-iface')">✕</div></div>
    <form id="form-iface" onsubmit="submitIface(event)">
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">اسم الواجهة</label><input class="form-input mono" name="name" placeholder="eth0" required></div>
        <div class="form-group"><label class="form-label">الاسم المعروض</label><input class="form-input" name="display_name" placeholder="WAN-1"></div>
      </div>
      <div class="form-group" style="margin-bottom:12px">
        <label class="form-label">نوع الاتصال</label>
        <select class="form-select" name="type" onchange="ifaceTypeChange(this)" required>
          <option value="pppoe">PPPoE</option><option value="dhcp">DHCP</option><option value="static">Static IP</option>
        </select>
      </div>
      <div id="pppoe-fields">
        <div class="form-row fr2">
          <div class="form-group"><label class="form-label">اسم المستخدم PPPoE</label><input class="form-input mono" name="pppoe_user" placeholder="user@isp.com"></div>
          <div class="form-group"><label class="form-label">كلمة المرور</label><input class="form-input" type="password" name="pppoe_pass"></div>
        </div>
      </div>
      <div id="static-fields" style="display:none">
        <div class="form-row fr2">
          <div class="form-group"><label class="form-label">عنوان IP</label><input class="form-input mono" name="ip_address" placeholder="x.x.x.x"></div>
          <div class="form-group"><label class="form-label">Subnet Mask</label><input class="form-input mono" name="subnet_mask" value="255.255.255.0"></div>
        </div>
        <div class="form-row fr2">
          <div class="form-group"><label class="form-label">Gateway</label><input class="form-input mono" name="gateway" placeholder="x.x.x.1"></div>
          <div class="form-group"><label class="form-label">MTU</label><input class="form-input mono" name="mtu" value="1500"></div>
        </div>
      </div>
      <div id="dhcp-fields" style="display:none"><p style="font-size:11px;color:var(--text3);padding:8px 0">سيتم الحصول على العنوان تلقائياً من DHCP Server.</p></div>
      <div class="form-row fr2" style="margin-top:8px">
        <div class="form-group"><label class="form-label">DNS 1</label><input class="form-input mono" name="dns1" value="8.8.8.8"></div>
        <div class="form-group"><label class="form-label">DNS 2</label><input class="form-input mono" name="dns2" value="8.8.4.4"></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">وزن Load Balancer (1-10)</label><input class="form-input mono" name="weight" type="number" min="1" max="10" value="1"></div>
        <div class="form-group"><label class="form-label">Metric</label><input class="form-input mono" name="metric" value="100"></div>
      </div>
      <div class="modal-footer"><button type="submit" class="btn btn-primary">إضافة</button><button type="button" class="btn" onclick="closeModal('modal-iface')">إلغاء</button></div>
    </form>
  </div>
</div>
<script>
async function submitIface(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  const body = Object.fromEntries(fd);
  body.weight = parseInt(body.weight); body.mtu = parseInt(body.mtu||1500); body.metric = parseInt(body.metric||100);
  const { data, success, message } = await api.post('/interfaces', body);
  if (success) { toast('تمت الإضافة', 'success'); closeModal('modal-iface'); setTimeout(()=>location.reload(),800); }
  else toast(message || 'خطأ', 'error');
}
async function deleteIface(id) {
  confirmDelete('حذف هذه الواجهة؟', async () => {
    await api.delete('/interfaces/'+id);
    toast('تم الحذف', 'success');
    setTimeout(()=>location.reload(),800);
  });
}
async function applyDhcp(name) { toast('جاري تجديد DHCP للواجهة '+name+'...', 'info'); }
function openEditIface(id) { toast('التعديل قيد التطوير', 'warning'); }
</script>
