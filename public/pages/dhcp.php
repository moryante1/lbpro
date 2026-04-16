<?php /* pages/dhcp.php */
$pools  = Database::fetchAll("SELECT p.*, i.name AS iface_name FROM dhcp_pools p JOIN interfaces i ON i.id=p.interface_id");
$leases = Database::fetchAll("SELECT * FROM dhcp_leases ORDER BY last_seen DESC LIMIT 50");
$ifaces = Database::fetchAll("SELECT id,name FROM interfaces");
$vlans  = Database::fetchAll("SELECT id, CONCAT('VLAN',vlan_id,' - ',name) AS label FROM vlans");
$leasesActive = count(array_filter($leases, fn($l)=>strtotime($l['lease_end']??'') > time()));
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between">
    <div><h1>DHCP Server</h1></div>
    <button class="btn btn-primary" onclick="openModal('modal-dhcp')">+ Pool جديد</button>
  </div>
  <div class="grid g3" style="margin-bottom:18px">
    <div class="stat-box"><div class="stat-val" style="color:var(--cyan)"><?= count($leases) ?></div><div class="stat-lbl">إجمالي Leases</div></div>
    <div class="stat-box"><div class="stat-val" style="color:var(--green)"><?= $leasesActive ?></div><div class="stat-lbl">Leases نشطة</div></div>
    <div class="stat-box"><div class="stat-val" style="color:var(--amber)"><?= count(array_filter($leases, fn($l)=>$l['is_reserved'])) ?></div><div class="stat-lbl">Reservations</div></div>
  </div>
  <div class="grid g2">
    <div class="card">
      <div class="card-header"><div class="card-header-title">Pools</div></div>
      <?php foreach($pools as $p): ?>
      <div class="conn-row">
        <div class="conn-icon" style="background:var(--cyan-g)">📡</div>
        <div class="conn-info">
          <div class="conn-name"><?= htmlspecialchars($p['name']) ?> <span style="color:var(--text3);font-size:10px"><?= htmlspecialchars($p['iface_name']) ?></span></div>
          <div class="conn-detail"><?= htmlspecialchars($p['range_start']) ?> → <?= htmlspecialchars($p['range_end']) ?></div>
        </div>
        <button class="btn btn-sm btn-danger" onclick="deletePool(<?= $p['id'] ?>)">حذف</button>
      </div>
      <?php endforeach; ?>
      <?php if(!$pools): ?><p style="color:var(--text3);font-size:12px;text-align:center">لا توجد pools</p><?php endif; ?>
    </div>
    <div class="card">
      <div class="card-header"><div class="card-header-title">آخر Leases</div></div>
      <div class="table-wrap">
        <table class="table">
          <thead><tr><th>MAC</th><th>IP</th><th>Hostname</th><th>النوع</th></tr></thead>
          <tbody>
            <?php foreach(array_slice($leases,0,8) as $l): ?>
            <tr>
              <td class="mono"><?= htmlspecialchars($l['mac_address']) ?></td>
              <td class="mono"><?= htmlspecialchars($l['ip_address']) ?></td>
              <td><?= htmlspecialchars($l['hostname'] ?: '—') ?></td>
              <td><?php if($l['is_reserved']): ?><span class="badge badge-amber">ثابت</span><?php else: ?><span class="badge badge-blue">ديناميكي</span><?php endif; ?></td>
            </tr>
            <?php endforeach; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</div>
<div class="modal-overlay" id="modal-dhcp">
  <div class="modal">
    <div class="modal-header"><div class="modal-title">DHCP Pool جديد</div><div class="modal-close" onclick="closeModal('modal-dhcp')">✕</div></div>
    <form onsubmit="submitDhcp(event)">
      <div class="form-row fr2">
        <div class="form-group"><label class="form-label">اسم Pool</label><input class="form-input" name="name" required placeholder="vlan20-clients"></div>
        <div class="form-group"><label class="form-label">الواجهة</label>
          <select class="form-select" name="interface_id" required><option value="">اختر...</option><?php foreach($ifaces as $i): ?><option value="<?= $i['id'] ?>"><?= htmlspecialchars($i['name']) ?></option><?php endforeach; ?></select></div>
      </div>
      <div class="form-row fr3">
        <div class="form-group"><label class="form-label">الشبكة</label><input class="form-input mono" name="subnet" placeholder="10.0.20.0" required></div>
        <div class="form-group"><label class="form-label">بداية</label><input class="form-input mono" name="range_start" placeholder="10.0.20.100" required></div>
        <div class="form-group"><label class="form-label">نهاية</label><input class="form-input mono" name="range_end" placeholder="10.0.20.200" required></div>
      </div>
      <div class="form-row fr3">
        <div class="form-group"><label class="form-label">Gateway</label><input class="form-input mono" name="gateway" placeholder="10.0.20.1" required></div>
        <div class="form-group"><label class="form-label">DNS 1</label><input class="form-input mono" name="dns1" value="8.8.8.8"></div>
        <div class="form-group"><label class="form-label">DNS 2</label><input class="form-input mono" name="dns2" value="8.8.4.4"></div>
      </div>
      <div class="form-group" style="margin-bottom:12px"><label class="form-label">Lease Time (ثانية)</label><input class="form-input mono" name="lease_time" value="86400"></div>
      <div class="modal-footer"><button type="submit" class="btn btn-primary">إنشاء</button><button type="button" class="btn" onclick="closeModal('modal-dhcp')">إلغاء</button></div>
    </form>
  </div>
</div>
<script>
async function submitDhcp(e) {
  e.preventDefault();
  const body = Object.fromEntries(new FormData(e.target));
  body.interface_id = parseInt(body.interface_id); body.lease_time = parseInt(body.lease_time);
  const { success, message } = await api.post('/dhcp', body);
  if (success) { toast('تم إنشاء Pool وإعادة تشغيل DHCP', 'success'); closeModal('modal-dhcp'); setTimeout(()=>location.reload(),800); }
  else toast(message||'خطأ','error');
}
async function deletePool(id) { confirmDelete('حذف هذا Pool؟', async ()=>{ await api.delete('/dhcp/'+id); toast('تم الحذف','success'); setTimeout(()=>location.reload(),800); }); }
</script>
