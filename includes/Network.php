<?php
// ============================================================
//  Network — Interface, VLAN, PPPoE, Route, LB operations
// ============================================================
class Network {

    // ============================================================
    // Interface helpers
    // ============================================================
    public static function getInterfaces(): array {
        $rows = Database::fetchAll("SELECT * FROM interfaces ORDER BY name");
        foreach ($rows as &$r) {
            $r['stats'] = self::readIfaceStats($r['name']);
        }
        return $rows;
    }

    public static function getInterface(int $id): ?array {
        return Database::fetchOne("SELECT * FROM interfaces WHERE id=?", [$id]);
    }

    public static function readIfaceStats(string $iface): array {
        $path = "/sys/class/net/{$iface}/statistics/";
        return [
            'rx_bytes'   => @file_get_contents("{$path}rx_bytes")   ?? 0,
            'tx_bytes'   => @file_get_contents("{$path}tx_bytes")   ?? 0,
            'rx_packets' => @file_get_contents("{$path}rx_packets") ?? 0,
            'tx_packets' => @file_get_contents("{$path}tx_packets") ?? 0,
            'rx_errors'  => @file_get_contents("{$path}rx_errors")  ?? 0,
            'tx_errors'  => @file_get_contents("{$path}tx_errors")  ?? 0,
        ];
    }

    public static function getIfaceStatus(string $iface): string {
        $operstate = @trim(file_get_contents("/sys/class/net/{$iface}/operstate")) ?: 'unknown';
        return ($operstate === 'up') ? 'up' : 'down';
    }

    public static function applyStaticIp(array $cfg): bool {
        $cmds = [
            "sudo ip addr flush dev {$cfg['name']}",
            "sudo ip addr add {$cfg['ip_address']}/{$cfg['prefix']} dev {$cfg['name']}",
            "sudo ip link set {$cfg['name']} up",
        ];
        if (!empty($cfg['gateway'])) {
            $cmds[] = "sudo ip route replace default via {$cfg['gateway']} dev {$cfg['name']} metric {$cfg['metric']}";
        }
        return self::runAll($cmds);
    }

    public static function applyDhcp(string $iface): bool {
        return self::run("sudo dhclient -v {$iface} > /tmp/dhclient_{$iface}.log 2>&1 &");
    }

