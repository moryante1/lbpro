<?php
// ============================================================
//  Cron — Daily Stats Aggregation
// ============================================================
define('LBPRO_ROOT', dirname(__DIR__));
require_once LBPRO_ROOT . '/config/config.php';
require_once LBPRO_ROOT . '/includes/Database.php';
require_once LBPRO_ROOT . '/includes/Logger.php';
require_once LBPRO_ROOT . '/includes/Auth.php';
require_once LBPRO_ROOT . '/includes/Network.php';

Logger::info('cron', 'daily_stats: running');
// Aggregate yesterday's traffic per interface
$yesterday = date('Y-m-d', strtotime('-1 day'));
$ifaces = Database::fetchAll("SELECT id, name FROM interfaces");
foreach ($ifaces as $iface) {
    $stats = Database::fetchOne(
        "SELECT SUM(bytes_in) total_in, SUM(bytes_out) total_out,
                AVG(latency_ms) avg_latency, COUNT(*) samples
         FROM traffic_stats
         WHERE interface_id=? AND DATE(recorded_at)=?",
        [$iface['id'], $yesterday]
    );
    if ($stats && $stats['samples'] > 0) {
        Logger::info('stats', sprintf(
            "%s %s: IN=%.2fGB OUT=%.2fGB latency=%.1fms",
            $yesterday, $iface['name'],
            $stats['total_in']/1073741824,
            $stats['total_out']/1073741824,
            $stats['avg_latency']
        ));
    }
}
Logger::info('cron', 'daily_stats: done');
