<?php
require_once dirname(__DIR__) . '/includes/bootstrap.php';
Auth::logout();
header('Location: /login.php');
exit;
