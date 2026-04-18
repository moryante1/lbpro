#!/bin/bash
# ============================================================
#  LoadBalancer Pro — Network Fix
#  يكتشف اسم الكارت تلقائياً ويضبط VLAN على نفس الكارت
# ============================================================

INSTALL_DIR="/var/www/lbpro"
DB_NAME="lbpro_db"
DB_USER="lbpro"
DB_PASS="admin123"

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'
ok()   { echo -e "${GREEN}[✔]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }

echo -e "\n${BOLD}${CYAN}━━━ إصلاح الشبكة + VLAN ━━━${NC}\n"

# ============================================================
# 1 — اكتشاف اسم الكارت الحقيقي
# ============================================================
# يأخذ الكارت الأول الذي له IP (غير lo)
REAL_IFACE=$(ip route get 8.8.8.8 2>/dev/null | grep -oP 'dev \K\S+' | head -1)
if [ -z "$REAL_IFACE" ]; then
    REAL_IFACE=$(ip link show | grep -v lo | grep 'state UP' | awk -F': ' '{print $2}' | head -1)
fi
if [ -z "$REAL_IFACE" ]; then
    REAL_IFACE=$(ip link show | grep -v lo | grep -v '@' | awk -F': ' 'NR==2{print $2}')
fi

REAL_IP=$(ip addr show "$REAL_IFACE" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -1)
REAL_GW=$(ip route show default 2>/dev/null | awk '{print $3}' | head -1)

echo -e "  الكارت المكتشف : ${CYAN}${REAL_IFACE}${NC}"
echo -e "  IP الحالي       : ${CYAN}${REAL_IP:-غير محدد}${NC}"
echo -e "  Gateway         : ${CYAN}${REAL_GW:-غير محدد}${NC}\n"

# ============================================================
# 2 — تحديث قاعدة البيانات باسم الكارت الحقيقي
# ============================================================
mysql -u root "$DB_NAME" << SQL
-- حذف القديم وإضافة الكارت الحقيقي
DELETE FROM \`interfaces\` WHERE \`name\` IN ('eth0','eth1','eth2','enp0s3','ether1');

INSERT INTO \`interfaces\`
  (\`name\`, \`display_name\`, \`type\`, \`ip_address\`, \`gateway\`, \`weight\`, \`metric\`, \`status\`, \`is_enabled\`)
VALUES
  ('${REAL_IFACE}', 'WAN-Main', 'static', '${REAL_IP}', '${REAL_GW}', 10, 100, 'up', 1);
SQL
ok "تم تسجيل الكارت: ${REAL_IFACE}"

# ============================================================
# 3 — تفعيل وحدة VLAN
# ============================================================
modprobe 8021q 2>/dev/null || true
echo "8021q" > /etc/modules-load.d/lbpro-vlan.conf
ok "وحدة VLAN (8021q) مفعّلة"

# ============================================================
# 4 — إصلاح Network.php ليستخدم الكارت الحقيقي
# ============================================================
cat > "${INSTALL_DIR}/includes/NetworkHelper.php" << PHPEOF
<?php
// ============================================================
//  NetworkHelper — يكتشف اسم الكارت تلقائياً
// ============================================================
class NetworkHelper {

    // اكتشاف الكارت الرئيسي تلقائياً
    public static function detectMainInterface(): string {
        // طريقة 1: من جدول التوجيه
        \$out = shell_exec("ip route get 8.8.8.8 2>/dev/null");
        if (preg_match('/dev\s+(\S+)/', \$out ?? '', \$m)) return \$m[1];

        // طريقة 2: أول كارت UP
        \$out = shell_exec("ip link show 2>/dev/null");
        preg_match_all('/\d+:\s+(\S+):.*state UP/', \$out ?? '', \$m);
        foreach (\$m[1] as \$iface) {
            if (\$iface !== 'lo') return \$iface;
        }

        // طريقة 3: من قاعدة البيانات
        \$row = Database::fetchOne("SELECT name FROM interfaces WHERE is_enabled=1 ORDER BY weight DESC LIMIT 1");
        return \$row['name'] ?? 'eth0';
    }

    // قراءة IP من الكارت مباشرة
    public static function getIfaceIp(string \$iface): string {
        \$out = shell_exec("ip addr show " . escapeshellarg(\$iface) . " 2>/dev/null");
        preg_match('/inet\s+(\d+\.\d+\.\d+\.\d+)/', \$out ?? '', \$m);
        return \$m[1] ?? '';
    }

    // إنشاء VLAN على الكارت الحقيقي
    public static function createVlan(string \$parentIface, int \$vlanId, string \$ipCidr): array {
        \$vlanIface = "{$parentIface}.{$vlanId}";

        // حذف القديم إن وجد
        shell_exec("sudo ip link del " . escapeshellarg(\$vlanIface) . " 2>/dev/null");

        \$cmds = [
            "sudo ip link add link " . escapeshellarg(\$parentIface) .
                " name " . escapeshellarg(\$vlanIface) .
                " type vlan id " . (int)\$vlanId,
            "sudo ip addr add " . escapeshellarg(\$ipCidr) .
                " dev " . escapeshellarg(\$vlanIface),
            "sudo ip link set " . escapeshellarg(\$vlanIface) . " up",
        ];

        foreach (\$cmds as \$cmd) {
            exec(\$cmd . " 2>&1", \$out, \$code);
            if (\$code !== 0) {
                return ['ok' => false, 'error' => implode("\n", \$out), 'cmd' => \$cmd];
            }
        }

        // حفظ في /etc/network/interfaces.d/ للبقاء بعد الريستارت
        \$persistFile = "/etc/network/interfaces.d/vlan{\$vlanId}";
        \$persistContent = "auto {\$vlanIface}\niface {\$vlanIface} inet static\n"
            . "  address {\$ipCidr}\n  vlan-raw-device {\$parentIface}\n";
        @file_put_contents(\$persistFile, \$persistContent);

        return ['ok' => true, 'vlan_interface' => \$vlanIface];
    }

    // حذف VLAN
    public static function deleteVlan(string \$vlanIface): bool {
        shell_exec("sudo ip link set " . escapeshellarg(\$vlanIface) . " down 2>/dev/null");
        shell_exec("sudo ip link del "  . escapeshellarg(\$vlanIface) . " 2>/dev/null");
        @unlink("/etc/network/interfaces.d/" . \$vlanIface);
        return true;
    }

    // تطبيق Static IP
    public static function applyStaticIp(string \$iface, string \$ip, string \$mask, string \$gw): bool {
        \$prefix = self::maskToPrefix(\$mask);
        \$cmds = [
            "sudo ip addr flush dev " . escapeshellarg(\$iface),
            "sudo ip addr add " . escapeshellarg("{$ip}/{$prefix}") . " dev " . escapeshellarg(\$iface),
            "sudo ip link set " . escapeshellarg(\$iface) . " up",
            "sudo ip route replace default via " . escapeshellarg(\$gw) . " dev " . escapeshellarg(\$iface),
        ];
        foreach (\$cmds as \$cmd) {
            exec(\$cmd . " 2>&1", \$out, \$code);
            if (\$code !== 0) return false;
        }
        return true;
    }

    // تحويل Subnet Mask إلى Prefix
    public static function maskToPrefix(string \$mask): int {
        return strlen(str_replace('0', '', decbin(ip2long(\$mask))));
    }

    // ping سريع
    public static function ping(string \$host, int \$count = 2): array {
        \$out = shell_exec("ping -c {\$count} -W 1 " . escapeshellarg(\$host) . " 2>&1");
        preg_match('/(\d+)% packet loss/', \$out ?? '', \$loss);
        preg_match('/rtt.*= [\d.]+\/([\d.]+)/', \$out ?? '', \$rtt);
        return [
            'reachable' => (int)(\$loss[1] ?? 100) < 100,
            'loss'      => (int)(\$loss[1] ?? 100),
            'latency'   => (float)(\$rtt[1] ?? 0),
        ];
    }

    // قراءة إحصائيات الكارت
    public static function getStats(string \$iface): array {
        \$base = "/sys/class/net/{\$iface}/statistics/";
        return [
            'rx_bytes'   => (int)@file_get_contents("{\$base}rx_bytes"),
            'tx_bytes'   => (int)@file_get_contents("{\$base}tx_bytes"),
            'rx_packets' => (int)@file_get_contents("{\$base}rx_packets"),
            'tx_packets' => (int)@file_get_contents("{\$base}tx_packets"),
            'rx_errors'  => (int)@file_get_contents("{\$base}rx_errors"),
            'tx_errors'  => (int)@file_get_contents("{\$base}tx_errors"),
        ];
    }
}
PHPEOF
ok "NetworkHelper.php تم إنشاؤه"

# ============================================================
# 5 — إصلاح صفحة VLANs لتستخدم الكارت الحقيقي
# ============================================================
cat > "${INSTALL_DIR}/public/pages/vlans.php" << PHPEOF
<?php
\$ifaces = Database::fetchAll("SELECT id, name FROM interfaces ORDER BY name");
\$vlans  = Database::fetchAll("
    SELECT v.*, i.name AS iface_name
    FROM vlans v
    JOIN interfaces i ON i.id = v.interface_id
    ORDER BY v.vlan_id
");

// اكتشاف الكارت الرئيسي تلقائياً
require_once dirname(__DIR__, 2) . '/includes/NetworkHelper.php';
\$mainIface = NetworkHelper::detectMainInterface();
?>
<div class="page-wrap">
  <div class="page-header" style="display:flex;justify-content:space-between;align-items:center">
    <div>
      <h1>إدارة VLANs</h1>
      <p>الكارت الرئيسي: <span class="mono" style="color:var(--cyan)"><?= htmlspecialchars(\$mainIface) ?></span> — <?= count(\$vlans) ?> VLAN</p>
    </div>
    <button class="btn btn-primary" onclick="openModal('modal-vlan')">+ إضافة VLAN</button>
  </div>

  <div class="card">
    <div class="table-wrap">
      <table class="table">
        <thead><tr>
          <th>VLAN ID</th><th>الاسم</th><th>الواجهة</th>
          <th>IP/Prefix</th><th>Gateway</th><th>النوع</th><th>الحالة</th><th>إجراءات</th>
        </tr></thead>
        <tbody>
          <?php foreach (\$vlans as \$v): ?>
          <tr>
            <td><span class="tag tag-vlan mono">VLAN<?= \$v['vlan_id'] ?></span></td>
            <td><?= htmlspecialchars(\$v['name']) ?></td>
            <td class="mono"><?= htmlspecialchars(\$v['vlan_interface'] ?: \$v['iface_name'].'.'.\$v['vlan_id']) ?></td>
            <td class="mono"><?= htmlspecialchars(\$v['ip_address']) ?>/<?= \$v['subnet'] ?></td>
            <td class="mono"><?= htmlspecialchars(\$v['gateway'] ?: '—') ?></td>
            <td><span class="tag tag-<?= \$v['vlan_type']==='tagged'?'vlan':'static' ?>"><?= \$v['vlan_type'] ?></span></td>
            <td><span class="badge badge-<?= \$v['status']==='active'?'green':'red' ?>"><?= \$v['status']==='active'?'نشط':'غير نشط' ?></span></td>
            <td>
              <button class="btn btn-sm btn-danger" onclick="deleteVlanById(<?= \$v['id'] ?>, '<?= htmlspecialchars(\$v['vlan_interface']) ?>')">حذف</button>
            </td>
          </tr>
          <?php endforeach; ?>
          <?php if(!\$vlans): ?>
          <tr><td colspan="8" style="text-align:center;color:var(--text3);padding:20px">
            لا توجد VLANs — أضف أول VLAN على كارت <strong><?= htmlspecialchars(\$mainIface) ?></strong>
          </td></tr>
          <?php endif; ?>
        </tbody>
      </table>
    </div>
  </div>
</div>

<!-- Modal إضافة VLAN -->
<div class="modal-overlay" id="modal-vlan">
  <div class="modal">
    <div class="modal-header">
      <div class="modal-title">إضافة VLAN على <?= htmlspecialchars(\$mainIface) ?></div>
      <div class="modal-close" onclick="closeModal('modal-vlan')">✕</div>
    </div>
    <form onsubmit="submitVlan(event)">
      <!-- الكارت الرئيسي ثابت تلقائياً -->
      <input type="hidden" name="interface_id" value="<?= \$ifaces[0]['id'] ?? 1 ?>">
      <input type="hidden" name="parent_iface" value="<?= htmlspecialchars(\$mainIface) ?>">

      <div class="form-row fr2">
        <div class="form-group">
          <label class="form-label">VLAN ID (1-4094)</label>
          <input class="form-input mono" name="vlan_id" type="number" min="1" max="4094" required placeholder="10">
        </div>
        <div class="form-group">
          <label class="form-label">الاسم</label>
          <input class="form-input" name="name" required placeholder="Clients">
        </div>
      </div>

      <div class="form-row fr2">
        <div class="form-group">
          <label class="form-label">عنوان IP للـ VLAN</label>
          <input class="form-input mono" name="ip_address" required placeholder="192.168.10.1">
        </div>
        <div class="form-group">
          <label class="form-label">Prefix (Subnet)</label>
          <input class="form-input mono" name="subnet" type="number" min="8" max="30" value="24">
        </div>
      </div>

      <div class="form-row fr2">
        <div class="form-group">
          <label class="form-label">Gateway (اختياري)</label>
          <input class="form-input mono" name="gateway" placeholder="192.168.10.254">
        </div>
        <div class="form-group">
          <label class="form-label">نوع VLAN</label>
          <select class="form-select" name="vlan_type">
            <option value="tagged">Tagged (Trunk)</option>
            <option value="untagged">Untagged (Access)</option>
          </select>
        </div>
      </div>

      <div class="form-row fr2">
        <div class="form-group">
          <label class="form-label">DNS Primary</label>
          <input class="form-input mono" name="dns1" value="8.8.8.8">
        </div>
        <div class="form-group">
          <label class="form-label">DNS Secondary</label>
          <input class="form-input mono" name="dns2" value="8.8.4.4">
        </div>
      </div>

      <div class="form-group" style="margin-bottom:12px">
        <label class="form-label">وصف (اختياري)</label>
        <input class="form-input" name="description" placeholder="وصف الشبكة">
      </div>

      <div style="background:var(--bg3);border-radius:var(--r);padding:10px 12px;margin-bottom:12px;font-size:11px;color:var(--text3)">
        📡 سيتم إنشاء الواجهة: <span class="mono" style="color:var(--cyan)"><?= htmlspecialchars(\$mainIface) ?>.<strong id="preview-vlan-id">XX</strong></span>
        مع IP: <span class="mono" style="color:var(--green)" id="preview-ip">—</span>
      </div>

      <div class="modal-footer">
        <button type="submit" class="btn btn-primary">إنشاء VLAN</button>
        <button type="button" class="btn" onclick="closeModal('modal-vlan')">إلغاء</button>
      </div>
    </form>
  </div>
</div>

<script>
// معاينة اسم الواجهة أثناء الكتابة
document.querySelector('[name=vlan_id]').addEventListener('input', function() {
  document.getElementById('preview-vlan-id').textContent = this.value || 'XX';
});
document.querySelector('[name=ip_address]').addEventListener('input', function() {
  const subnet = document.querySelector('[name=subnet]').value;
  document.getElementById('preview-ip').textContent = this.value ? this.value + '/' + subnet : '—';
});
document.querySelector('[name=subnet]').addEventListener('input', function() {
  const ip = document.querySelector('[name=ip_address]').value;
  if (ip) document.getElementById('preview-ip').textContent = ip + '/' + this.value;
});

async function submitVlan(e) {
  e.preventDefault();
  const fd   = new FormData(e.target);
  const body = Object.fromEntries(fd);
  body.vlan_id      = parseInt(body.vlan_id);
  body.subnet       = parseInt(body.subnet);
  body.interface_id = parseInt(body.interface_id);

  const btn = e.target.querySelector('[type=submit]');
  btn.textContent = 'جاري الإنشاء...'; btn.disabled = true;

  const { success, message, data } = await api.post('/vlans', body);
  btn.textContent = 'إنشاء VLAN'; btn.disabled = false;

  if (success) {
    toast('✔ تم إنشاء VLAN ' + body.vlan_id + ' على ' + body.parent_iface + '.' + body.vlan_id, 'success');
    closeModal('modal-vlan');
    setTimeout(() => location.reload(), 1000);
  } else {
    toast(message || 'خطأ في الإنشاء', 'error');
  }
}

async function deleteVlanById(id, vlanIface) {
  confirmDelete('حذف VLAN ' + vlanIface + '؟', async () => {
    const { success } = await api.delete('/vlans/' + id);
    if (success) { toast('تم الحذف', 'success'); setTimeout(() => location.reload(), 800); }
    else toast('خطأ في الحذف', 'error');
  });
}
</script>
PHPEOF
ok "صفحة VLANs محدّثة"

# ============================================================
# 6 — تحديث API لدعم الكارت الحقيقي
# ============================================================
# إصلاح الـ API endpoint الخاص بـ VLANs
cat > "${INSTALL_DIR}/api/vlans.php" << 'APIPHP'
<?php
require_once dirname(__DIR__) . '/includes/bootstrap.php';
require_once dirname(__DIR__) . '/includes/NetworkHelper.php';

$method = $_SERVER['REQUEST_METHOD'];
$body   = json_decode(file_get_contents('php://input'), true) ?? [];
$id     = (int)($_GET['id'] ?? 0);

header('Content-Type: application/json');

if ($method === 'GET') {
    $rows = Database::fetchAll("
        SELECT v.*, i.name AS iface_name
        FROM vlans v
        JOIN interfaces i ON i.id = v.interface_id
        ORDER BY v.vlan_id
    ");
    Response::ok($rows);
}

if ($method === 'POST') {
    // التحقق من الحقول المطلوبة
    foreach (['vlan_id','name','interface_id','ip_address','subnet'] as $f) {
        if (empty($body[$f])) Response::error("$f مطلوب");
    }

    // جلب اسم الكارت الأصلي
    $iface = Database::fetchOne("SELECT name FROM interfaces WHERE id=?", [(int)$body['interface_id']]);
    if (!$iface) {
        // استخدم الكارت المكتشف تلقائياً
        $ifaceName = NetworkHelper::detectMainInterface();
    } else {
        $ifaceName = $iface['name'];
    }

    $vlanIface = $ifaceName . '.' . (int)$body['vlan_id'];
    $ipCidr    = $body['ip_address'] . '/' . (int)$body['subnet'];

    // تطبيق VLAN على الكارت الحقيقي
    $result = NetworkHelper::createVlan($ifaceName, (int)$body['vlan_id'], $ipCidr);

    if (!$result['ok']) {
        Logger::error('vlan', "Failed: " . ($result['error'] ?? ''));
        Response::error('فشل تطبيق VLAN على الكارت: ' . ($result['error'] ?? 'خطأ غير معروف'));
    }

    // حفظ في قاعدة البيانات
    $newId = Database::insert('vlans', [
        'vlan_id'        => (int)$body['vlan_id'],
        'name'           => $body['name'],
        'interface_id'   => (int)$body['interface_id'],
        'vlan_interface' => $vlanIface,
        'ip_address'     => $body['ip_address'],
        'subnet'         => (int)$body['subnet'],
        'gateway'        => $body['gateway'] ?? null,
        'vlan_type'      => $body['vlan_type'] ?? 'tagged',
        'dns1'           => $body['dns1'] ?? '8.8.8.8',
        'dns2'           => $body['dns2'] ?? '8.8.4.4',
        'description'    => $body['description'] ?? null,
        'status'         => 'active',
    ]);

    Logger::info('vlan', "Created VLAN {$body['vlan_id']} on {$vlanIface}");
    Response::created(['id' => $newId, 'vlan_interface' => $vlanIface]);
}

if ($method === 'DELETE' && $id) {
    $vlan = Database::fetchOne("SELECT * FROM vlans WHERE id=?", [$id]);
    if (!$vlan) Response::notFound();

    NetworkHelper::deleteVlan($vlan['vlan_interface']);
    Database::delete('vlans', 'id=?', [$id]);
    Logger::info('vlan', "Deleted VLAN {$vlan['vlan_id']}");
    Response::ok(null, 'تم الحذف');
}

Response::error('Method not allowed', 405);
APIPHP
ok "API VLANs محدّث"

# ============================================================
# 7 — تحديث interfaces في DB
# ============================================================
mysql -u root "$DB_NAME" << SQL
UPDATE \`interfaces\`
SET \`name\` = '${REAL_IFACE}',
    \`display_name\` = 'WAN-Main (${REAL_IFACE})',
    \`ip_address\` = '${REAL_IP}',
    \`gateway\` = '${REAL_GW}',
    \`status\` = 'up'
WHERE \`name\` IN ('${REAL_IFACE}','eth0','eth1','enp0s3','ether1')
LIMIT 1;
SQL
ok "تم تحديث اسم الكارت في قاعدة البيانات"

# ============================================================
# 8 — Sudoers للأوامر الشبكية
# ============================================================
cat > /etc/sudoers.d/lbpro << 'SUDO'
www-data ALL=(root) NOPASSWD: /sbin/ip, /sbin/ifconfig, /sbin/route, /usr/bin/pppd, /sbin/pppoe-start, /sbin/pppoe-stop, /bin/systemctl restart networking, /sbin/iptables, /sbin/iptables-save, /sbin/nft, /usr/sbin/dhcpd, /bin/kill
SUDO
chmod 0440 /etc/sudoers.d/lbpro
ok "sudoers"

# ============================================================
# 9 — إعادة تشغيل
# ============================================================
chown -R www-data:www-data "${INSTALL_DIR}"
chmod -R 755 "${INSTALL_DIR}"
chmod 600 "${INSTALL_DIR}/config/config.php"
systemctl restart nginx php8.1-fpm 2>/dev/null || systemctl restart nginx php8.3-fpm 2>/dev/null
ok "Nginx + PHP-FPM أُعيد تشغيلهما"

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✔  تم إصلاح الشبكة بنجاح!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  🔌 الكارت الرئيسي : ${CYAN}${REAL_IFACE}${NC}"
echo -e "  🌐 IP الخادم       : ${CYAN}${REAL_IP}${NC}"
echo -e "  🗺  Gateway         : ${CYAN}${REAL_GW}${NC}"
echo ""
echo -e "  📡 مثال VLAN على نفس الكارت:"
echo -e "     VLAN 10 → ${CYAN}${REAL_IFACE}.10${NC} → IP: 192.168.10.1/24"
echo -e "     VLAN 20 → ${CYAN}${REAL_IFACE}.20${NC} → IP: 192.168.20.1/24"
echo ""
echo -e "  افتح لوحة التحكم: ${CYAN}http://${REAL_IP}${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
