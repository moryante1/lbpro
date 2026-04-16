<?php
$level    = $_GET['level'] ?? '';
$category = $_GET['cat']   ?? '';
$limit    = (int)($_GET['limit'] ?? 100);
$sql      = "SELECT * FROM system_logs WHERE 1=1";
$params   = [];
if ($level)    { $sql .= " AND level=?";    $params[] = $level; }
if ($category) { $sql .= " AND category=?"; $params[] = $category; }
$sql .= " ORDER BY created_at DESC LIMIT ?";
$params[] = $limit;
$logs = Database::fetchAll($sql, $params);
$cats = Database::fetchAll("SELECT DISTINCT category FROM system_logs ORDER BY category");
$levelColors = ['info'=>'cyan','warning'=>'amber','error'=>'red','critical'=>'red'];
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between">
    <div><h1>سجل النظام</h1><p><?= count($logs) ?> سجل</p></div>
    <div class="btn-group">
      <form method="GET" style="display:flex;gap:8px;align-items:center">
        <input type="hidden" name="page" value="logs">
        <select class="form-select" name="level" style="padding:6px 10px;font-size:12px">
          <option value="">كل المستويات</option>
          <?php foreach(['info','warning','error','critical'] as $l): ?>
          <option value="<?= $l ?>" <?= $level===$l?'selected':'' ?>><?= strtoupper($l) ?></option>
          <?php endforeach; ?>
        </select>
        <select class="form-select" name="cat" style="padding:6px 10px;font-size:12px">
          <option value="">كل الفئات</option>
          <?php foreach($cats as $c): ?>
          <option value="<?= htmlspecialchars($c['category']) ?>" <?= $category===$c['category']?'selected':'' ?>><?= htmlspecialchars($c['category']) ?></option>
          <?php endforeach; ?>
        </select>
        <select class="form-select" name="limit" style="padding:6px 10px;font-size:12px">
          <?php foreach([50,100,250,500] as $lim): ?>
          <option value="<?= $lim ?>" <?= $limit===$lim?'selected':'' ?>><?= $lim ?> سجل</option>
          <?php endforeach; ?>
        </select>
        <button type="submit" class="btn btn-sm">فلترة</button>
        <a href="/?page=logs" class="btn btn-sm">مسح</a>
      </form>
    </div>
  </div>

  <div class="card">
    <div class="log-box" style="max-height:600px">
      <?php foreach ($logs as $log): $clr = $levelColors[$log['level']] ?? 'text2'; ?>
      <div class="log-line log-<?= $log['level'] ?>">
        <span class="log-time"><?= substr($log['created_at'],0,19) ?></span>
        <span class="log-level" style="color:var(--<?= $clr ?>)">[<?= strtoupper($log['level']) ?>]</span>
        <span style="color:var(--blue);min-width:80px">[<?= htmlspecialchars($log['category']) ?>]</span>
        <span class="log-msg"><?= htmlspecialchars($log['message']) ?></span>
        <?php if ($log['ip_address']): ?><span style="color:var(--text3);margin-right:auto;font-size:10px"><?= htmlspecialchars($log['ip_address']) ?></span><?php endif; ?>
      </div>
      <?php endforeach; ?>
      <?php if (!$logs): ?><div style="color:var(--text3);text-align:center;padding:20px">لا توجد سجلات تطابق الفلتر</div><?php endif; ?>
    </div>
  </div>
</div>
