#!/bin/bash
# ============================================================
#  LoadBalancer Pro - Full Installer v2.4.2
#  Ubuntu 22.04 LTS | PHP 8.1 | MySQL 8.0 | Nginx | Redis
#  FIXED: schema key word conflict + skey column
# ============================================================
set -e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

ok()   { echo -e "${GREEN}[✔]${NC} $1"; }
info() { echo -e "${CYAN}[i]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; exit 1; }
step() { echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n    $1\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"; }

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
echo -e "${BOLD}  LoadBalancer Pro — Full Installer v2.4.2${NC}"
echo -e "  Ubuntu 22.04 LTS | PHP 8.1 | MySQL 8.0 | Nginx | Redis"
echo -e "  ${CYAN}github.com/moryante1/lbpro${NC}\n"

[[ $EUID -ne 0 ]] && err "شغّل كـ root: sudo bash install.sh"

# ============================================================
step "إعداد التثبيت"
# ============================================================
DEFAULT_IP=$(hostname -I | awk '{print $1}')
read -p "  IP أو نطاق الخادم [${DEFAULT_IP}]: " DOMAIN
DOMAIN=${DOMAIN:-$DEFAULT_IP}

read -p "  مستخدم MySQL [lbpro]: " DB_USER
DB_USER=${DB_USER:-lbpro}

read -s -p "  كلمة مرور MySQL (Enter = تلقائي): " DB_PASS; echo
[ -z "$DB_PASS" ] && DB_PASS=$(openssl rand -base64 18 | tr -d '=/+' | head -c 20) \
  && warn "كلمة المرور التلقائية: ${BOLD}${DB_PASS}${NC}"

read -p "  اسم قاعدة البيانات [lbpro_db]: " DB_NAME
DB_NAME=${DB_NAME:-lbpro_db}

read -s -p "  كلمة مرور admin (Enter = تلقائي): " ADMIN_PASS; echo
[ -z "$ADMIN_PASS" ] && ADMIN_PASS=$(openssl rand -base64 12 | tr -d '=/+' | head -c 14) \
  && warn "كلمة مرور Admin: ${BOLD}${ADMIN_PASS}${NC}"

INSTALL_DIR="/var/www/lbpro"
JWT_SECRET=$(openssl rand -hex 32)
PHP_VER="8.1"
GITHUB_ZIP="https://codeload.github.com/moryante1/lbpro/zip/refs/heads/main"

echo -e "\n  ${BOLD}ملخص:${NC} IP=${CYAN}${DOMAIN}${NC} | DB=${CYAN}${DB_NAME}${NC} | PHP=${CYAN}${PHP_VER}${NC}\n"
read -p "  متابعة؟ [Y/n]: " C; [[ "${C,,}" == "n" ]] && exit 0

# ============================================================
step "1/9 — تحديث النظام"
# ============================================================
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get upgrade -y -qq
apt-get install -y -qq \
  curl wget git unzip zip software-properties-common \
  net-tools iproute2 iptables iptables-persistent \
  nftables tcpdump traceroute mtr-tiny jq bc lsof htop \
  ppp pppoe pppoeconf vlan bridge-utils isc-dhcp-server \
  openssl ca-certificates gnupg lsb-release
ok "الأدوات الأساسية"

# ============================================================
step "2/9 — Nginx"
# ============================================================
apt-get install -y -qq nginx
systemctl enable nginx --now
ok "Nginx"

# ============================================================
step "3/9 — PHP ${PHP_VER}"
# ============================================================
grep -q "ondrej/php" /etc/apt/sources.list.d/*.list 2>/dev/null \
  || { add-apt-repository -y ppa:ondrej/php >/dev/null 2>&1; apt-get update -qq; }

apt-get install -y -qq \
  php${PHP_VER}-fpm php${PHP_VER}-cli php${PHP_VER}-mysql \
  php${PHP_VER}-curl php${PHP_VER}-mbstring php${PHP_VER}-xml \
  php${PHP_VER}-zip php${PHP_VER}-bcmath php${PHP_VER}-gd \
  php${PHP_VER}-sockets
apt-get install -y -qq php${PHP_VER}-redis 2>/dev/null \
  || warn "php-redis غير متاح — سيتم تخطيه"

systemctl enable php${PHP_VER}-fpm --now
ok "PHP ${PHP_VER}-FPM"

# ============================================================
step "4/9 — MySQL + Redis"
# ============================================================
apt-get install -y -qq mysql-server mysql-client redis-server
systemctl enable mysql redis-server
systemctl start  mysql redis-server
ok "MySQL 8.0 + Redis"

# ============================================================
step "5/9 — قاعدة البيانات"
# ============================================================
mysql -u root << MYSQL
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '${DB_USER}'@'localhost'
  IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'localhost';
FLUSH PRIVILEGES;
MYSQL
ok "قاعدة البيانات: ${DB_NAME}"

# ============================================================
step "6/9 — تحميل الملفات من GitHub"
# ============================================================
TMP_ZIP="/tmp/lbpro_main.zip"
TMP_DIR="/tmp/lbpro_src"

info "جاري التحميل..."
wget -q --show-progress -O "${TMP_ZIP}" "${GITHUB_ZIP}" \
  || curl -sL "${GITHUB_ZIP}" -o "${TMP_ZIP}" \
  || err "فشل التحميل — تحقق من الإنترنت"

rm -rf "${TMP_DIR}"; mkdir -p "${TMP_DIR}"
unzip -q "${TMP_ZIP}" -d "${TMP_DIR}"; rm -f "${TMP_ZIP}"

EXTRACTED=$(find "${TMP_DIR}" -maxdepth 1 -mindepth 1 -type d | head -1)
[ -z "$EXTRACTED" ] && err "فشل فك الضغط"

rm -rf "${INSTALL_DIR}"; mkdir -p "${INSTALL_DIR}"
cp -r "${EXTRACTED}/." "${INSTALL_DIR}/"
rm -rf "${TMP_DIR}"

mkdir -p "${INSTALL_DIR}"/{logs,config,public/assets/{css,js},public/pages,public/auth,cron,includes,api}
ok "تم نسخ الملفات إلى ${INSTALL_DIR}"

# ============================================================
step "7/9 — ملف الإعدادات + قاعدة البيانات"
# ============================================================

# config.php
cat > "${INSTALL_DIR}/config/config.php" << PHPCONF
<?php
define('APP_NAME',    'LoadBalancer Pro');
define('APP_VERSION', '2.4.2');
define('APP_URL',     'http://${DOMAIN}');
define('APP_ENV',     'production');
define('DEBUG_MODE',  false);

define('DB_HOST',    'localhost');
define('DB_PORT',    3306);
define('DB_NAME',    '${DB_NAME}');
define('DB_USER',    '${DB_USER}');
define('DB_PASS',    '${DB_PASS}');
define('DB_CHARSET', 'utf8mb4');

define('JWT_SECRET',      '${JWT_SECRET}');
define('SESSION_LIFETIME', 3600);
define('API_RATE_LIMIT',   100);

define('BASE_PATH',  '${INSTALL_DIR}');
define('LOG_PATH',   BASE_PATH . '/logs');
define('CACHE_PATH', '/tmp/lbpro_cache');

define('PING_INTERVAL',  30);
define('FAILOVER_TRIES',  3);
define('DEFAULT_MTU',  1500);
define('PPPOE_MTU',    1492);

define('REDIS_HOST', '127.0.0.1');
define('REDIS_PORT',  6379);
PHPCONF
ok "config.php"

# ---- schema.sql (مدمج مباشرة في install.sh لضمان الصحة) ----
mysql -u root "${DB_NAME}" << 'SCHEMA'
SET NAMES utf8mb4;
SET foreign_key_checks = 0;
SET sql_mode = 'NO_ENGINE_SUBSTITUTION';

CREATE TABLE IF NOT EXISTS `users` (
  `id`            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `username`      VARCHAR(60)  NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `email`         VARCHAR(120) NOT NULL,
  `role`          ENUM('superadmin','admin','readonly') NOT NULL DEFAULT 'admin',
  `last_login`    DATETIME     DEFAULT NULL,
  `is_active`     TINYINT(1)   NOT NULL DEFAULT 1,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `interfaces` (
  `id`           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name`         VARCHAR(30)  NOT NULL UNIQUE,
  `display_name` VARCHAR(60)  DEFAULT NULL,
  `type`         ENUM('pppoe','dhcp','static') NOT NULL DEFAULT 'dhcp',
  `ip_address`   VARCHAR(45)  DEFAULT NULL,
  `subnet_mask`  VARCHAR(45)  DEFAULT '255.255.255.0',
  `gateway`      VARCHAR(45)  DEFAULT NULL,
  `dns1`         VARCHAR(45)  DEFAULT '8.8.8.8',
  `dns2`         VARCHAR(45)  DEFAULT '8.8.4.4',
  `mtu`          SMALLINT UNSIGNED DEFAULT 1500,
  `weight`       TINYINT UNSIGNED  DEFAULT 1,
  `metric`       SMALLINT UNSIGNED DEFAULT 100,
  `is_enabled`   TINYINT(1)   NOT NULL DEFAULT 1,
  `status`       ENUM('up','down','connecting','disabled') DEFAULT 'down',
  `speed_in`     BIGINT UNSIGNED DEFAULT 0,
  `speed_out`    BIGINT UNSIGNED DEFAULT 0,
  `last_seen`    DATETIME DEFAULT NULL,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pppoe_connections` (
  `id`                INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `interface_id`      INT UNSIGNED NOT NULL,
  `username`          VARCHAR(120) NOT NULL,
  `password`          VARCHAR(255) NOT NULL,
  `service_name`      VARCHAR(60)  DEFAULT NULL,
  `mru`               SMALLINT UNSIGNED DEFAULT 1492,
  `mtu`               SMALLINT UNSIGNED DEFAULT 1492,
  `lcp_echo_interval` SMALLINT UNSIGNED DEFAULT 30,
  `lcp_echo_failure`  TINYINT UNSIGNED  DEFAULT 4,
  `persist`           TINYINT(1)  DEFAULT 1,
  `maxfail`           TINYINT UNSIGNED  DEFAULT 0,
  `status`            ENUM('connected','disconnected','connecting','error') DEFAULT 'disconnected',
  `assigned_ip`       VARCHAR(45) DEFAULT NULL,
  `server_ip`         VARCHAR(45) DEFAULT NULL,
  `session_id`        VARCHAR(20) DEFAULT NULL,
  `connected_at`      DATETIME    DEFAULT NULL,
  `bytes_in`          BIGINT UNSIGNED DEFAULT 0,
  `bytes_out`         BIGINT UNSIGNED DEFAULT 0,
  `created_at`        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`        DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  FOREIGN KEY (`interface_id`) REFERENCES `interfaces`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `vlans` (
  `id`             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `vlan_id`        SMALLINT UNSIGNED NOT NULL,
  `name`           VARCHAR(60)  NOT NULL,
  `interface_id`   INT UNSIGNED NOT NULL,
  `vlan_interface` VARCHAR(30)  DEFAULT NULL,
  `ip_address`     VARCHAR(45)  NOT NULL,
  `subnet`         TINYINT UNSIGNED NOT NULL DEFAULT 24,
  `gateway`        VARCHAR(45)  DEFAULT NULL,
  `vlan_type`      ENUM('tagged','untagged') DEFAULT 'tagged',
  `dhcp_enabled`   TINYINT(1)   DEFAULT 1,
  `dns1`           VARCHAR(45)  DEFAULT '8.8.8.8',
  `dns2`           VARCHAR(45)  DEFAULT '8.8.4.4',
  `description`    VARCHAR(120) DEFAULT NULL,
  `status`         ENUM('active','inactive','error') DEFAULT 'active',
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY `uniq_vlan` (`vlan_id`,`interface_id`),
  FOREIGN KEY (`interface_id`) REFERENCES `interfaces`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dhcp_pools` (
  `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name`        VARCHAR(60)  NOT NULL,
  `vlan_id`     INT UNSIGNED DEFAULT NULL,
  `interface_id`INT UNSIGNED NOT NULL,
  `subnet`      VARCHAR(45)  NOT NULL,
  `range_start` VARCHAR(45)  NOT NULL,
  `range_end`   VARCHAR(45)  NOT NULL,
  `gateway`     VARCHAR(45)  NOT NULL,
  `dns1`        VARCHAR(45)  DEFAULT '8.8.8.8',
  `dns2`        VARCHAR(45)  DEFAULT '8.8.4.4',
  `lease_time`  INT UNSIGNED DEFAULT 86400,
  `domain_name` VARCHAR(120) DEFAULT NULL,
  `is_active`   TINYINT(1)   DEFAULT 1,
  `created_at`  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`interface_id`) REFERENCES `interfaces`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `dhcp_leases` (
  `id`          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `pool_id`     INT UNSIGNED NOT NULL,
  `ip_address`  VARCHAR(45) NOT NULL,
  `mac_address` VARCHAR(17) NOT NULL,
  `hostname`    VARCHAR(120) DEFAULT NULL,
  `is_reserved` TINYINT(1)  DEFAULT 0,
  `lease_start` DATETIME DEFAULT CURRENT_TIMESTAMP,
  `lease_end`   DATETIME DEFAULT NULL,
  `last_seen`   DATETIME DEFAULT NULL,
  FOREIGN KEY (`pool_id`) REFERENCES `dhcp_pools`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `static_routes` (
  `id`           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `destination`  VARCHAR(45)  NOT NULL,
  `prefix`       TINYINT UNSIGNED NOT NULL DEFAULT 24,
  `gateway`      VARCHAR(45)  NOT NULL,
  `interface_id` INT UNSIGNED DEFAULT NULL,
  `metric`       SMALLINT UNSIGNED DEFAULT 100,
  `description`  VARCHAR(120) DEFAULT NULL,
  `is_active`    TINYINT(1)  DEFAULT 1,
  `created_at`   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (`interface_id`) REFERENCES `interfaces`(`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `loadbalancer_config` (
  `id`                    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `algorithm`             ENUM('weighted_rr','least_conn','hash_src','bandwidth','failover') DEFAULT 'weighted_rr',
  `health_check_interval` SMALLINT UNSIGNED DEFAULT 30,
  `health_check_host`     VARCHAR(120) DEFAULT '8.8.8.8',
  `failover_threshold`    TINYINT UNSIGNED DEFAULT 3,
  `sticky_sessions`       TINYINT(1) DEFAULT 0,
  `updated_at`            DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT IGNORE INTO `loadbalancer_config` (`algorithm`) VALUES ('weighted_rr');

CREATE TABLE IF NOT EXISTS `traffic_stats` (
  `id`           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `interface_id` INT UNSIGNED NOT NULL,
  `recorded_at`  DATETIME NOT NULL,
  `bytes_in`     BIGINT UNSIGNED DEFAULT 0,
  `bytes_out`    BIGINT UNSIGNED DEFAULT 0,
  `packets_in`   BIGINT UNSIGNED DEFAULT 0,
  `packets_out`  BIGINT UNSIGNED DEFAULT 0,
  `errors_in`    INT UNSIGNED DEFAULT 0,
  `errors_out`   INT UNSIGNED DEFAULT 0,
  `latency_ms`   FLOAT DEFAULT NULL,
  KEY `idx_iface_time` (`interface_id`,`recorded_at`),
  FOREIGN KEY (`interface_id`) REFERENCES `interfaces`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `api_keys` (
  `id`             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name`           VARCHAR(60)  NOT NULL,
  `key_hash`       VARCHAR(255) NOT NULL UNIQUE,
  `key_prefix`     VARCHAR(12)  NOT NULL,
  `permissions`    SET('interfaces','vlans','pppoe','dhcp','routes','loadbalancer','stats','admin') NOT NULL DEFAULT 'interfaces,stats',
  `rate_limit`     SMALLINT UNSIGNED DEFAULT 100,
  `is_active`      TINYINT(1)  DEFAULT 1,
  `last_used`      DATETIME    DEFAULT NULL,
  `requests_count` INT UNSIGNED DEFAULT 0,
  `expires_at`     DATETIME    DEFAULT NULL,
  `created_by`     INT UNSIGNED DEFAULT NULL,
  `created_at`     DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `system_logs` (
  `id`         BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `level`      ENUM('info','warning','error','critical') DEFAULT 'info',
  `category`   VARCHAR(40) NOT NULL,
  `message`    TEXT NOT NULL,
  `context`    JSON DEFAULT NULL,
  `user_id`    INT UNSIGNED DEFAULT NULL,
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  KEY `idx_level_time` (`level`,`created_at`),
  KEY `idx_category`   (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `settings` (
  `skey`       VARCHAR(80) NOT NULL PRIMARY KEY,
  `value`      TEXT        DEFAULT NULL,
  `type`       ENUM('string','int','bool','json') DEFAULT 'string',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `settings` (`skey`,`value`,`type`) VALUES
  ('hostname',      'lb-pro-01',   'string'),
  ('timezone',      'Asia/Riyadh', 'string'),
  ('ntp_server',    'pool.ntp.org','string'),
  ('ping_interval', '30',          'int'),
  ('failover_auto', '1',           'bool'),
  ('alert_email',   '',            'string'),
  ('ipv6_enabled',  '0',           'bool'),
  ('snmp_enabled',  '1',           'bool'),
  ('auto_update',   '1',           'bool')
ON DUPLICATE KEY UPDATE `value` = VALUES(`value`);

INSERT IGNORE INTO `interfaces` (`name`,`display_name`,`type`,`weight`,`status`) VALUES
  ('eth0','WAN-1','pppoe', 4,'down'),
  ('eth1','WAN-2','dhcp',  2,'down'),
  ('eth2','WAN-3','static',8,'down');

SET foreign_key_checks = 1;
SCHEMA
ok "تم استيراد قاعدة البيانات بنجاح"

# ---- مستخدم admin ----
ADMIN_HASH=$(php${PHP_VER} -r "echo password_hash('${ADMIN_PASS}', PASSWORD_BCRYPT, ['cost'=>12]);")
mysql -u root "${DB_NAME}" << ADMINSQL
INSERT INTO users (username,password_hash,role,email,created_at)
VALUES ('admin','${ADMIN_HASH}','superadmin','admin@lbpro.local',NOW())
ON DUPLICATE KEY UPDATE password_hash='${ADMIN_HASH}';
ADMINSQL
ok "مستخدم admin"

# ============================================================
step "8/9 — Nginx"
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

    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    gzip on;
    gzip_types text/plain text/css application/json application/javascript;

    location /api/ {
        try_files \$uri \$uri/ /api/index.php?\$query_string;
        add_header 'Access-Control-Allow-Origin' '*' always;
        add_header 'Access-Control-Allow-Methods' 'GET,POST,PUT,DELETE,OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Authorization,Content-Type,X-API-Key' always;
        if (\$request_method = 'OPTIONS') { return 204; }
    }

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass   unix:/run/php/php${PHP_VER}-fpm.sock;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include        fastcgi_params;
        fastcgi_read_timeout 60;
    }

    location ~* \.(css|js|png|jpg|svg|ico|woff2)$ {
        expires 30d;
        add_header Cache-Control "public, immutable";
        try_files \$uri =404;
    }

    location ~ /(config|includes|cron|logs)/ { deny all; }
    location ~ /\. { deny all; }

    access_log /var/log/nginx/lbpro_access.log;
    error_log  /var/log/nginx/lbpro_error.log warn;
}
NGINX

ln -sf /etc/nginx/sites-available/lbpro /etc/nginx/sites-enabled/lbpro
rm -f /etc/nginx/sites-enabled/default
nginx -t && ok "Nginx config صحيح" || err "خطأ Nginx — راجع: sudo nginx -t"

# PHP-FPM tuning
PHP_INI="/etc/php/${PHP_VER}/fpm/php.ini"
[ -f "$PHP_INI" ] && {
  sed -i 's/^;*upload_max_filesize.*/upload_max_filesize = 50M/'  "$PHP_INI"
  sed -i 's/^;*post_max_size.*/post_max_size = 50M/'              "$PHP_INI"
  sed -i 's/^;*memory_limit.*/memory_limit = 256M/'               "$PHP_INI"
  sed -i 's/^;*max_execution_time.*/max_execution_time = 60/'     "$PHP_INI"
  sed -i 's|^;*date.timezone.*|date.timezone = Asia/Riyadh|'      "$PHP_INI"
  ok "PHP-FPM tuning"
}

# ============================================================
step "9/9 — صلاحيات + Cron + Kernel"
# ============================================================
chown -R www-data:www-data "${INSTALL_DIR}"
chmod -R 755 "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}/logs"
chmod 775 "${INSTALL_DIR}/logs"
chmod 600 "${INSTALL_DIR}/config/config.php"
ok "الصلاحيات"

cat > /etc/sudoers.d/lbpro << 'SUDO'
www-data ALL=(root) NOPASSWD: /sbin/ip, /sbin/ifconfig, /sbin/route, /usr/bin/pppd, /sbin/pppoe-start, /sbin/pppoe-stop, /bin/systemctl restart networking, /sbin/iptables, /sbin/iptables-save, /sbin/nft, /usr/sbin/dhcpd, /bin/kill
SUDO
chmod 0440 /etc/sudoers.d/lbpro
ok "sudoers"

(crontab -l -u www-data 2>/dev/null | grep -v lbpro; cat << CRON
* * * * * sleep 0  && /usr/bin/php${PHP_VER} ${INSTALL_DIR}/cron/monitor.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
* * * * * sleep 30 && /usr/bin/php${PHP_VER} ${INSTALL_DIR}/cron/monitor.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
0 0 * * * /usr/bin/php${PHP_VER} ${INSTALL_DIR}/cron/daily_stats.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
0 3 * * * /usr/bin/php${PHP_VER} ${INSTALL_DIR}/cron/cleanup.php >> ${INSTALL_DIR}/logs/cron.log 2>&1
CRON
) | crontab -u www-data -
ok "Cron Jobs"

cat > /etc/sysctl.d/99-lbpro.conf << 'SYSCTL'
net.ipv4.ip_forward = 1
net.ipv4.conf.all.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.tcp_window_scaling = 1
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
SYSCTL
sysctl -p /etc/sysctl.d/99-lbpro.conf > /dev/null 2>&1
modprobe 8021q 2>/dev/null || true
echo "8021q" >> /etc/modules-load.d/lbpro.conf
ok "Kernel + VLAN"

systemctl enable  nginx php${PHP_VER}-fpm mysql redis-server
systemctl restart nginx php${PHP_VER}-fpm mysql redis-server
ok "جميع الخدمات تعمل"

sleep 2
HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost/ 2>/dev/null || echo "000")
[[ "$HTTP" == "200" || "$HTTP" == "302" ]] \
  && STATUS="${GREEN}✔ يعمل (HTTP ${HTTP})${NC}" \
  || STATUS="${YELLOW}⚠ HTTP ${HTTP} — تحقق: tail -f /var/log/nginx/lbpro_error.log${NC}"

echo ""
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}${BOLD}  ✔  تم التثبيت بنجاح — LoadBalancer Pro v2.4.2${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  🌐 الرابط    : ${CYAN}http://${DOMAIN}${NC}"
echo -e "  👤 المستخدم  : ${BOLD}admin${NC}"
echo -e "  🔑 كلمة المرور: ${RED}${BOLD}${ADMIN_PASS}${NC}  ← احفظها!"
echo ""
echo -e "  🗄  MySQL    : ${DB_NAME} | ${DB_USER} | ${RED}${DB_PASS}${NC}"
echo -e "  🔧 PHP       : ${PHP_VER}-FPM"
echo -e "  📡 الموقع    : $(echo -e $STATUS)"
echo ""
echo -e "  📋 أوامر مفيدة:"
echo -e "     tail -f ${INSTALL_DIR}/logs/system.log"
echo -e "     tail -f /var/log/nginx/lbpro_error.log"
echo -e "     sudo systemctl status nginx php${PHP_VER}-fpm mysql"
echo ""
echo -e "  ${YELLOW}${BOLD}⚠  احفظ كلمات المرور في مكان آمن!${NC}"
echo -e "${GREEN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
