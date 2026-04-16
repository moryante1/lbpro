#!/bin/bash
# ============================================================
#  LoadBalancer Pro - Full Installer
#  Ubuntu 22.04 LTS
#  Author: LBPro Install Script v2.4.1
# ============================================================
set -e

# ---- Colors ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

ok()   { echo -e "${GREEN}[✔]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}\n"; }

# ---- Banner ----
clear
echo -e "${CYAN}"
cat << 'EOF'
  _                 _ ____        _                           
 | |    ___   __ _| | __ )  __ _| | __ _ _ __   ___ ___ _ __
 | |   / _ \ / _` | |  _ \ / _` | |/ _` | '_ \ / __/ _ \ '__|
 | |__| (_) | (_| | | |_) | (_| | | (_| | | | | (_|  __/ |   
 |_____\___/ \__,_|_|____/ \__,_|_|\__,_|_| |_|\___\___|_|  Pro
EOF
echo -e "${NC}"
echo -e "${BOLD}  LoadBalancer Pro — Full Stack Installer v2.4.1${NC}"
echo -e "  Ubuntu 22.04 LTS | PHP 8.3 | MySQL 8.0 | Nginx\n"
echo -e "  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ---- Root check ----
[[ $EUID -ne 0 ]] && err "يجب تشغيل هذا السكريبت كـ root: sudo bash install.sh"

# ---- Interactive config ----
step "إعداد التثبيت"

read -p "  اسم النطاق أو IP الخادم [default: $(hostname -I | awk '{print $1}')]: " DOMAIN
DOMAIN=${DOMAIN:-$(hostname -I | awk '{print $1}')}

read -p "  اسم مستخدم MySQL الجديد [default: lbpro]: " DB_USER
DB_USER=${DB_USER:-lbpro}

read -s -p "  كلمة مرور MySQL (اضغط Enter لتوليد تلقائي): " DB_PASS
echo
if [ -z "$DB_PASS" ]; then
    DB_PASS=$(openssl rand -base64 18 | tr -d '=/+' | head -c 20)
    warn "كلمة المرور المُولَّدة تلقائياً: ${BOLD}${DB_PASS}${NC}"
fi

read -p "  اسم قاعدة البيانات [default: lbpro_db]: " DB_NAME
DB_NAME=${DB_NAME:-lbpro_db}

read -s -p "  كلمة مرور لوحة التحكم (admin): " ADMIN_PASS
echo
if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS=$(openssl rand -base64 12 | tr -d '=/+' | head -c 14)
    warn "كلمة مرور Admin المُولَّدة: ${BOLD}${ADMIN_PASS}${NC}"
fi

INSTALL_DIR="/var/www/lbpro"
JWT_SECRET=$(openssl rand -hex 32)

echo -e "\n  ${BOLD}ملخص التثبيت:${NC}"
echo -e "  النطاق/IP     : ${CYAN}${DOMAIN}${NC}"
echo -e "  مجلد التثبيت : ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  قاعدة البيانات: ${CYAN}${DB_NAME}@${DB_USER}${NC}"
echo -e ""
read -p "  هل تريد المتابعة؟ [Y/n]: " CONFIRM
[[ "${CONFIRM,,}" == "n" ]] && { info "تم الإلغاء."; exit 0; }

# ============================================================
step "1/8 — تحديث النظام"
# ============================================================
apt-get update -qq
apt-get upgrade -y -qq
ok "تم تحديث الحزم"

# ============================================================
step "2/8 — تثبيت المتطلبات الأساسية"
# ============================================================
apt-get install -y -qq \
    curl wget git unzip software-properties-common \
    net-tools iproute2 iptables iptables-persistent \
    nftables tcpdump traceroute mtr-tiny \
    jq bc sudo lsof htop \
    ppp pppoe pppoeconf \
    vlan bridge-utils \
    isc-dhcp-server \
    openssl ca-certificates gnupg lsb-release
ok "تم تثبيت أدوات الشبكة والمتطلبات"

# ============================================================
step "3/8 — تثبيت Nginx + PHP 8.3 + MySQL 8.0"
# ============================================================

# Nginx
apt-get install -y -qq nginx
ok "تم تثبيت Nginx"

# PHP 8.3
add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
apt-get update -qq
apt-get install -y -qq \
    php8.3-fpm php8.3-cli php8.3-mysql php8.3-curl \
    php8.3-json php8.3-mbstring php8.3-xml php8.3-zip \
    php8.3-bcmath php8.3-gd php8.3-redis php8.3-sockets
ok "تم تثبيت PHP 8.3-FPM"

# MySQL 8.0
apt-get install -y -qq mysql-server mysql-client
ok "تم تثبيت MySQL 8.0"

# Redis (for sessions/cache)
apt-get install -y -qq redis-server
ok "تم تثبيت Redis"

# ============================================================
step "4/8 — ضبط MySQL وإنشاء قاعدة البيانات"
# ============================================================
systemctl start mysql
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL_SCRIPT
ok "تم إنشاء قاعدة البيانات والمستخدم"

# ============================================================
step "5/8 — نسخ ملفات المشروع"
# ============================================================
mkdir -p "${INSTALL_DIR}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ -d "${SCRIPT_DIR}/public" ]; then
    cp -r "${SCRIPT_DIR}/." "${INSTALL_DIR}/"
    ok "تم نسخ الملفات من المجلد الحالي"
else
    warn "لم يتم العثور على ملفات المشروع في المجلد الحالي"
    warn "يرجى نسخ ملفات المشروع إلى: ${INSTALL_DIR}"
fi

# ============================================================
step "6/8 — ضبط ملف الإعدادات"
# ============================================================
cat > "${INSTALL_DIR}/config/config.php" <<PHPCONF
<?php
// ============================================================
//  LoadBalancer Pro — Main Config (auto-generated)
// ============================================================
define('APP_NAME',    'LoadBalancer Pro');
define('APP_VERSION', '2.4.1');
define('APP_URL',     'http://${DOMAIN}');
define('APP_ENV',     'production');
define('DEBUG_MODE',  false);

// Database
define('DB_HOST',     'localhost');
define('DB_PORT',     3306);
define('DB_NAME',     '${DB_NAME}');
define('DB_USER',     '${DB_USER}');
define('DB_PASS',     '${DB_PASS}');
define('DB_CHARSET',  'utf8mb4');

// Security
define('JWT_SECRET',      '${JWT_SECRET}');
define('SESSION_LIFETIME', 3600);
define('API_RATE_LIMIT',   100);   // requests per minute per key

// Paths
define('BASE_PATH',   '${INSTALL_DIR}');
define('LOG_PATH',    BASE_PATH . '/logs');
define('CACHE_PATH',  '/tmp/lbpro_cache');

// Network defaults
define('PING_INTERVAL', 30);       // seconds
define('FAILOVER_TRIES', 3);
define('DEFAULT_MTU', 1500);
define('PPPOE_MTU',   1492);

// Redis
define('REDIS_HOST', '127.0.0.1');
define('REDIS_PORT', 6379);
PHPCONF
ok "تم إنشاء ملف الإعدادات"

# ---- Import SQL schema ----
if [ -f "${INSTALL_DIR}/config/schema.sql" ]; then
    mysql -u root "${DB_NAME}" < "${INSTALL_DIR}/config/schema.sql"
    ok "تم استيراد مخطط قاعدة البيانات"
fi

# ---- Admin password hash ----
ADMIN_HASH=$(php -r "echo password_hash('${ADMIN_PASS}', PASSWORD_BCRYPT, ['cost'=>12]);")
mysql -u root "${DB_NAME}" <<SQL
INSERT INTO users (username, password_hash, role, email, created_at)
VALUES ('admin', '${ADMIN_HASH}', 'superadmin', 'admin@lbpro.local', NOW())
ON DUPLICATE KEY UPDATE password_hash='${ADMIN_HASH}';
SQL
ok "تم إنشاء مستخدم admin"

# ============================================================
step "7/8 — ضبط Nginx"
# ============================================================
cat > /etc/nginx/sites-available/lbpro <<NGINX
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    root ${INSTALL_DIR}/public;
    index index.php index.html;

    charset utf-8;
    client_max_body_size 50M;

    # Security headers
    add_header X-Frame-Options          "SAMEORIGIN"  always;
    add_header X-XSS-Protection         "1; mode=block" always;
    add_header X-Content-Type-Options   "nosniff"     always;
    add_header Referrer-Policy          "strict-origin-when-cross-origin" always;
    add_header Permissions-Policy       "geolocation=(), microphone=()" always;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml;

    # API routes
    location /api/ {
        try_files \$uri \$uri/ /api/index.php?\$query_string;
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, X-API-Key' always;
        if (\$request_method = 'OPTIONS') { return 204; }
    }

    # Main app
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP-FPM
    location ~ \.php$ {
        fastcgi_pass   unix:/run/php/php8.3-fpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
        fastcgi_read_timeout 60;
    }

    # Static assets cache
    location ~* \.(css|js|png|jpg|svg|ico|woff2|woff)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Deny hidden files
    location ~ /\. { deny all; }

    # Logs
    access_log /var/log/nginx/lbpro_access.log;
    error_log  /var/log/nginx/lbpro_error.log;
}
NGINX

ln -sf /etc/nginx/sites-available/lbpro /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && ok "ضبط Nginx صحيح"

# ---- PHP-FPM tuning ----
PHP_FPM_CONF="/etc/php/8.3/fpm/php.ini"
sed -i 's/^;*upload_max_filesize.*/upload_max_filesize = 50M/' "${PHP_FPM_CONF}"
sed -i 's/^;*post_max_size.*/post_max_size = 50M/'             "${PHP_FPM_CONF}"
sed -i 's/^;*memory_limit.*/memory_limit = 256M/'              "${PHP_FPM_CONF}"
sed -i 's/^;*max_execution_time.*/max_execution_time = 60/'    "${PHP_FPM_CONF}"
sed -i 's/^;*date.timezone.*/date.timezone = Asia\/Riyadh/'    "${PHP_FPM_CONF}"
ok "تم ضبط PHP-FPM"

# ============================================================
step "8/8 — الصلاحيات والخدمات والـ Cron"
# ============================================================

# Permissions
chown -R www-data:www-data "${INSTALL_DIR}"
chmod -R 755 "${INSTALL_DIR}"
chmod -R 775 "${INSTALL_DIR}/logs"
chmod 600 "${INSTALL_DIR}/config/config.php"

# Sudoers for www-data (network commands)
cat > /etc/sudoers.d/lbpro <<SUDO
www-data ALL=(root) NOPASSWD: /sbin/ip, /sbin/ifconfig, /sbin/route, /usr/bin/pppd, /sbin/pppoe-start, /sbin/pppoe-stop, /bin/systemctl restart networking, /sbin/iptables, /sbin/iptables-save, /sbin/nft, /usr/sbin/dhcpd
SUDO
chmod 0440 /etc/sudoers.d/lbpro
ok "تم ضبط صلاحيات sudo"

# Cron jobs
crontab -l -u www-data 2>/dev/null | grep -v lbpro > /tmp/cron_tmp || true
cat >> /tmp/cron_tmp <<CRON
# LBPro — مراقبة الخطوط كل 30 ثانية
* * * * * sleep 0  && php ${INSTALL_DIR}/cron/monitor.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
* * * * * sleep 30 && php ${INSTALL_DIR}/cron/monitor.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
# تحديث إحصائيات اليومية
0 0 * * * php ${INSTALL_DIR}/cron/daily_stats.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
# تنظيف السجلات القديمة
0 3 * * * php ${INSTALL_DIR}/cron/cleanup.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
CRON
crontab -u www-data /tmp/cron_tmp
ok "تم ضبط Cron Jobs"

# Enable IP forwarding
echo "net.ipv4.ip_forward=1"                      >> /etc/sysctl.d/99-lbpro.conf
echo "net.ipv4.conf.all.rp_filter=0"              >> /etc/sysctl.d/99-lbpro.conf
echo "net.ipv4.conf.default.rp_filter=0"          >> /etc/sysctl.d/99-lbpro.conf
echo "net.ipv4.tcp_window_scaling=1"              >> /etc/sysctl.d/99-lbpro.conf
echo "net.core.rmem_max=134217728"                >> /etc/sysctl.d/99-lbpro.conf
echo "net.core.wmem_max=134217728"                >> /etc/sysctl.d/99-lbpro.conf
sysctl -p /etc/sysctl.d/99-lbpro.conf > /dev/null 2>&1
ok "تم تفعيل IP Forwarding وضبط kernel parameters"

# 8021q module (VLAN)
modprobe 8021q
echo "8021q" >> /etc/modules-load.d/lbpro.conf
ok "تم تحميل وحدة VLAN (8021q)"

# Restart services
systemctl enable nginx php8.3-fpm mysql redis-server
systemctl restart nginx php8.3-fpm mysql redis-server
ok "تم تشغيل جميع الخدمات"

# ============================================================
#  Summary
# ============================================================
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✔  تم تثبيت LoadBalancer Pro بنجاح!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}رابط لوحة التحكم:${NC}  http://${DOMAIN}"
echo -e "  ${BOLD}المستخدم:${NC}           admin"
echo -e "  ${BOLD}كلمة المرور:${NC}        ${RED}${ADMIN_PASS}${NC}  ← احفظها الآن!"
echo ""
echo -e "  ${BOLD}قاعدة البيانات:${NC}"
echo -e "    Host: localhost | DB: ${DB_NAME}"
echo -e "    User: ${DB_USER} | Pass: ${DB_PASS}"
echo ""
echo -e "  ${BOLD}ملف الإعدادات:${NC}     ${INSTALL_DIR}/config/config.php"
echo -e "  ${BOLD}السجلات:${NC}           ${INSTALL_DIR}/logs/"
echo -e "  ${BOLD}Nginx:${NC}             /var/log/nginx/lbpro_*.log"
echo ""
echo -e "  ${YELLOW}${BOLD}⚠  احفظ كلمات المرور أعلاه في مكان آمن!${NC}"
echo ""
