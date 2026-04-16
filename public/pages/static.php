<?php
$routes = Database::fetchAll("SELECT r.*, i.name AS iface FROM static_routes r LEFT JOIN interfaces i ON i.id=r.interface_id ORDER BY r.metric");
$ifaces = Database::fetchAll("SELECT id,name,ip_address FROM interfaces ORDER BY name");
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between">
    <div><h1>Static IP &amp; Routes</h1><p><?= count($routes) ?> مسار مُضاف</p></div>
    <button class="btn btn-primary" onclick="openModal('modal-static')">+ إضافة مسار</button>
  </div>

  <!-- Static IP per interface -->
  <div class="card" style="margin-bottom:18px">
    <div class="card-title">ضبط Static IP على الواجهات</div>
    <div class="table-wrap">
      <table class="table">
        <thead><tr><th>الواجهة</th><th>IP الحالي</th><th>Gateway</th><th>DNS</th><th>MTU</th><th>إجراءات</th></tr></thead>
        <tbody>
          <?php foreach ($ifaces as $i): ?>
          <tr>
            <td class="mono"><?= htmlspecialchars($i['name']) ?></td>
            <td class="mono"><?= htmlspecialchars($i['ip_address'] ?: '—') ?></td>
            <td class="mono">—</td><td class="mono">8.8.8.8</td><td>1500</td>
            <td><button class="btn btn-sm" onclick="openStaticEdit(<?= $i['id'] ?>)">تعديل</button></td>
          </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div>
  </div>

  <!-- Static routes table -->
  <div class="card">
    <div class="card-header"><div class="card-header-title">Static Routes</div></div>
    <div class="table-wrap">
      <table class="table">
        <thead><tr><th>Destination</th><th>Prefix</th><th>Gateway</th><th>Interface</th><th>Metric</th><th>الوصف</th><th>الحالة</th><th>إجراءات</th></tr></thead>
        <tbody>
          <?php foreach ($routes as $r): ?>
          <tr>
            <td class="mono"><?= htmlspecialchars($r['destination']) ?></td>
            <td class="mono">/<?= $r['prefix'] ?></td>
            <td class="mono"><?= htmlspecialchars($r['gateway']) ?></td>
            <td class="mono"><?= htmlspecialchars($r['iface'] ?: '—') ?></td>
            <td><?= $r['metric'] ?></td>
            <td style="color:var(--text3)"><?= htmlspecialchars($r['description'] ?: '—') ?></td>
            <td><span class="badge badge-<?= $r['is_active']?'green':'red' ?>"><?= $r['is_active']?'نشط':'معطّل' ?></span></td>
            <td><button class="btn btn-sm btn-danger" onclick="deleteRoute(<?= $r['id'] ?>)">حذف</button></td>
          </tr>
          <?php endforeach; ?>
          <?php if(!$routes): ?><tr><td colspan="8" style="text-align:center;color:var(--text3)">لا توجد مسارات</td></tr><?php endif; ?>
        </tbody>
      </table>
    </div>
  </div>
</div>

<div class="modal-overlay" id="modal-static">
  <div class="modal">
    <div class="modal-header"><div class="modal-title">إضافة Static Route</div><div class="modal-close" onclick="closeModal('modal-static')">✕</div></div>
    <form onsubmit="submitRoute(event)">
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">Destination</label><input class="form-input mono" name="destination" placeholder="0.0.0.0 أو 10.0.0.0" required></div>
        <div class="form-group"><label class="form-label">Prefix Length</label><input class="form-input mono" name="prefix" type="number" min="0" max="32" value="0"></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">Gateway</label><input class="form-input mono" name="gateway" placeholder="x.x.x.1" required></div>
        <div class="form-group"><label class="form-label">الواجهة (اختياري)</label>
          <select class="form-select" name="interface_id"><option value="">تلقائي</option><?php foreach($ifaces as $i): ?><option value="<?= $i['id'] ?>"><?= htmlspecialchars($i['name']) ?></option><?php endforeach; ?></select></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">Metric</label><input class="form-input mono" name="metric" value="100"></div>
        <div class="form-group"><label class="form-label">الوصف</label><input class="form-input" name="description" placeholder="Default route WAN-1"></div>
      </div>
      <div class="modal-footer"><button type="submit" class="btn btn-primary">إضافة وتطبيق</button><button type="button" class="btn" onclick="closeModal('modal-static')">إلغاء</button></div>
    </form>
  </div>
</div>

<!-- Edit Static IP Modal -->
<div class="modal-overlay" id="modal-static-edit">
  <div class="modal">
    <div class="modal-header"><div class="modal-title">تعديل Static IP</div><div class="modal-close" onclick="closeModal('modal-static-edit')">✕</div></div>
    <form onsubmit="submitStaticIp(event)">
      <input type="hidden" name="id" id="edit-iface-id">
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">عنوان IP</label><input class="form-input mono" name="ip_address" id="edit-ip" required></div>
        <div class="form-group"><label class="form-label">Subnet Mask</label><input class="form-input mono" name="subnet_mask" id="edit-mask" value="255.255.255.0"></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">Gateway</label><input class="form-input mono" name="gateway" id="edit-gw"></div>
        <div class="form-group"><label class="form-label">MTU</label><input class="form-input mono" name="mtu" id="edit-mtu" value="1500"></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">DNS 1</label><input class="form-input mono" name="dns1" value="8.8.8.8"></div>
        <div class="form-group"><label class="form-label">DNS 2</label><input class="form-input mono" name="dns2" value="8.8.4.4"></div>
      </div>
      <div class="modal-footer"><button type="submit" class="btn btn-primary">تطبيق</button><button type="button" class="btn" onclick="closeModal('modal-static-edit')">إلغاء</button></div>
    </form>
  </div>
</div>
<script>
async function submitRoute(e) {
  e.preventDefault();
  const body = Object.fromEntries(new FormData(e.target));
  body.prefix = parseInt(body.prefix); body.metric = parseInt(body.metric||100);
  if (!body.interface_id) delete body.interface_id;
  const { success, message } = await api.post('/routes', body);
  if (success) { toast('تم إضافة المسار وتطبيقه', 'success'); closeModal('modal-static'); setTimeout(()=>location.reload(),800); }
  else toast(message||'خطأ في تطبيق المسار','error');
}
function openStaticEdit(id) {
  document.getElementById('edit-iface-id').value = id;
  openModal('modal-static-edit');
}
async function submitStaticIp(e) {
  e.preventDefault();
  const body = Object.fromEntries(new FormData(e.target));
  const id = body.id; delete body.id;
  body.type = 'static'; body.mtu = parseInt(body.mtu);
  const { success } = await api.put('/interfaces/'+id, body);
  if (success) { toast('تم تطبيق Static IP', 'success'); closeModal('modal-static-edit'); setTimeout(()=>location.reload(),800); }
  else toast('خطأ في التطبيق','error');
}
</script>
