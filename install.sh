#!/bin/bash
# ============================================================
#  LoadBalancer Pro - Full Installer
#  Ubuntu 22.04 LTS | PHP 8.1 | MySQL 8.0 | Nginx
#  GitHub: moryante1/lbpro
#  تشغيل: sudo bash install.sh
# ============================================================
set -e

# ---- Colors ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

ok()   { echo -e "${GREEN}[✔]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n    $1\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

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
echo -e "${BOLD}  LoadBalancer Pro — Full Installer v2.4.1${NC}"
echo -e "  Ubuntu 22.04 LTS | PHP 8.1 | MySQL 8.0 | Nginx | Redis"
echo -e "  GitHub: ${CYAN}moryante1/lbpro${NC}"
echo -e "\n  ${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# ---- Root check ----
[[ $EUID -ne 0 ]] && err "يجب تشغيل هذا السكريبت كـ root: sudo bash install.sh"

# ---- Ubuntu version check ----
OS_VER=$(lsb_release -rs 2>/dev/null || echo "0")
if [[ "$OS_VER" != "22.04" ]] && [[ "$OS_VER" != "20.04" ]]; then
    warn "هذا السكريبت مُختبر على Ubuntu 22.04 — أنت على ${OS_VER}"
    read -p "  هل تريد المتابعة رغم ذلك؟ [y/N]: " OSOK
    [[ "${OSOK,,}" != "y" ]] && exit 0
fi

# ============================================================
# ---- Interactive config ----
# ============================================================
step "إعداد التثبيت — أجب على الأسئلة التالية"

DEFAULT_IP=$(hostname -I | awk '{print $1}')
read -p "  اسم النطاق أو IP الخادم [default: ${DEFAULT_IP}]: " DOMAIN
DOMAIN=${DOMAIN:-$DEFAULT_IP}

read -p "  اسم مستخدم MySQL [default: lbpro]: " DB_USER
DB_USER=${DB_USER:-lbpro}

read -s -p "  كلمة مرور MySQL (Enter = توليد تلقائي): " DB_PASS
echo
if [ -z "$DB_PASS" ]; then
    DB_PASS=$(openssl rand -base64 18 | tr -d '=/+' | head -c 20)
    warn "كلمة المرور المُولَّدة: ${BOLD}${DB_PASS}${NC}"
fi

read -p "  اسم قاعدة البيانات [default: lbpro_db]: " DB_NAME
DB_NAME=${DB_NAME:-lbpro_db}

read -s -p "  كلمة مرور لوحة التحكم/admin (Enter = توليد تلقائي): " ADMIN_PASS
echo
if [ -z "$ADMIN_PASS" ]; then
    ADMIN_PASS=$(openssl rand -base64 12 | tr -d '=/+' | head -c 14)
    warn "كلمة مرور Admin: ${BOLD}${ADMIN_PASS}${NC}"
fi

INSTALL_DIR="/var/www/lbpro"
JWT_SECRET=$(openssl rand -hex 32)
PHP_VER="8.1"
GITHUB_ZIP="https://codeload.github.com/moryante1/lbpro/zip/refs/heads/main"

echo -e "\n  ${BOLD}┌─ ملخص التثبيت ─────────────────────────┐${NC}"
echo -e "  │ النطاق/IP     : ${CYAN}${DOMAIN}${NC}"
echo -e "  │ مجلد التثبيت : ${CYAN}${INSTALL_DIR}${NC}"
echo -e "  │ قاعدة البيانات: ${CYAN}${DB_NAME}${NC} | مستخدم: ${CYAN}${DB_USER}${NC}"
echo -e "  │ PHP           : ${CYAN}${PHP_VER}${NC}"
echo -e "  │ GitHub        : ${CYAN}moryante1/lbpro${NC}"
echo -e "  ${BOLD}└────────────────────────────────────────┘${NC}\n"

read -p "  هل تريد المتابعة؟ [Y/n]: " CONFIRM
[[ "${CONFIRM,,}" == "n" ]] && { info "تم الإلغاء."; exit 0; }

# ============================================================
step "1/9 — تحديث النظام وتثبيت الأدوات الأساسية"
# ============================================================
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
    curl wget git unzip zip \
    software-properties-common \
    net-tools iproute2 \
    iptables iptables-persistent \
    nftables tcpdump traceroute mtr-tiny \
    jq bc lsof htop \
    ppp pppoe pppoeconf \
    vlan bridge-utils \
    isc-dhcp-server \
    openssl ca-certificates gnupg lsb-release
ok "تم تثبيت الأدوات الأساسية"

# ============================================================
step "2/9 — تثبيت Nginx"
# ============================================================
apt-get install -y -qq nginx
systemctl enable nginx
systemctl start nginx
ok "تم تثبيت Nginx"

# ============================================================
step "3/9 — تثبيت PHP ${PHP_VER}"
# ============================================================
# إضافة مستودع ondrej/php
if ! grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null; then
    add-apt-repository -y ppa:ondrej/php > /dev/null 2>&1
    apt-get update -qq
fi

apt-get install -y -qq \
    php${PHP_VER}-fpm \
    php${PHP_VER}-cli \
    php${PHP_VER}-mysql \
    php${PHP_VER}-curl \
    php${PHP_VER}-mbstring \
    php${PHP_VER}-xml \
    php${PHP_VER}-zip \
    php${PHP_VER}-bcmath \
    php${PHP_VER}-gd \
    php${PHP_VER}-sockets

# redis extension (اختياري — لا يوقف التثبيت إن فشل)
apt-get install -y -qq php${PHP_VER}-redis 2>/dev/null || warn "php-redis غير متاح — سيتم تخطيه"

systemctl enable php${PHP_VER}-fpm
systemctl start  php${PHP_VER}-fpm
ok "تم تثبيت PHP ${PHP_VER}-FPM"

# ============================================================
step "4/9 — تثبيت MySQL 8.0 و Redis"
# ============================================================
apt-get install -y -qq mysql-server mysql-client
apt-get install -y -qq redis-server

systemctl enable mysql redis-server
systemctl start  mysql redis-server
ok "تم تثبيت MySQL و Redis"

# ============================================================
step "5/9 — إنشاء قاعدة البيانات والمستخدم"
# ============================================================
mysql -u root <<MYSQL_SCRIPT
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
    IDENTIFIED BY '${DB_PASS}';

GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.*
    TO '${DB_USER}'@'localhost';

FLUSH PRIVILEGES;
MYSQL_SCRIPT
ok "تم إنشاء قاعدة البيانات: ${DB_NAME}"

# ============================================================
step "6/9 — تحميل ملفات المشروع من GitHub"
# ============================================================
TMP_ZIP="/tmp/lbpro_main.zip"
TMP_DIR="/tmp/lbpro_src"

info "جاري التحميل من: ${GITHUB_ZIP}"
wget -q --show-progress -O "${TMP_ZIP}" "${GITHUB_ZIP}" || \
    curl -sL "${GITHUB_ZIP}" -o "${TMP_ZIP}" || \
    err "فشل تحميل الملفات من GitHub — تحقق من الاتصال بالإنترنت"

# فك الضغط
rm -rf "${TMP_DIR}"
mkdir -p "${TMP_DIR}"
unzip -q "${TMP_ZIP}" -d "${TMP_DIR}"
rm -f "${TMP_ZIP}"

# تحديد المجلد المُستخرج (GitHub يضيف -main)
EXTRACTED=$(find "${TMP_DIR}" -maxdepth 1 -type d | grep -v "^${TMP_DIR}$" | head -1)
if [ -z "$EXTRACTED" ]; then
    err "فشل فك الضغط أو الملفات فارغة"
fi

info "تم استخراج الملفات من: ${EXTRACTED}"

# نسخ للمسار النهائي
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cp -r "${EXTRACTED}/." "${INSTALL_DIR}/"
rm -rf "${TMP_DIR}"

# إنشاء المجلدات المطلوبة
mkdir -p "${INSTALL_DIR}/logs"
mkdir -p "${INSTALL_DIR}/config"
mkdir -p "${INSTALL_DIR}/public/assets/css"
mkdir -p "${INSTALL_DIR}/public/assets/js"
mkdir -p "${INSTALL_DIR}/public/pages"
mkdir -p "${INSTALL_DIR}/public/auth"
mkdir -p "${INSTALL_DIR}/cron"

ok "تم تحميل ونسخ ملفات المشروع إلى ${INSTALL_DIR}"

# ============================================================
step "7/9 — إنشاء ملف الإعدادات"
# ============================================================
cat > "${INSTALL_DIR}/config/config.php" << PHPCONF
<?php
// ============================================================
//  LoadBalancer Pro — Main Config (auto-generated by installer)
//  تاريخ التثبيت: $(date '+%Y-%m-%d %H:%M:%S')
// ============================================================
define('APP_NAME',    'LoadBalancer Pro');
define('APP_VERSION', '2.4.1');
define('APP_URL',     'http://${DOMAIN}');
define('APP_ENV',     'production');
define('DEBUG_MODE',  false);

// Database
define('DB_HOST',    'localhost');
define('DB_PORT',    3306);
define('DB_NAME',    '${DB_NAME}');
define('DB_USER',    '${DB_USER}');
define('DB_PASS',    '${DB_PASS}');
define('DB_CHARSET', 'utf8mb4');

// Security
define('JWT_SECRET',       '${JWT_SECRET}');
define('SESSION_LIFETIME',  3600);
define('API_RATE_LIMIT',    100);

// Paths
define('BASE_PATH',  '${INSTALL_DIR}');
define('LOG_PATH',   BASE_PATH . '/logs');
define('CACHE_PATH', '/tmp/lbpro_cache');

// Network defaults
define('PING_INTERVAL',  30);
define('FAILOVER_TRIES',  3);
define('DEFAULT_MTU',  1500);
define('PPPOE_MTU',    1492);

// Redis
define('REDIS_HOST', '127.0.0.1');
define('REDIS_PORT',  6379);
PHPCONF
ok "تم إنشاء config.php"

# ---- استيراد قاعدة البيانات ----
if [ -f "${INSTALL_DIR}/config/schema.sql" ]; then
    mysql -u root "${DB_NAME}" < "${INSTALL_DIR}/config/schema.sql"
    ok "تم استيراد schema.sql"
else
    warn "لم يتم العثور على schema.sql — يرجى استيراده يدوياً"
fi

# ---- إنشاء مستخدم admin ----
ADMIN_HASH=$(php${PHP_VER} -r "echo password_hash('${ADMIN_PASS}', PASSWORD_BCRYPT, ['cost'=>12]);")
mysql -u root "${DB_NAME}" << SQL
INSERT INTO users (username, password_hash, role, email, created_at)
VALUES ('admin', '${ADMIN_HASH}', 'superadmin', 'admin@lbpro.local', NOW())
ON DUPLICATE KEY UPDATE password_hash='${ADMIN_HASH}';
SQL
ok "تم إنشاء مستخدم admin"

# ============================================================
step "8/9 — ضبط Nginx"
# ============================================================
cat > /etc/nginx/sites-available/lbpro << NGINX
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name ${DOMAIN} _;
    root ${INSTALL_DIR}/public;
    index index.php index.html;

    charset utf-8;
    client_max_body_size 50M;

    # Security headers
    add_header X-Frame-Options        "SAMEORIGIN"  always;
    add_header X-XSS-Protection       "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff"     always;
    add_header Referrer-Policy        "strict-origin-when-cross-origin" always;

    # Gzip
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml;

    # API routes
    location /api/ {
        try_files \$uri \$uri/ /api/index.php?\$query_string;
        add_header 'Access-Control-Allow-Origin'  '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, PUT, DELETE, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization, Content-Type, X-API-Key' always;
        if (\$request_method = 'OPTIONS') { return 204; }
    }

    # Main app
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    # PHP-FPM — PHP ${PHP_VER}
    location ~ \.php$ {
        fastcgi_pass   unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
        fastcgi_read_timeout 60;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
    }

    # Static assets cache
    location ~* \.(css|js|png|jpg|svg|ico|woff2|woff|ttf)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    # Deny hidden files & sensitive files
    location ~ /\. { deny all; }
    location ~ /(config|includes|cron|logs)/ { deny all; }

    # Logs
    access_log /var/log/nginx/lbpro_access.log;
    error_log  /var/log/nginx/lbpro_error.log warn;
}
NGINX

