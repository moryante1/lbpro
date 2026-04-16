<?php
require_once dirname(__DIR__) . '/includes/bootstrap.php';
if (Auth::check()) { header('Location: /'); exit; }

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $csrf = $_POST['csrf'] ?? '';
    if (!hash_equals($_SESSION['csrf'] ?? '', $csrf)) { $error = 'طلب غير صالح'; }
    elseif (Auth::login(trim($_POST['username'] ?? ''), $_POST['password'] ?? '')) {
        header('Location: /'); exit;
    } else { $error = 'اسم المستخدم أو كلمة المرور غير صحيحة'; }
}
$_SESSION['csrf'] = bin2hex(random_bytes(16));
?><!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>تسجيل الدخول — LoadBalancer Pro</title>
<link rel="stylesheet" href="/assets/css/app.css">
<style>
body{background:#0d0f14;display:flex;align-items:center;justify-content:center;min-height:100vh;font-family:'IBM Plex Sans Arabic',sans-serif}
.login-box{background:#13161e;border:1px solid #2a3045;border-radius:16px;padding:40px;width:380px;max-width:95vw}
.logo{text-align:center;margin-bottom:32px}
.logo-icon{width:52px;height:52px;background:linear-gradient(135deg,#3b82f6,#06b6d4);border-radius:14px;display:flex;align-items:center;justify-content:center;font-size:26px;margin:0 auto 14px}
h1{font-size:20px;font-weight:600;color:#e2e8f0;text-align:center;margin:0}
.sub{color:#64748b;font-size:12px;text-align:center;margin-top:5px}
.form-group{margin-bottom:16px}
label{display:block;font-size:12px;font-weight:500;color:#94a3b8;margin-bottom:5px}
input{width:100%;background:#1a1e28;border:1px solid #2a3045;border-radius:8px;padding:10px 14px;color:#e2e8f0;font-size:14px;font-family:inherit;outline:none;box-sizing:border-box;transition:border .2s}
input:focus{border-color:#3b82f6}
.btn{width:100%;background:#3b82f6;border:none;border-radius:8px;padding:11px;color:#fff;font-size:14px;font-weight:500;cursor:pointer;font-family:inherit;transition:background .15s}
.btn:hover{background:#1d4ed8}
.error{background:rgba(239,68,68,.12);border:1px solid rgba(239,68,68,.3);color:#ef4444;border-radius:8px;padding:10px 14px;font-size:12px;margin-bottom:16px}
.ver{color:#3d4a6a;font-size:10px;text-align:center;margin-top:20px}
</style>
</head>
<body>
<div class="login-box">
  <div class="logo">
    <div class="logo-icon">⚡</div>
    <h1>LoadBalancer Pro</h1>
    <p class="sub">Ubuntu 22.04 LTS — Network Management</p>
  </div>
  <?php if ($error): ?><div class="error"><?= htmlspecialchars($error) ?></div><?php endif; ?>
  <form method="POST">
    <input type="hidden" name="csrf" value="<?= htmlspecialchars($_SESSION['csrf']) ?>">
    <div class="form-group">
      <label>اسم المستخدم</label>
      <input type="text" name="username" placeholder="admin" autocomplete="username" required>
    </div>
    <div class="form-group">
      <label>كلمة المرور</label>
      <input type="password" name="password" placeholder="••••••••" autocomplete="current-password" required>
    </div>
    <button type="submit" class="btn">تسجيل الدخول</button>
  </form>
  <p class="ver">v2.4.1</p>
</div>
</body>
</html>
