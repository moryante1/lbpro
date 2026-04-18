-- ============================================================
--  LoadBalancer Pro — Database Schema v2.4.1
--  Fixed: column renamed from `key` to `skey` (reserved word)
-- ============================================================

SET NAMES utf8mb4;
SET time_zone = '+00:00';
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
  `id`            INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name`          VARCHAR(30)  NOT NULL UNIQUE,
  `display_name`  VARCHAR(60)  DEFAULT NULL,
  `type`          ENUM('pppoe','dhcp','static') NOT NULL DEFAULT 'dhcp',
  `ip_address`    VARCHAR(45)  DEFAULT NULL,
  `subnet_mask`   VARCHAR(45)  DEFAULT '255.255.255.0',
  `gateway`       VARCHAR(45)  DEFAULT NULL,
  `dns1`          VARCHAR(45)  DEFAULT '8.8.8.8',
  `dns2`          VARCHAR(45)  DEFAULT '8.8.4.4',
  `mtu`           SMALLINT UNSIGNED DEFAULT 1500,
  `weight`        TINYINT UNSIGNED  DEFAULT 1,
  `metric`        SMALLINT UNSIGNED DEFAULT 100,
  `is_enabled`    TINYINT(1)   NOT NULL DEFAULT 1,
  `status`        ENUM('up','down','connecting','disabled') DEFAULT 'down',
  `speed_in`      BIGINT UNSIGNED  DEFAULT 0,
  `speed_out`     BIGINT UNSIGNED  DEFAULT 0,
  `last_seen`     DATETIME     DEFAULT NULL,
  `created_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
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
  `persist`           TINYINT(1)   DEFAULT 1,
  `maxfail`           TINYINT UNSIGNED  DEFAULT 0,
  `status`            ENUM('connected','disconnected','connecting','error') DEFAULT 'disconnected',
  `assigned_ip`       VARCHAR(45)  DEFAULT NULL,
  `server_ip`         VARCHAR(45)  DEFAULT NULL,
  `session_id`        VARCHAR(20)  DEFAULT NULL,
  `connected_at`      DATETIME     DEFAULT NULL,
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
  UNIQUE KEY `uniq_vlan` (`vlan_id`, `interface_id`),
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
  `is_reserved` TINYINT(1)   DEFAULT 0,
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
  `is_active`    TINYINT(1)   DEFAULT 1,
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

INSERT INTO `loadbalancer_config` (`algorithm`) VALUES ('weighted_rr');

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
  KEY `idx_iface_time` (`interface_id`, `recorded_at`),
  FOREIGN KEY (`interface_id`) REFERENCES `interfaces`(`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `api_keys` (
  `id`             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
  `name`           VARCHAR(60)  NOT NULL,
  `key_hash`       VARCHAR(255) NOT NULL UNIQUE,
  `key_prefix`     VARCHAR(12)  NOT NULL,
  `permissions`    SET('interfaces','vlans','pppoe','dhcp','routes','loadbalancer','stats','admin') NOT NULL DEFAULT 'interfaces,stats',
  `rate_limit`     SMALLINT UNSIGNED DEFAULT 100,
  `is_active`      TINYINT(1)   DEFAULT 1,
  `last_used`      DATETIME     DEFAULT NULL,
  `requests_count` INT UNSIGNED DEFAULT 0,
  `expires_at`     DATETIME     DEFAULT NULL,
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
  KEY `idx_level_time` (`level`, `created_at`),
  KEY `idx_category`   (`category`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- FIXED: renamed column from `key` to `skey` to avoid reserved word conflict
CREATE TABLE IF NOT EXISTS `settings` (
  `skey`       VARCHAR(80)  NOT NULL PRIMARY KEY,
  `value`      TEXT         DEFAULT NULL,
  `type`       ENUM('string','int','bool','json') DEFAULT 'string',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

INSERT INTO `settings` (`skey`, `value`, `type`) VALUES
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

INSERT IGNORE INTO `interfaces` (`name`, `display_name`, `type`, `weight`, `status`) VALUES
  ('eth0', 'WAN-1', 'pppoe',  4, 'down'),
  ('eth1', 'WAN-2', 'dhcp',   2, 'down'),
  ('eth2', 'WAN-3', 'static', 8, 'down');

SET foreign_key_checks = 1;