# تفعيل الموقع وإلغاء الصفحة الافتراضية
ln -sf /etc/nginx/sites-available/lbpro /etc/nginx/sites-enabled/lbpro
rm -f /etc/nginx/sites-enabled/default

# اختبار إعداد Nginx
nginx -t && ok "ضبط Nginx صحيح" || err "خطأ في ضبط Nginx — راجع: sudo nginx -t"

# ---- ضبط PHP-FPM ----
PHP_INI="/etc/php/${PHP_VER}/fpm/php.ini"
if [ -f "$PHP_INI" ]; then
    sed -i 's/^;*upload_max_filesize.*/upload_max_filesize = 50M/'   "$PHP_INI"
    sed -i 's/^;*post_max_size.*/post_max_size = 50M/'               "$PHP_INI"
    sed -i 's/^;*memory_limit.*/memory_limit = 256M/'                "$PHP_INI"
    sed -i 's/^;*max_execution_time.*/max_execution_time = 60/'      "$PHP_INI"
    sed -i 's|^;*date.timezone.*|date.timezone = Asia/Riyadh|'       "$PHP_INI"
    ok "تم ضبط php.ini"
fi

# ============================================================
step "9/9 — الصلاحيات والخدمات والـ Cron"
# ============================================================

# ---- الصلاحيات ----
chown -R www-data:www-data "${INSTALL_DIR}"
chmod -R 755 "${INSTALL_DIR}"
chmod -R 775 "${INSTALL_DIR}/logs"
chmod 600 "${INSTALL_DIR}/config/config.php"
ok "تم ضبط الصلاحيات"

