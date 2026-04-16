<?php
// ============================================================
//  Bootstrap — loaded by every page and API endpoint
// ============================================================
define('LBPRO_ROOT', dirname(__DIR__));
require_once LBPRO_ROOT . '/config/config.php';
require_once LBPRO_ROOT . '/includes/Database.php';
require_once LBPRO_ROOT . '/includes/Logger.php';
require_once LBPRO_ROOT . '/includes/Auth.php';
require_once LBPRO_ROOT . '/includes/Network.php';

// Session
if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.cookie_httponly', 1);
    ini_set('session.use_strict_mode', 1);
    session_name('LBPRO_SESS');
    session_start();
}

// Error handling
if (APP_ENV === 'production') {
    error_reporting(0);
    set_error_handler(function($errno, $errstr, $errfile, $errline) {
        Logger::error('php', "$errstr in $errfile:$errline");
        return true;
    });
    set_exception_handler(function(Throwable $e) {
        Logger::critical('php', $e->getMessage(), ['file' => $e->getFile(), 'line' => $e->getLine()]);
        if (!headers_sent()) Response::error('Internal server error', 500);
    });
} else {
    error_reporting(E_ALL);
}
