<?php
// ============================================================
//  LoadBalancer Pro — REST API Router
//  Base URL: /api/v1/
// ============================================================
require_once dirname(__DIR__) . '/includes/bootstrap.php';

header('Content-Type: application/json; charset=UTF-8');

// Parse request
$method = $_SERVER['REQUEST_METHOD'];
$uri    = parse_url($_SERVER['REQUEST_URI'], PHP_URL_PATH);
$uri    = str_replace('/api/v1', '', $uri);
$uri    = rtrim($uri, '/') ?: '/';
$body   = json_decode(file_get_contents('php://input'), true) ?? [];

// Authenticate (API key OR active session)
$apiKey = Auth::checkApiKey();
if (!$apiKey && !Auth::check()) Response::unauthorized();

// Helpers
function seg(int $n): string|false {
    global $uri;
    $parts = array_filter(explode('/', $uri));
    $parts = array_values($parts);
    return $parts[$n] ?? false;
}
function intSeg(int $n): ?int {
    $v = seg($n); return is_numeric($v) ? (int)$v : null;
}

// ============================================================
//  ROUTES
// ============================================================

// ---- GET /status ----
if ($method === 'GET' && $uri === '/status') {
    Response::ok([
        'app'     => APP_NAME,
        'version' => APP_VERSION,
        'uptime'  => shell_exec('uptime -p'),
        'time'    => date('c'),
    ]);
}

// ---- /interfaces ----
if (str_starts_with($uri, '/interfaces')) {
    $id = intSeg(1);
    if ($method === 'GET' && !$id) Response::ok(Network::getInterfaces());
    if ($method === 'GET' &&  $id) {
        $r = Network::getInterface($id);
        $r ? Response::ok($r) : Response::notFound();
    }
    if ($method === 'POST') {
        $required = ['name', 'type'];
        foreach ($required as $f) if (empty($body[$f])) Response::error("$f required");
        $newId = Database::insert('interfaces', array_intersect_key($body, array_flip(
            ['name','display_name','type','ip_address','subnet_mask','gateway','dns1','dns2','mtu','weight','metric']
        )));
        if ($body['type'] === 'dhcp') Network::applyDhcp($body['name']);
        if ($body['type'] === 'static') Network::applyStaticIp($body);
        Response::created(['id' => $newId]);
    }
    if ($method === 'PUT' && $id) {
        Database::update('interfaces', array_intersect_key($body, array_flip(
            ['display_name','type','ip_address','subnet_mask','gateway','dns1','dns2','mtu','weight','metric','is_enabled']
        )), 'id=?', [$id]);
        Response::ok();
    }
    if ($method === 'DELETE' && $id) {
        Database::delete('interfaces', 'id=?', [$id]);
        Response::ok(null, 'Deleted');
    }
}

// ---- /vlans ----
if (str_starts_with($uri, '/vlans')) {
    $id = intSeg(1);
    if ($method === 'GET' && !$id)
        Response::ok(Database::fetchAll("SELECT v.*, i.name AS iface_name FROM vlans v JOIN interfaces i ON i.id=v.interface_id ORDER BY v.vlan_id"));
    if ($method === 'GET' && $id) {
        $r = Database::fetchOne("SELECT * FROM vlans WHERE id=?", [$id]);
        $r ? Response::ok($r) : Response::notFound();
    }
    if ($method === 'POST') {
        foreach (['vlan_id','name','interface_id','ip_address','subnet'] as $f)
            if (empty($body[$f])) Response::error("$f required");
        $result = Network::createVlan($body);
        $result['ok'] ? Response::created($result) : Response::error($result['error'] ?? 'Error');
    }
    if ($method === 'DELETE' && $id) {
        Network::deleteVlan($id);
        Response::ok(null, 'Deleted');
    }
}

