<?php
// ============================================================
//  Cron — Network Monitor (runs every 30 seconds)
// ============================================================
define('LBPRO_ROOT', dirname(__DIR__));
require_once LBPRO_ROOT . '/config/config.php';
require_once LBPRO_ROOT . '/includes/Database.php';
require_once LBPRO_ROOT . '/includes/Logger.php';
require_once LBPRO_ROOT . '/includes/Auth.php';
require_once LBPRO_ROOT . '/includes/Network.php';

// Prevent concurrent runs
$lockFile = '/tmp/lbpro_monitor.lock';
if (file_exists($lockFile) && (time() - filemtime($lockFile)) < 25) exit(0);
touch($lockFile);

try {
    Network::monitorAll();
} catch (Throwable $e) {
    Logger::error('cron', 'monitor.php: ' . $e->getMessage());
}

unlink($lockFile);
