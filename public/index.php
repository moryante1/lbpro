<?php
require_once dirname(__DIR__) . '/includes/bootstrap.php';
Auth::requireLogin();
$user = Auth::user();
$page = preg_replace('/[^a-z_]/', '', $_GET['page'] ?? 'dashboard');
$validPages = ['dashboard','interfaces','vlans','pppoe','dhcp','static','loadbalancer','routing','api','logs','settings'];
if (!in_array($page, $validPages)) $page = 'dashboard';
?><!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LoadBalancer Pro</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+Arabic:wght@300;400;500;600&family=JetBrains+Mono:wght@400;600&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/css/app.css">
</head>
<body>

<!-- Topbar -->
<header class="topbar">
  <div class="logo">
    <div class="logo-icon">⚡</div>
    <span>LoadBalancer Pro</span>
    <span class="logo-ver">Ubuntu 22.04</span>
  </div>
  <div class="topbar-center">
    <div class="sys-stat" id="stat-up"><span class="dot green"></span><span id="stat-up-count">—</span> خطوط نشطة</div>
    <div class="sys-stat" id="stat-bw"><span class="dot blue"></span><span id="stat-bw-val">—</span> Gbps</div>
    <div class="sys-stat" id="stat-sess"><span class="dot purple"></span><span id="stat-sess-val">—</span> جلسات PPPoE</div>
  </div>
  <div class="topbar-right">
    <div class="topbar-user">
      <div class="avatar"><?= strtoupper(substr($user['username'], 0, 1)) ?></div>
      <div>
        <div class="uname"><?= htmlspecialchars($user['username']) ?></div>
        <div class="urole"><?= htmlspecialchars($user['role']) ?></div>
      </div>
    </div>
    <a href="/logout.php" class="btn btn-sm">خروج</a>
  </div>
</header>

<!-- Body -->
<div class="body-wrap">

<!-- Sidebar -->
<nav class="sidebar">
  <?php
  $nav = [
    'الرئيسية' => [
      ['dashboard',    '📊', 'لوحة التحكم'],
      ['interfaces',   '🔌', 'الواجهات'],
      ['vlans',        '🌐', 'VLANs'],
    ],
    'الاتصالات' => [
      ['pppoe',        '🔗', 'PPPoE'],
      ['dhcp',         '📡', 'DHCP Server'],
      ['static',       '📌', 'Static IP'],
    ],
    'الموازنة' => [
      ['loadbalancer', '⚖️', 'Load Balancer'],
      ['routing',      '🗺️', 'Routing'],
    ],
    'الإدارة' => [
      ['api',          '🔑', 'API Manager'],
      ['logs',         '📋', 'السجلات'],
      ['settings',     '⚙️', 'الإعدادات'],
    ],
  ];
  foreach ($nav as $section => $items): ?>
  <div class="nav-section">
    <div class="nav-label"><?= $section ?></div>
    <?php foreach ($items as [$p, $icon, $label]): ?>
    <a href="/?page=<?= $p ?>" class="nav-item<?= $page === $p ? ' active' : '' ?>">
      <span class="nav-icon"><?= $icon ?></span><?= $label ?>
    </a>
    <?php endforeach; ?>
  </div>
  <?php endforeach; ?>
</nav>

<!-- Main -->
<main class="main-content">
  <?php
  $tpl = __DIR__ . "/pages/{$page}.php";
  if (file_exists($tpl)) include $tpl;
  else echo "<div class='page-wrap'><p>الصفحة غير موجودة</p></div>";
  ?>
</main>

</div><!-- /body-wrap -->

<script src="/assets/js/app.js"></script>
</body>
</html>
