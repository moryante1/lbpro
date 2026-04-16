<?php
// ============================================================
//  Auth — Session + JWT + API Key authentication
// ============================================================
class Auth {

    // ---- Web session login ----
    public static function login(string $username, string $password): bool {
        $user = Database::fetchOne(
            "SELECT * FROM users WHERE username = ? AND is_active = 1", [$username]);
        if (!$user || !password_verify($password, $user['password_hash'])) return false;

        Database::query("UPDATE users SET last_login=NOW() WHERE id=?", [$user['id']]);
        session_regenerate_id(true);
        $_SESSION['user_id']   = $user['id'];
        $_SESSION['username']  = $user['username'];
        $_SESSION['role']      = $user['role'];
        $_SESSION['login_at']  = time();
        Logger::info('auth', "Login: {$user['username']}");
        return true;
    }

    public static function logout(): void {
        Logger::info('auth', "Logout: " . ($_SESSION['username'] ?? '?'));
        session_destroy();
    }

    public static function check(): bool {
        if (!isset($_SESSION['user_id'])) return false;
        if ((time() - $_SESSION['login_at']) > SESSION_LIFETIME) {
            self::logout(); return false;
        }
        return true;
    }

    public static function requireLogin(): void {
        if (!self::check()) {
            header('Location: /login.php'); exit;
        }
    }

    public static function requireRole(string $role): void {
        self::requireLogin();
        $order = ['readonly' => 0, 'admin' => 1, 'superadmin' => 2];
        if (($order[$_SESSION['role']] ?? -1) < ($order[$role] ?? 99)) {
            http_response_code(403);
            die(json_encode(['error' => 'Forbidden']));
        }
    }

    // ---- API Key auth ----
    public static function checkApiKey(): ?array {
        $key = $_SERVER['HTTP_X_API_KEY']
            ?? ($_SERVER['HTTP_AUTHORIZATION'] ? str_replace('Bearer ', '', $_SERVER['HTTP_AUTHORIZATION']) : null);
        if (!$key) return null;

        $hash = hash('sha256', $key);
        $apiKey = Database::fetchOne(
            "SELECT * FROM api_keys WHERE key_hash=? AND is_active=1
             AND (expires_at IS NULL OR expires_at > NOW())", [$hash]);
        if (!$apiKey) return null;

        // Rate limiting via Redis
        $redis = new Redis();
        $redis->connect(REDIS_HOST, REDIS_PORT);
        $rlKey = "rl:{$apiKey['id']}:" . date('YmdHi');
        $count = $redis->incr($rlKey);
        $redis->expire($rlKey, 60);
        if ($count > ($apiKey['rate_limit'] ?? API_RATE_LIMIT)) {
            http_response_code(429);
            die(json_encode(['error' => 'Rate limit exceeded']));
        }

        Database::query("UPDATE api_keys SET last_used=NOW(), requests_count=requests_count+1 WHERE id=?",
            [$apiKey['id']]);
        return $apiKey;
    }

    // ---- Generate API key ----
    public static function generateApiKey(string $name, array $permissions, int $createdBy): array {
        $raw    = 'lbpro_' . bin2hex(random_bytes(24));
        $hash   = hash('sha256', $raw);
        $prefix = substr($raw, 0, 12);
        Database::insert('api_keys', [
            'name'        => $name,
            'key_hash'    => $hash,
            'key_prefix'  => $prefix,
            'permissions' => implode(',', $permissions),
            'created_by'  => $createdBy,
        ]);
        return ['key' => $raw, 'prefix' => $prefix];
    }

    public static function user(): array {
        return ['id' => $_SESSION['user_id'], 'username' => $_SESSION['username'], 'role' => $_SESSION['role']];
    }
}
