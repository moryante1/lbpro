<?php /* pages/vlans.php */
$vlans  = Database::fetchAll("SELECT v.*, i.name AS iface_name FROM vlans v JOIN interfaces i ON i.id=v.interface_id ORDER BY v.vlan_id");
$ifaces = Database::fetchAll("SELECT id, name FROM interfaces ORDER BY name");
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between">
    <div><h1>إدارة VLANs</h1><p><?= count($vlans) ?> شبكة افتراضية</p></div>
    <button class="btn btn-primary" onclick="openModal('modal-vlan')">+ إضافة VLAN</button>
  </div>
  <div class="card">
    <div class="table-wrap">
      <table class="table">
        <thead><tr><th>VLAN ID</th><th>الاسم</th><th>الواجهة</th><th>الشبكة</th><th>Gateway</th><th>النوع</th><th>الحالة</th><th>إجراءات</th></tr></thead>
        <tbody>
          <?php foreach ($vlans as $v): ?>
          <tr>
            <td><span class="tag tag-vlan mono">VLAN<?= $v['vlan_id'] ?></span></td>
            <td><?= htmlspecialchars($v['name']) ?></td>
            <td class="mono"><?= htmlspecialchars($v['vlan_interface'] ?: $v['iface_name'].'.'.$v['vlan_id']) ?></td>
            <td class="mono"><?= htmlspecialchars($v['ip_address']) ?>/<?= $v['subnet'] ?></td>
            <td class="mono"><?= htmlspecialchars($v['gateway'] ?: '—') ?></td>
            <td><span class="tag tag-<?= $v['vlan_type']==='tagged'?'vlan':'static' ?>"><?= $v['vlan_type'] ?></span></td>
            <td><span class="badge badge-<?= $v['status']==='active'?'green':'amber' ?>"><?= $v['status']==='active'?'نشط':'غير نشط' ?></span></td>
            <td>
              <button class="btn btn-sm" onclick="editVlan(<?= $v['id'] ?>)">تعديل</button>
              <button class="btn btn-sm btn-danger" onclick="deleteVlan(<?= $v['id'] ?>)">حذف</button>
            </td>
          </tr>
          <?php endforeach; ?>
          <?php if(!$vlans): ?><tr><td colspan="8" style="text-align:center;color:var(--text3)">لا توجد VLANs. أضف أول VLAN.</td></tr><?php endif; ?>
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Add VLAN Modal -->
<div class="modal-overlay" id="modal-vlan">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title">إضافة VLAN جديد</div>
      <div class="modal-close" onclick="closeModal('modal-vlan')">✕</div>
    </div>
    <form id="form-vlan" onsubmit="submitVlan(event)">
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">VLAN ID (1-4094)</label><input class="form-input mono" name="vlan_id" type="number" min="1" max="4094" required></div>
        <div class="form-group"><label class="form-label">الاسم</label><input class="form-input" name="name" required placeholder="مثال: Clients"></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">الواجهة</label>
          <select class="form-select" name="interface_id" required>
            <option value="">اختر واجهة</option>
            <?php foreach ($ifaces as $i): ?><option value="<?= $i['id'] ?>"><?= htmlspecialchars($i['name']) ?></option><?php endforeach; ?>
          </select></div>
        <div class="form-group"><label class="form-label">نوع VLAN</label>
          <select class="form-select" name="vlan_type"><option value="tagged">Tagged (Trunk)</option><option value="untagged">Untagged (Access)</option></select></div>
      </div>
      <div class="form-row fr3">
        <div class="form-group"><label class="form-label">عنوان Gateway IP</label><input class="form-input mono" name="ip_address" placeholder="10.0.x.1" required></div>
        <div class="form-group"><label class="form-label">Prefix (/)</label><input class="form-input mono" name="subnet" type="number" min="8" max="30" value="24"></div>
        <div class="form-group"><label class="form-label">Gateway</label><input class="form-input mono" name="gateway" placeholder="اختياري"></div>
      </div>
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">DNS Primary</label><input class="form-input mono" name="dns1" value="8.8.8.8"></div>
        <div class="form-group"><label class="form-label">DNS Secondary</label><input class="form-input mono" name="dns2" value="8.8.4.4"></div>
      </div>
      <div class="form-group" style="margin-bottom:12px"><label class="form-label">وصف (اختياري)</label><input class="form-input" name="description" placeholder="وصف مختصر"></div>
      <div class="modal-footer"><button type="submit" class="btn btn-primary">إنشاء VLAN</button><button type="button" class="btn" onclick="closeModal('modal-vlan')">إلغاء</button></div>
    </form>
  </div>
</div>
<script>
async function submitVlan(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  const body = Object.fromEntries(fd);
  body.vlan_id = parseInt(body.vlan_id); body.subnet = parseInt(body.subnet);
  const { data, success, message } = await api.post('/vlans', body);
  if (success) { toast('تم إنشاء VLAN بنجاح', 'success'); closeModal('modal-vlan'); setTimeout(()=>location.reload(),800); }
  else toast(message || 'خطأ', 'error');
}
function editVlan(id) { toast('صفحة التعديل قيد التطوير', 'warning'); }
</script>
