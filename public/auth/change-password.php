<?php
require_once dirname(__DIR__, 2) . '/includes/bootstrap.php';
header('Content-Type: application/json');
Auth::requireLogin();
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); die(json_encode(['success'=>false,'message'=>'Method not allowed'])); }

$currentPass = $_POST['current_pass'] ?? '';
$newPass     = $_POST['new_pass']     ?? '';
if (strlen($newPass) < 8) { die(json_encode(['success'=>false,'message'=>'كلمة المرور الجديدة قصيرة جداً (8+ أحرف)'])); }

$user = Database::fetchOne("SELECT * FROM users WHERE id=?", [Auth::user()['id']]);
if (!$user || !password_verify($currentPass, $user['password_hash'])) {
    die(json_encode(['success'=>false,'message'=>'كلمة المرور الحالية غير صحيحة']));
}

$hash = password_hash($newPass, PASSWORD_BCRYPT, ['cost'=>12]);
Database::update('users', ['password_hash' => $hash], 'id=?', [$user['id']]);
Logger::info('auth', "Password changed for: {$user['username']}");
echo json_encode(['success'=>true, 'message'=>'تم تغيير كلمة المرور بنجاح']);