# ---- Sudoers ----
cat > /etc/sudoers.d/lbpro << SUDO
# LoadBalancer Pro — network commands for www-data
www-data ALL=(root) NOPASSWD: /sbin/ip, /sbin/ifconfig, /sbin/route, /usr/bin/pppd, /sbin/pppoe-start, /sbin/pppoe-stop, /bin/systemctl restart networking, /sbin/iptables, /sbin/iptables-save, /sbin/nft, /usr/sbin/dhcpd, /bin/kill
SUDO
chmod 0440 /etc/sudoers.d/lbpro
ok "تم ضبط sudoers"

# ---- Cron Jobs ----
(crontab -l -u www-data 2>/dev/null | grep -v lbpro; \
cat << CRON
# LBPro — مراقبة الخطوط كل 30 ثانية
* * * * * sleep 0  && /usr/bin/php${PHP_VER} ${INSTALL_DIR}/cron/monitor.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
* * * * * sleep 30 && /usr/bin/php${PHP_VER} ${INSTALL_DIR}/cron/monitor.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
# إحصائيات يومية
0 0 * * * /usr/bin/php${PHP_VER} ${INSTALL_DIR}/cron/daily_stats.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
# تنظيف قديم
0 3 * * * /usr/bin/php${PHP_VER} ${INSTALL_DIR}/cron/cleanup.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
CRON
) | crontab -u www-data -
ok "تم ضبط Cron Jobs"

