<?php
// Dashboard — pulls live data
$ifaces  = Database::fetchAll("SELECT * FROM interfaces ORDER BY name");
$vlans   = Database::fetchAll("SELECT v.*, i.name iface FROM vlans v JOIN interfaces i ON i.id=v.interface_id ORDER BY v.vlan_id LIMIT 5");
$upCount = count(array_filter($ifaces, fn($i) => $i['status'] === 'up'));
$pppoeSess = (int) Database::fetchOne("SELECT COUNT(*) c FROM pppoe_connections WHERE status='connected'")['c'];
$apiStats  = Database::fetchOne("SELECT COUNT(*) total FROM api_keys WHERE is_active=1");
$logs5     = Database::fetchAll("SELECT * FROM system_logs ORDER BY created_at DESC LIMIT 6");
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between;align-items:center">
    <div><h1>لوحة التحكم</h1><p>النظام يعمل بكفاءة — آخر تحديث: <?= date('H:i:s') ?></p></div>
    <div class="badge badge-green">● نشط</div>
  </div>

  <!-- Metric cards -->
  <div class="grid g4" style="margin-bottom:18px">
    <div class="card">
      <div class="card-title">الخطوط النشطة</div>
      <div class="metric" style="color:var(--green)"><?= $upCount ?></div>
      <div class="metric-sub">من أصل <?= count($ifaces) ?> خط</div>
      <div class="progress"><div class="progress-bar" style="width:<?= count($ifaces)?round($upCount/count($ifaces)*100):0 ?>%;background:var(--green)"></div></div>
    </div>
    <div class="card">
      <div class="card-title">جلسات PPPoE</div>
      <div class="metric" style="color:var(--purple)"><?= $pppoeSess ?></div>
      <div class="metric-sub">جلسة نشطة</div>
    </div>
    <div class="card">
      <div class="card-title">VLANs المُفعّلة</div>
      <div class="metric" style="color:var(--blue)"><?= count($vlans) ?>+</div>
      <div class="metric-sub">شبكة افتراضية</div>
    </div>
    <div class="card">
      <div class="card-title">مفاتيح API</div>
      <div class="metric" style="color:var(--amber)"><?= $apiStats['total'] ?></div>
      <div class="metric-sub">مفتاح نشط</div>
    </div>
  </div>

  <div class="grid g2" style="margin-bottom:18px">
    <!-- Interfaces list -->
    <div class="card">
      <div class="card-header">
        <div class="card-header-title">حالة الخطوط</div>
        <a href="/?page=interfaces" class="btn btn-sm">إدارة</a>
      </div>
      <?php foreach ($ifaces as $iface): ?>
      <div class="conn-row">
        <div class="conn-icon" style="background:var(--<?= $iface['status']==='up'?'green-g':'red-g' ?>)">🔗</div>
        <div class="conn-info">
          <div class="conn-name">
            <span class="mono"><?= htmlspecialchars($iface['name']) ?></span>
            <?php if ($iface['display_name']): ?><span style="color:var(--text3);margin-right:5px"><?= htmlspecialchars($iface['display_name']) ?></span><?php endif; ?>
            <span class="tag tag-<?= $iface['type'] ?>"><?= strtoupper($iface['type']) ?></span>
          </div>
          <div class="conn-detail"><?= $iface['ip_address'] ?: '—' ?></div>
        </div>
        <div class="sparkline" data-color="<?= $iface['status']==='up'?'#22c55e':'#ef4444' ?>"></div>
        <span class="badge badge-<?= $iface['status']==='up'?'green':'red' ?>"><?= $iface['status']==='up'?'نشط':'منقطع' ?></span>
      </div>
      <?php endforeach; ?>
    </div>

    <!-- VLANs summary -->
    <div class="card">
      <div class="card-header">
        <div class="card-header-title">VLANs</div>
        <a href="/?page=vlans" class="btn btn-sm">إدارة</a>
      </div>
      <div class="table-wrap">
        <table class="table">
          <thead><tr><th>ID</th><th>الاسم</th><th>الشبكة</th><th>الحالة</th></tr></thead>
          <tbody>
            <?php foreach ($vlans as $v): ?>
            <tr>
              <td><span class="tag tag-vlan mono"><?= $v['vlan_id'] ?></span></td>
              <td><?= htmlspecialchars($v['name']) ?></td>
              <td class="mono"><?= htmlspecialchars($v['ip_address']) ?>/<?= $v['subnet'] ?></td>
              <td><span class="badge badge-<?= $v['status']==='active'?'green':'amber' ?>"><?= $v['status']==='active'?'نشط':'تحذير' ?></span></td>
            </tr>
            <?php endforeach; ?>
            <?php if(!$vlans): ?><tr><td colspan="4" style="text-align:center;color:var(--text3)">لا توجد VLANs بعد</td></tr><?php endif; ?>
          </tbody>
        </table>
      </div>
    </div>
  </div>

  <!-- Recent logs -->
  <div class="card">
    <div class="card-header">
      <div class="card-header-title">آخر أحداث النظام</div>
      <a href="/?page=logs" class="btn btn-sm">عرض الكل</a>
    </div>
    <div class="log-box">
      <?php foreach ($logs5 as $log): ?>
      <div class="log-line log-<?= $log['level'] ?>">
        <span class="log-time"><?= substr($log['created_at'],11,8) ?></span>
        <span class="log-level">[<?= strtoupper($log['level']) ?>]</span>
        <span class="log-msg"><?= htmlspecialchars($log['message']) ?></span>
      </div>
      <?php endforeach; ?>
      <?php if(!$logs5): ?><div style="color:var(--text3);font-size:11px">لا توجد سجلات بعد</div><?php endif; ?>
    </div>
  </div>
</div>
