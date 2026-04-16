<?php
// ============================================================
//  Logger
// ============================================================
class Logger {
    public static function log(string $level, string $category, string $message, array $ctx = []): void {
        Database::insert('system_logs', [
            'level'      => $level,
            'category'   => $category,
            'message'    => $message,
            'context'    => $ctx ? json_encode($ctx) : null,
            'user_id'    => $_SESSION['user_id'] ?? null,
            'ip_address' => $_SERVER['REMOTE_ADDR'] ?? null,
        ]);
        // Also write to file
        $line = sprintf("[%s] [%s] [%s] %s\n", date('Y-m-d H:i:s'), strtoupper($level), $category, $message);
        @file_put_contents(LOG_PATH . '/system.log', $line, FILE_APPEND | LOCK_EX);
    }
    public static function info(string $cat, string $msg, array $ctx = []): void    { self::log('info',     $cat, $msg, $ctx); }
    public static function warning(string $cat, string $msg, array $ctx = []): void { self::log('warning',  $cat, $msg, $ctx); }
    public static function error(string $cat, string $msg, array $ctx = []): void   { self::log('error',    $cat, $msg, $ctx); }
    public static function critical(string $cat, string $msg, array $ctx = []): void{ self::log('critical', $cat, $msg, $ctx); }
}

// ============================================================
//  API Response helper
// ============================================================
class Response {
    public static function json(mixed $data, int $code = 200): void {
        http_response_code($code);
        header('Content-Type: application/json; charset=UTF-8');
        echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }
    public static function ok(mixed $data = null, string $message = 'OK'): void {
        self::json(['success' => true, 'message' => $message, 'data' => $data]);
    }
    public static function created(mixed $data = null): void {
        self::json(['success' => true, 'data' => $data], 201);
    }
    public static function error(string $message, int $code = 400, mixed $errors = null): void {
        self::json(['success' => false, 'message' => $message, 'errors' => $errors], $code);
    }
    public static function notFound(string $message = 'Not found'): void {
        self::error($message, 404);
    }
    public static function unauthorized(): void {
        self::error('Unauthorized', 401);
    }
    public static function forbidden(): void {
        self::error('Forbidden', 403);
    }
}