    // ============================================================
    // PPPoE
    // ============================================================
    public static function pppoeConnect(int $connId): array {
        $conn = Database::fetchOne(
            "SELECT p.*, i.name AS iface FROM pppoe_connections p
             JOIN interfaces i ON i.id=p.interface_id WHERE p.id=?", [$connId]);
        if (!$conn) return ['ok' => false, 'error' => 'Connection not found'];

        $pass = self::decryptPassword($conn['password']);
        $peerFile = "/etc/ppp/peers/lbpro_{$conn['iface']}";

        // Write pppd peer file
        $content = "plugin rp-pppoe.so {$conn['iface']}\n"
            . "user \"{$conn['username']}\"\n"
            . "password \"{$pass}\"\n"
            . ($conn['service_name'] ? "rp_pppoe_service \"{$conn['service_name']}\"\n" : "")
            . "mtu {$conn['mtu']}\nmru {$conn['mru']}\n"
            . "persist\nmaxfail {$conn['maxfail']}\n"
            . "lcp-echo-interval {$conn['lcp_echo_interval']}\n"
            . "lcp-echo-failure {$conn['lcp_echo_failure']}\n"
            . "defaultroute\nusepeerdns\nnoauth\nhide-password\n";

        if (file_put_contents($peerFile, $content) === false)
            return ['ok' => false, 'error' => 'Cannot write peer file'];

        $ok = self::run("sudo pppd call lbpro_{$conn['iface']} &");
        if ($ok) {
            Database::update('pppoe_connections', ['status' => 'connecting'], 'id=?', [$connId]);
            Logger::info('pppoe', "Connecting {$conn['iface']} as {$conn['username']}");
        }
        return ['ok' => $ok];
    }

    public static function pppoeDisconnect(int $connId): bool {
        $conn = Database::fetchOne("SELECT i.name AS iface FROM pppoe_connections p
            JOIN interfaces i ON i.id=p.interface_id WHERE p.id=?", [$connId]);
        if (!$conn) return false;
        $ok = self::run("sudo kill \$(cat /var/run/ppp-{$conn['iface']}.pid 2>/dev/null) 2>/dev/null; true");
        Database::update('pppoe_connections', ['status' => 'disconnected', 'assigned_ip' => null], 'id=?', [$connId]);
        return $ok;
    }

    // ============================================================
    // VLANs
    // ============================================================
    public static function createVlan(array $cfg): array {
        $iface = Database::fetchOne("SELECT name FROM interfaces WHERE id=?", [$cfg['interface_id']]);
        if (!$iface) return ['ok' => false, 'error' => 'Interface not found'];

        $vlanIface = "{$iface['name']}.{$cfg['vlan_id']}";
        $cmds = [
            "sudo ip link add link {$iface['name']} name {$vlanIface} type vlan id {$cfg['vlan_id']}",
            "sudo ip addr add {$cfg['ip_address']}/{$cfg['subnet']} dev {$vlanIface}",
            "sudo ip link set {$vlanIface} up",
        ];
        $ok = self::runAll($cmds);

        if ($ok) {
            $cfg['vlan_interface'] = $vlanIface;
            $id = Database::insert('vlans', $cfg);
            Logger::info('vlan', "Created VLAN {$cfg['vlan_id']} on {$vlanIface}");
            return ['ok' => true, 'id' => $id, 'vlan_interface' => $vlanIface];
        }
        return ['ok' => false, 'error' => 'Failed to apply VLAN'];
    }

    public static function deleteVlan(int $vlanId): bool {
        $vlan = Database::fetchOne("SELECT * FROM vlans WHERE id=?", [$vlanId]);
        if (!$vlan) return false;
        self::run("sudo ip link set {$vlan['vlan_interface']} down");
        self::run("sudo ip link delete {$vlan['vlan_interface']}");
        Database::delete('vlans', 'id=?', [$vlanId]);
        return true;
    }

    // ============================================================
    // DHCP Server (ISC DHCP)
    // ============================================================
    public static function writeDhcpConfig(): bool {
        $pools = Database::fetchAll(
            "SELECT p.*, v.vlan_interface FROM dhcp_pools p
             LEFT JOIN vlans v ON v.id=p.vlan_id WHERE p.is_active=1");

        $conf = "# LoadBalancer Pro — auto-generated DHCP config\n"
              . "ddns-update-style none;\ndefault-lease-time 86400;\nmax-lease-time 172800;\n\n";

        foreach ($pools as $pool) {
            $network = long2ip(ip2long($pool['subnet']) & ip2long('255.255.255.0'));
            $conf .= "subnet {$network} netmask 255.255.255.0 {\n"
                   . "  range {$pool['range_start']} {$pool['range_end']};\n"
                   . "  option routers {$pool['gateway']};\n"
                   . "  option domain-name-servers {$pool['dns1']}, {$pool['dns2']};\n"
                   . "  default-lease-time {$pool['lease_time']};\n"
                   . "}\n\n";
        }

        // Reserved leases
        $reserved = Database::fetchAll("SELECT * FROM dhcp_leases WHERE is_reserved=1");
        foreach ($reserved as $r) {
            $conf .= "host reserved_{$r['id']} {\n"
                   . "  hardware ethernet {$r['mac_address']};\n"
                   . "  fixed-address {$r['ip_address']};\n}\n";
        }

        file_put_contents('/etc/dhcp/dhcpd.conf', $conf);
        return self::run("sudo systemctl restart isc-dhcp-server");
    }

    // ============================================================
    // Static Routes
    // ============================================================
    public static function applyRoute(array $route): bool {
        $cmd = "sudo ip route replace {$route['destination']}/{$route['prefix']} via {$route['gateway']}";
        if (!empty($route['interface'])) $cmd .= " dev {$route['interface']}";
        if (!empty($route['metric']))    $cmd .= " metric {$route['metric']}";
        return self::run($cmd);
    }

    public static function deleteRoute(int $routeId): bool {
        $r = Database::fetchOne("SELECT s.*, i.name AS iface FROM static_routes s
            LEFT JOIN interfaces i ON i.id=s.interface_id WHERE s.id=?", [$routeId]);
        if (!$r) return false;
        $cmd = "sudo ip route del {$r['destination']}/{$r['prefix']}";
        if ($r['iface']) $cmd .= " dev {$r['iface']}";
        self::run($cmd);
        Database::delete('static_routes', 'id=?', [$routeId]);
        return true;
    }

    // ============================================================
    // Load Balancer — iptables ECMP / weighted routing
    // ============================================================
    public static function applyLoadBalancer(): bool {
        $cfg    = Database::fetchOne("SELECT * FROM loadbalancer_config LIMIT 1");
        $ifaces = Database::fetchAll("SELECT * FROM interfaces WHERE status='up' AND is_enabled=1 ORDER BY weight DESC");

        if (empty($ifaces)) return false;

        // Flush existing LB rules
        self::run("sudo iptables -t mangle -F PREROUTING");
        self::run("sudo ip route flush table 100 2>/dev/null; true");
        self::run("sudo ip route flush table 101 2>/dev/null; true");

        foreach ($ifaces as $idx => $iface) {
            $table = 100 + $idx;
            if (!$iface['gateway'] || !$iface['ip_address']) continue;
            self::run("sudo ip route add default via {$iface['gateway']} dev {$iface['name']} table {$table}");
            self::run("sudo ip rule add from {$iface['ip_address']}/32 table {$table} pref " . (100 + $idx));
        }

        // ECMP nexthops
        if (count($ifaces) > 1) {
            $nexthops = '';
            foreach ($ifaces as $iface) {
                if (!$iface['gateway']) continue;
                $nexthops .= " nexthop via {$iface['gateway']} dev {$iface['name']} weight {$iface['weight']}";
            }
            if ($nexthops) {
                self::run("sudo ip route replace default proto static scope global {$nexthops}");
            }
        }

        // Save iptables
        self::run("sudo iptables-save > /etc/iptables/rules.v4");
        Logger::info('loadbalancer', "Applied LB: {$cfg['algorithm']} with " . count($ifaces) . " interfaces");
        return true;
    }

    // ============================================================
    // Health check / ping
    // ============================================================
    public static function pingCheck(string $host, int $count = 3): array {
        $output = shell_exec("ping -c {$count} -W 2 " . escapeshellarg($host) . " 2>&1");
        preg_match('/(\d+)% packet loss/', $output ?? '', $loss);
        preg_match('/rtt min\/avg\/max.*= [\d.]+\/([\d.]+)/', $output ?? '', $rtt);
        return [
            'reachable' => ($loss[1] ?? 100) < 100,
            'loss'      => (int) ($loss[1] ?? 100),
            'latency'   => (float) ($rtt[1] ?? 0),
        ];
    }

    public static function monitorAll(): void {
        $ifaces = Database::fetchAll("SELECT * FROM interfaces WHERE is_enabled=1");
        $lbCfg  = Database::fetchOne("SELECT health_check_host, failover_threshold FROM loadbalancer_config LIMIT 1");
        $changed = false;

        foreach ($ifaces as $iface) {
            $check  = self::pingCheck($lbCfg['health_check_host'] ?? '8.8.8.8');
            $newStatus = $check['reachable'] ? 'up' : 'down';
            $oldStatus = $iface['status'];

            if ($newStatus !== $oldStatus) {
                Database::update('interfaces', [
                    'status'   => $newStatus,
                    'last_seen'=> $check['reachable'] ? date('Y-m-d H:i:s') : null,
                ], 'id=?', [$iface['id']]);
                Logger::info('monitor', "Interface {$iface['name']}: {$oldStatus} → {$newStatus}");
                $changed = true;
            }

            // Record traffic stats
            $stats = self::readIfaceStats($iface['name']);
            Database::insert('traffic_stats', [
                'interface_id' => $iface['id'],
                'recorded_at'  => date('Y-m-d H:i:s'),
                'bytes_in'     => (int) $stats['rx_bytes'],
                'bytes_out'    => (int) $stats['tx_bytes'],
                'packets_in'   => (int) $stats['rx_packets'],
                'packets_out'  => (int) $stats['tx_packets'],
                'errors_in'    => (int) $stats['rx_errors'],
                'latency_ms'   => $check['latency'],
            ]);
        }

        if ($changed) self::applyLoadBalancer();
    }

    // ============================================================
    // Utilities
    // ============================================================
    private static function run(string $cmd): bool {
        exec($cmd . ' 2>/tmp/lbpro_cmd_err', $out, $code);
        if ($code !== 0) {
            Logger::warning('network', "CMD failed: $cmd | " . trim(@file_get_contents('/tmp/lbpro_cmd_err')));
        }
        return $code === 0;
    }

    private static function runAll(array $cmds): bool {
        foreach ($cmds as $cmd) {
            if (!self::run($cmd)) return false;
        }
        return true;
    }

    public static function encryptPassword(string $pass): string {
        return base64_encode(openssl_encrypt($pass, 'AES-256-CBC', JWT_SECRET, 0,
            substr(JWT_SECRET, 0, 16)));
    }

    public static function decryptPassword(string $enc): string {
        return openssl_decrypt(base64_decode($enc), 'AES-256-CBC', JWT_SECRET, 0,
            substr(JWT_SECRET, 0, 16)) ?: '';
    }
}
