<?php
$settings = [];
foreach (Database::fetchAll("SELECT `key`,`value` FROM settings") as $s) {
    $settings[$s['key']] = $s['value'];
}
function s(string $k, string $default = ''): string {
    global $settings;
    return htmlspecialchars($settings[$k] ?? $default);
}
// System info
$phpV   = PHP_VERSION;
$nginxV = trim(shell_exec('nginx -v 2>&1 | head -1') ?: '—');
$mysqlV = trim(shell_exec('mysql --version 2>/dev/null | head -1') ?: '—');
$uptime = trim(shell_exec('uptime -p 2>/dev/null') ?: '—');
$kernel = trim(shell_exec('uname -r 2>/dev/null') ?: '—');
$cpu    = trim(shell_exec("grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2") ?: '—');
$mem    = trim(shell_exec("free -h | awk '/^Mem:/{print $2\" total / \"$3\" used\"}'") ?: '—');
$disk   = trim(shell_exec("df -h / | awk 'NR==2{print $3\"/\"$2\" (\"$5\")\"}'") ?: '—');
?>
<div class="page-wrap">
  <div class="page-header"><h1>الإعدادات</h1></div>
  <div class="grid g2">

    <!-- General settings -->
    <div class="card">
      <div class="card-title">إعدادات عامة</div>
      <form onsubmit="saveSettings(event)">
        <div class="form-row fr2">
          <div class="form-group"><label class="form-label">Hostname</label><input class="form-input mono" name="hostname" value="<?= s('hostname','lb-pro-01') ?>"></div>
          <div class="form-group"><label class="form-label">المنطقة الزمنية</label>
            <select class="form-select" name="timezone">
              <?php foreach(['Asia/Riyadh','Asia/Baghdad','Africa/Cairo','UTC','Europe/London'] as $tz): ?>
              <option value="<?= $tz ?>" <?= s('timezone')===$tz?'selected':'' ?>><?= $tz ?></option>
              <?php endforeach; ?>
            </select></div>
        </div>
        <div class="form-row fr2">
          <div class="form-group"><label class="form-label">NTP Server</label><input class="form-input mono" name="ntp_server" value="<?= s('ntp_server','pool.ntp.org') ?>"></div>
          <div class="form-group"><label class="form-label">Health Check Interval (s)</label><input class="form-input mono" name="ping_interval" value="<?= s('ping_interval','30') ?>"></div>
        </div>
        <div class="form-group" style="margin-bottom:12px"><label class="form-label">بريد التنبيهات</label><input class="form-input" name="alert_email" type="email" value="<?= s('alert_email') ?>" placeholder="admin@example.com"></div>
        <div class="divider"></div>
        <div style="display:flex;flex-direction:column;gap:10px;margin-bottom:14px">
          <div style="display:flex;justify-content:space-between;align-items:center">
            <span>Failover تلقائي</span>
            <label class="toggle"><input type="checkbox" name="failover_auto" <?= s('failover_auto')!=='0'?'checked':'' ?> value="1"><span class="toggle-slider"></span></label>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:center">
            <span>IPv6 دعم</span>
            <label class="toggle"><input type="checkbox" name="ipv6_enabled" <?= s('ipv6_enabled')==='1'?'checked':'' ?> value="1"><span class="toggle-slider"></span></label>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:center">
            <span>SNMP مفعّل</span>
            <label class="toggle"><input type="checkbox" name="snmp_enabled" <?= s('snmp_enabled')!=='0'?'checked':'' ?> value="1"><span class="toggle-slider"></span></label>
          </div>
          <div style="display:flex;justify-content:space-between;align-items:center">
            <span>تحديث تلقائي للإعدادات</span>
            <label class="toggle"><input type="checkbox" name="auto_update" <?= s('auto_update')!=='0'?'checked':'' ?> value="1"><span class="toggle-slider"></span></label>
          </div>
        </div>
        <button type="submit" class="btn btn-primary">حفظ الإعدادات</button>
      </form>
    </div>

    <!-- System info -->
    <div class="card">
      <div class="card-title">معلومات النظام</div>
      <div style="display:flex;flex-direction:column;gap:7px;font-size:12px">
        <?php foreach ([
          'نظام التشغيل'  => 'Ubuntu 22.04 LTS',
          'الكرنل'         => $kernel,
          'المعالج'         => $cpu,
          'الذاكرة'         => $mem,
          'القرص'          => $disk,
          'وقت التشغيل'   => $uptime,
          'PHP'            => $phpV,
          'Nginx'          => $nginxV,
          'MySQL'          => $mysqlV,
          'إصدار النظام'   => 'LoadBalancer Pro v2.4.1',
        ] as $label => $val): ?>
        <div style="display:flex;justify-content:space-between;padding:6px 0;border-bottom:1px solid var(--border)">
          <span style="color:var(--text3)"><?= $label ?></span>
          <span class="mono" style="color:var(--text2);max-width:240px;text-align:left;overflow:hidden;text-overflow:ellipsis;white-space:nowrap"><?= htmlspecialchars($val) ?></span>
        </div>
        <?php endforeach; ?>
      </div>

      <div class="divider"></div>
      <div class="card-title">تغيير كلمة المرور</div>
      <form onsubmit="changePassword(event)">
        <div class="form-row">
          <div class="form-group"><label class="form-label">كلمة المرور الحالية</label><input class="form-input" type="password" name="current_pass" required></div>
          <div class="form-group"><label class="form-label">كلمة المرور الجديدة</label><input class="form-input" type="password" name="new_pass" minlength="8" required></div>
        </div>
        <button type="submit" class="btn btn-primary btn-sm">تغيير</button>
      </form>
    </div>
  </div>
</div>
<script>
async function saveSettings(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  const body = {};
  for (const [k, v] of fd.entries()) body[k] = v;
  // Handle unchecked checkboxes
  ['failover_auto','ipv6_enabled','snmp_enabled','auto_update'].forEach(k => { if (!body[k]) body[k] = '0'; });
  const { success } = await api.put('/settings', body);
  toast(success ? 'تم حفظ الإعدادات' : 'خطأ في الحفظ', success ? 'success' : 'error');
}
async function changePassword(e) {
  e.preventDefault();
  const fd = new FormData(e.target);
  const res = await fetch('/auth/change-password.php', { method:'POST', body: fd });
  const d = await res.json();
  toast(d.message || (d.success ? 'تم التغيير' : 'خطأ'), d.success ? 'success' : 'error');
}
</script>