// ---- /pppoe ----
if (str_starts_with($uri, '/pppoe')) {
    $id     = intSeg(1);
    $action = seg(2);
    if ($method === 'GET' && !$id)
        Response::ok(Database::fetchAll("SELECT p.*, i.name AS iface FROM pppoe_connections p JOIN interfaces i ON i.id=p.interface_id"));
    if ($method === 'POST' && !$id) {
        foreach (['interface_id','username','password'] as $f)
            if (empty($body[$f])) Response::error("$f required");
        $body['password'] = Network::encryptPassword($body['password']);
        $newId = Database::insert('pppoe_connections', array_intersect_key($body, array_flip(
            ['interface_id','username','password','service_name','mtu','mru','lcp_echo_interval','lcp_echo_failure','persist']
        )));
        Response::created(['id' => $newId]);
    }
    if ($method === 'POST' && $id && $action === 'connect')    Response::ok(Network::pppoeConnect($id));
    if ($method === 'POST' && $id && $action === 'disconnect') Response::ok(['ok' => Network::pppoeDisconnect($id)]);
    if ($method === 'DELETE' && $id) {
        Network::pppoeDisconnect($id);
        Database::delete('pppoe_connections', 'id=?', [$id]);
        Response::ok(null, 'Deleted');
    }
}

// ---- /dhcp ----
if (str_starts_with($uri, '/dhcp')) {
    $id = intSeg(1);
    if ($method === 'GET' && !$id)
        Response::ok(Database::fetchAll("SELECT * FROM dhcp_pools"));
    if ($method === 'POST') {
        foreach (['name','interface_id','subnet','range_start','range_end','gateway'] as $f)
            if (empty($body[$f])) Response::error("$f required");
        $newId = Database::insert('dhcp_pools', array_intersect_key($body, array_flip(
            ['name','vlan_id','interface_id','subnet','range_start','range_end','gateway','dns1','dns2','lease_time']
        )));
        Network::writeDhcpConfig();
        Response::created(['id' => $newId]);
    }
    if ($method === 'DELETE' && $id) {
        Database::delete('dhcp_pools', 'id=?', [$id]);
        Network::writeDhcpConfig();
        Response::ok(null, 'Deleted');
    }
    // Leases
    if ($method === 'GET' && seg(1) === 'leases')
        Response::ok(Database::fetchAll("SELECT * FROM dhcp_leases ORDER BY last_seen DESC LIMIT 200"));
}

// ---- /routes ----
if (str_starts_with($uri, '/routes')) {
    $id = intSeg(1);
    if ($method === 'GET')
        Response::ok(Database::fetchAll("SELECT r.*, i.name AS iface FROM static_routes r LEFT JOIN interfaces i ON i.id=r.interface_id"));
    if ($method === 'POST') {
        foreach (['destination','prefix','gateway'] as $f)
            if (!isset($body[$f])) Response::error("$f required");
        $ok = Network::applyRoute($body);
        if ($ok) { $newId = Database::insert('static_routes', $body); Response::created(['id' => $newId]); }
        else Response::error('Failed to apply route');
    }
    if ($method === 'DELETE' && $id) {
        Network::deleteRoute($id);
        Response::ok(null, 'Deleted');
    }
}

// ---- /loadbalancer ----
if (str_starts_with($uri, '/loadbalancer')) {
    $sub = seg(1);
    if ($method === 'GET' && !$sub)
        Response::ok(Database::fetchOne("SELECT * FROM loadbalancer_config LIMIT 1"));
    if ($method === 'PUT' && $sub === 'config') {
        Database::update('loadbalancer_config', array_intersect_key($body, array_flip(
            ['algorithm','health_check_interval','health_check_host','failover_threshold','sticky_sessions']
        )), 'id=1');
        Network::applyLoadBalancer();
        Response::ok();
    }
    if ($method === 'PUT' && $sub === 'weights') {
        foreach (($body['weights'] ?? []) as $ifaceId => $weight) {
            Database::update('interfaces', ['weight' => (int)$weight], 'id=?', [(int)$ifaceId]);
        }
        Network::applyLoadBalancer();
        Response::ok();
    }
    if ($method === 'POST' && $sub === 'apply') {
        $ok = Network::applyLoadBalancer();
        Response::ok(['applied' => $ok]);
    }
}

