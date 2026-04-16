<?php
$lbCfg  = Database::fetchOne("SELECT * FROM loadbalancer_config LIMIT 1") ?? [];
$ifaces = Database::fetchAll("SELECT * FROM interfaces WHERE is_enabled=1 ORDER BY weight DESC");
$algos  = [
  'weighted_rr' => 'Weighted Round Robin',
  'least_conn'  => 'Least Connections',
  'hash_src'    => 'Hash-Based (src IP)',
  'bandwidth'   => 'Bandwidth Ratio',
  'failover'    => 'Failover Only',
];
$upIfaces = array_filter($ifaces, fn($i) => $i['status'] === 'up');
$totalWeight = array_sum(array_column(iterator_to_array(new ArrayIterator($upIfaces)), 'weight'));
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between">
    <div><h1>Load Balancer</h1><p><?= count($upIfaces) ?> خط نشط — توزيع الحمل فعّال</p></div>
    <div style="display:flex;gap:8px">
      <button class="btn btn-success" onclick="applyLB()">⚡ تطبيق الآن</button>
      <span class="badge badge-<?= count($upIfaces)?'green':'red' ?>">● <?= count($upIfaces) ?> up</span>
    </div>
  </div>

  <div class="grid g2" style="margin-bottom:18px">
    <!-- Algorithm config -->
    <div class="card">
      <div class="card-title">خوارزمية التوزيع</div>
      <form onsubmit="saveLBConfig(event)">
        <div class="form-group" style="margin-bottom:14px">
          <label class="form-label">الخوارزمية</label>
          <select class="form-select" name="algorithm">
            <?php foreach ($algos as $val => $label): ?>
            <option value="<?= $val ?>" <?= ($lbCfg['algorithm']??'')===$val?'selected':'' ?>><?= $label ?></option>
            <?php endforeach; ?>
          </select>
        </div>
        <div class="form-row fr2">
          <div class="form-group"><label class="form-label">Health Check Host</label><input class="form-input mono" name="health_check_host" value="<?= htmlspecialchars($lbCfg['health_check_host']??'8.8.8.8') ?>"></div>
          <div class="form-group"><label class="form-label">Interval (ثانية)</label><input class="form-input mono" name="health_check_interval" value="<?= $lbCfg['health_check_interval']??30 ?>"></div>
        </div>
        <div class="form-row fr2">
          <div class="form-group"><label class="form-label">Failover Threshold</label><input class="form-input mono" name="failover_threshold" value="<?= $lbCfg['failover_threshold']??3 ?>"></div>
          <div class="form-group"><label class="form-label">Sticky Sessions</label>
            <select class="form-select" name="sticky_sessions"><option value="0" <?= !($lbCfg['sticky_sessions']??0)?'selected':'' ?>>لا</option><option value="1" <?= ($lbCfg['sticky_sessions']??0)?'selected':'' ?>>نعم</option></select></div>
        </div>
        <button type="submit" class="btn btn-primary">حفظ الإعدادات</button>
      </form>
    </div>

    <!-- Weight sliders -->
    <div class="card">
      <div class="card-title">أوزان الخطوط</div>
      <div id="lb-weights">
        <?php foreach ($ifaces as $iface): ?>
        <div class="lb-row">
          <div class="lb-label">
            <span class="mono"><?= htmlspecialchars($iface['name']) ?></span>
            <span class="tag tag-<?= $iface['type'] ?>" style="margin-right:6px"><?= strtoupper($iface['type']) ?></span>
            <?php if ($iface['status']==='up'): ?><span class="badge badge-green" style="font-size:10px">up</span><?php else: ?><span class="badge badge-red" style="font-size:10px">down</span><?php endif; ?>
          </div>
          <div class="lb-controls">
            <span style="font-size:11px;color:var(--text3)">وزن:</span>
            <input type="range" min="1" max="10" value="<?= $iface['weight'] ?>"
              data-iface-id="<?= $iface['id'] ?>"
              oninput="this.nextElementSibling.textContent=this.value; updateLBBars()">
            <span class="lb-weight"><?= $iface['weight'] ?></span>
          </div>
        </div>
        <?php endforeach; ?>
        <?php if (!$ifaces): ?><p style="color:var(--text3);font-size:12px">لا توجد واجهات</p><?php endif; ?>
      </div>
      <div style="margin-top:14px;display:flex;gap:8px">
        <button class="btn btn-primary btn-sm" onclick="saveLBWeights()">حفظ الأوزان</button>
        <button class="btn btn-sm" onclick="equalizeWeights()">توزيع متساوي</button>
      </div>
    </div>
  </div>

  <!-- Current distribution bars -->
  <div class="card">
    <div class="card-title">توزيع الحمل الحالي</div>
    <div id="dist-bars" style="display:flex;flex-direction:column;gap:12px">
      <?php
      foreach ($ifaces as $iface):
        $pct = $totalWeight > 0 ? round($iface['weight'] / $totalWeight * 100) : 0;
        $color = ['pppoe'=>'var(--purple)','dhcp'=>'var(--cyan)','static'=>'var(--amber)'][$iface['type']] ?? 'var(--blue)';
      ?>
      <div data-dist-id="<?= $iface['id'] ?>" data-weight="<?= $iface['weight'] ?>">
        <div style="display:flex;justify-content:space-between;font-size:11px;margin-bottom:4px">
          <span class="mono"><?= htmlspecialchars($iface['name']) ?> — <?= htmlspecialchars($iface['ip_address']?:'—') ?></span>
          <span class="mono" style="color:<?= $color ?>"><?= $pct ?>% (وزن <?= $iface['weight'] ?>)</span>
        </div>
        <div class="progress thick"><div class="progress-bar" style="width:<?= $pct ?>%;background:<?= $color ?>"></div></div>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
</div>
<script>
async function saveLBConfig(e) {
  e.preventDefault();
  const body = Object.fromEntries(new FormData(e.target));
  body.failover_threshold = parseInt(body.failover_threshold);
  body.health_check_interval = parseInt(body.health_check_interval);
  body.sticky_sessions = parseInt(body.sticky_sessions);
  const { success } = await api.put('/loadbalancer/config', body);
  if (success) toast('تم حفظ الإعدادات وتطبيق Load Balancer', 'success');
  else toast('خطأ في الحفظ', 'error');
}
function updateLBBars() {
  const sliders = [...document.querySelectorAll('[data-iface-id]')];
  const total = sliders.reduce((s, el) => s + parseInt(el.value), 0);
  sliders.forEach(el => {
    const id = el.dataset.ifaceId;
    const pct = total > 0 ? Math.round(parseInt(el.value) / total * 100) : 0;
    const row = document.querySelector(`[data-dist-id="${id}"]`);
    if (row) {
      row.querySelector('.progress-bar').style.width = pct + '%';
      row.querySelector('.mono:last-child').textContent = `${pct}% (وزن ${el.value})`;
    }
  });
}
function equalizeWeights() {
  document.querySelectorAll('[data-iface-id]').forEach(el => {
    el.value = 5;
    el.nextElementSibling.textContent = 5;
  });
  updateLBBars();
}
</script>
