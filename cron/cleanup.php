<?php
// ============================================================
//  Cron — Cleanup old records
// ============================================================
define('LBPRO_ROOT', dirname(__DIR__));
require_once LBPRO_ROOT . '/config/config.php';
require_once LBPRO_ROOT . '/includes/Database.php';
require_once LBPRO_ROOT . '/includes/Logger.php';
require_once LBPRO_ROOT . '/includes/Auth.php';
require_once LBPRO_ROOT . '/includes/Network.php';

// Delete traffic stats older than 30 days
$r1 = Database::query("DELETE FROM traffic_stats WHERE recorded_at < NOW() - INTERVAL 30 DAY")->rowCount();
// Delete system logs older than 90 days
$r2 = Database::query("DELETE FROM system_logs WHERE created_at < NOW() - INTERVAL 90 DAY")->rowCount();
// Delete expired DHCP leases
$r3 = Database::query("DELETE FROM dhcp_leases WHERE is_reserved=0 AND lease_end < NOW() - INTERVAL 7 DAY")->rowCount();

Logger::info('cron', "cleanup: traffic_stats={$r1}, logs={$r2}, dhcp_leases={$r3}");