# ---- Kernel / Network ----
cat > /etc/sysctl.d/99-lbpro.conf << SYSCTL
# LoadBalancer Pro kernel settings
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
SYSCTL
sysctl -p /etc/sysctl.d/99-lbpro.conf > /dev/null 2>&1
ok "تم تفعيل IP Forwarding وضبط Kernel"

# VLAN module
modprobe 8021q 2>/dev/null || true
echo "8021q" >> /etc/modules-load.d/lbpro.conf
ok "تم تحميل وحدة VLAN (8021q)"

# ---- إعادة تشغيل جميع الخدمات ----
systemctl enable  nginx php${PHP_VER}-fpm mysql redis-server
systemctl restart nginx php${PHP_VER}-fpm mysql redis-server
ok "تم تشغيل جميع الخدمات"

# ---- التحقق النهائي ----
sleep 2
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
    SITE_STATUS="${GREEN}✔ يعمل (HTTP ${HTTP_CODE})${NC}"
else
    SITE_STATUS="${YELLOW}⚠ HTTP ${HTTP_CODE} — تحقق من السجلات${NC}"
fi

# ============================================================
#  ملخص التثبيت النهائي
# ============================================================
echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✔  تم تثبيت LoadBalancer Pro بنجاح!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}🌐 رابط لوحة التحكم:${NC}  ${CYAN}http://${DOMAIN}${NC}"
echo -e "  ${BOLD}👤 المستخدم:${NC}           admin"
echo -e "  ${BOLD}🔑 كلمة المرور:${NC}        ${RED}${BOLD}${ADMIN_PASS}${NC}  ← احفظها الآن!"
echo ""
echo -e "  ${BOLD}🗄  قاعدة البيانات:${NC}"
echo -e "      Host: localhost | DB: ${CYAN}${DB_NAME}${NC}"
echo -e "      User: ${CYAN}${DB_USER}${NC} | Pass: ${RED}${DB_PASS}${NC}"
echo ""
echo -e "  ${BOLD}🔧 تفاصيل النظام:${NC}"
echo -e "      PHP:   ${PHP_VER}-FPM"
echo -e "      Nginx: $(nginx -v 2>&1 | grep -o 'nginx/[0-9.]*')"
echo -e "      MySQL: $(mysql --version 2>/dev/null | grep -o '[0-9]*\.[0-9]*\.[0-9]*' | head -1)"
echo -e "      حالة الموقع: $(echo -e $SITE_STATUS)"
echo ""
echo -e "  ${BOLD}📁 المسارات:${NC}"
echo -e "      ملفات المشروع : ${INSTALL_DIR}"
echo -e "      ملف الإعدادات : ${INSTALL_DIR}/config/config.php"
echo -e "      السجلات       : ${INSTALL_DIR}/logs/"
echo -e "      Nginx logs    : /var/log/nginx/lbpro_*.log"
echo ""
echo -e "  ${BOLD}📋 أوامر مفيدة:${NC}"
echo -e "      sudo systemctl status nginx php${PHP_VER}-fpm mysql"
echo -e "      tail -f ${INSTALL_DIR}/logs/system.log"
echo -e "      tail -f /var/log/nginx/lbpro_error.log"
echo ""
echo -e "  ${YELLOW}${BOLD}⚠  احفظ كلمات المرور أعلاه في مكان آمن!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