// ---- /stats ----
if (str_starts_with($uri, '/stats')) {
    $sub = seg(1);
    if ($sub === 'realtime') {
        $data = [];
        foreach (Network::getInterfaces() as $iface) {
            $data[] = ['name' => $iface['name'], 'status' => $iface['status'], 'stats' => $iface['stats']];
        }
        Response::ok($data);
    }
    if ($sub === 'traffic') {
        $ifaceId = $_GET['interface_id'] ?? null;
        $hours   = (int) ($_GET['hours'] ?? 24);
        $sql  = "SELECT * FROM traffic_stats WHERE recorded_at >= NOW() - INTERVAL ? HOUR";
        $params = [$hours];
        if ($ifaceId) { $sql .= " AND interface_id=?"; $params[] = $ifaceId; }
        $sql .= " ORDER BY recorded_at DESC LIMIT 1000";
        Response::ok(Database::fetchAll($sql, $params));
    }
    if ($sub === 'summary') {
        Response::ok([
            'interfaces_up'   => (int) Database::fetchOne("SELECT COUNT(*) c FROM interfaces WHERE status='up'")['c'],
            'interfaces_total'=> (int) Database::fetchOne("SELECT COUNT(*) c FROM interfaces")['c'],
            'pppoe_sessions'  => (int) Database::fetchOne("SELECT COUNT(*) c FROM pppoe_connections WHERE status='connected'")['c'],
            'vlan_count'      => (int) Database::fetchOne("SELECT COUNT(*) c FROM vlans WHERE status='active'")['c'],
            'dhcp_leases'     => (int) Database::fetchOne("SELECT COUNT(*) c FROM dhcp_leases WHERE lease_end > NOW()")['c'],
        ]);
    }
}

// ---- /logs ----
if (str_starts_with($uri, '/logs')) {
    if ($method === 'GET') {
        $level  = $_GET['level']  ?? null;
        $limit  = (int)($_GET['limit'] ?? 100);
        $sql    = "SELECT * FROM system_logs";
        $params = [];
        if ($level) { $sql .= " WHERE level=?"; $params[] = $level; }
        $sql .= " ORDER BY created_at DESC LIMIT ?";
        $params[] = $limit;
        Response::ok(Database::fetchAll($sql, $params));
    }
}

// ---- /api-keys ----
if (str_starts_with($uri, '/api-keys')) {
    $id = intSeg(1);
    if ($method === 'GET')
        Response::ok(Database::fetchAll("SELECT id,name,key_prefix,permissions,rate_limit,is_active,last_used,requests_count,expires_at,created_at FROM api_keys ORDER BY created_at DESC"));
    if ($method === 'POST') {
        if (empty($body['name'])) Response::error('name required');
        $perms = $body['permissions'] ?? ['interfaces','stats'];
        $user  = Auth::user();
        $result = Auth::generateApiKey($body['name'], $perms, $user['id']);
        Response::created($result);
    }
    if ($method === 'PUT' && $id) {
        Database::update('api_keys', ['is_active' => (int)$body['is_active']], 'id=?', [$id]);
        Response::ok();
    }
    if ($method === 'DELETE' && $id) {
        Database::delete('api_keys', 'id=?', [$id]);
        Response::ok(null, 'Revoked');
    }
}

// ---- /settings ----
if (str_starts_with($uri, '/settings')) {
    if ($method === 'GET')
        Response::ok(Database::fetchAll("SELECT * FROM settings ORDER BY `key`"));
    if ($method === 'PUT') {
        foreach (($body ?? []) as $key => $value) {
            Database::query("INSERT INTO settings (`key`,`value`) VALUES (?,?) ON DUPLICATE KEY UPDATE `value`=?",
                [$key, $value, $value]);
        }
        Response::ok();
    }
}

// 404
Response::notFound("Route not found: $method $uri");
