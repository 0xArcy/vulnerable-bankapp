<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/bootstrap.php';

$_SESSION = [];
session_destroy();
session_start();
setFlash('success', 'You have been signed out.');
redirect('/login.php');

