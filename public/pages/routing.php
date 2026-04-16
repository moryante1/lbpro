<?php
$routes = Database::fetchAll("SELECT r.*, i.name AS iface FROM static_routes r LEFT JOIN interfaces i ON i.id=r.interface_id ORDER BY r.metric");
// Also get kernel routing table
$kernelRoutes = [];
$out = shell_exec('ip route show 2>/dev/null') ?: '';
foreach (explode("\n", trim($out)) as $line) {
    if (trim($line)) $kernelRoutes[] = $line;
}
?>
<div class="page-wrap">
  <div class="page-header"><h1>Routing Table</h1><p>جدول التوجيه — Kernel + Static</p></div>

  <!-- Kernel routes -->
  <div class="card" style="margin-bottom:18px">
    <div class="card-header">
      <div class="card-header-title">جدول الكرنل (ip route show)</div>
      <button class="btn btn-sm" onclick="refreshRoutes()">تحديث</button>
    </div>
    <div class="log-box" id="kernel-routes" style="max-height:200px">
      <?php if ($kernelRoutes): ?>
        <?php foreach ($kernelRoutes as $line): ?>
        <div style="padding:2px 0;border-bottom:1px solid var(--border)"><?= htmlspecialchars($line) ?></div>
        <?php endforeach; ?>
      <?php else: ?>
        <span style="color:var(--text3)">لا يمكن قراءة جدول التوجيه (يحتاج صلاحيات)</span>
      <?php endif; ?>
    </div>
  </div>

  <!-- Database routes -->
  <div class="card">
    <div class="card-header">
      <div class="card-header-title">المسارات المُدارة</div>
      <a href="/?page=static" class="btn btn-sm btn-primary">+ مسار جديد</a>
    </div>
    <div class="table-wrap">
      <table class="table">
        <thead><tr><th>Destination</th><th>Prefix</th><th>Gateway</th><th>Interface</th><th>Protocol</th><th>Metric</th><th>الحالة</th><th>إجراءات</th></tr></thead>
        <tbody>
          <?php foreach ($routes as $r): ?>
          <tr>
            <td class="mono"><?= htmlspecialchars($r['destination']) ?></td>
            <td class="mono">/<?= $r['prefix'] ?></td>
            <td class="mono"><?= htmlspecialchars($r['gateway']) ?></td>
            <td class="mono"><?= htmlspecialchars($r['iface'] ?: '—') ?></td>
            <td><span class="tag tag-static">Static</span></td>
            <td><?= $r['metric'] ?></td>
            <td><span class="badge badge-<?= $r['is_active']?'green':'red' ?>"><?= $r['is_active']?'نشط':'معطّل' ?></span></td>
            <td><button class="btn btn-sm btn-danger" onclick="deleteRoute(<?= $r['id'] ?>)">حذف</button></td>
          </tr>
          <?php endforeach; ?>
          <?php if(!$routes): ?><tr><td colspan="8" style="text-align:center;color:var(--text3)">لا توجد مسارات مُدارة</td></tr><?php endif; ?>
        </tbody>
      </table>
    </div>
  </div>
</div>
<script>
async function refreshRoutes() {
  const { data } = await api.get('/routes');
  toast('تم التحديث', 'info');
  setTimeout(() => location.reload(), 500);
}
</script>
