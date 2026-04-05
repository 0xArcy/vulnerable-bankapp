<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/bootstrap.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    redirect('/login.php');
}

$username = trim((string)($_POST['username'] ?? ''));
$password = (string)($_POST['password'] ?? '');

if ($username === DEMO_USERNAME && $password === DEMO_PASSWORD) {
    $_SESSION['user'] = [
        'id' => 1001,
        'username' => DEMO_USERNAME,
        'name' => 'Julia Ross',
        'email' => 'julia.ross@modernbank.local',
        'phone' => '(416) 555-0139',
        'member_since' => '2018',
        'tier' => 'Platinum',
        'avatar' => $_SESSION['user']['avatar'] ?? DEFAULT_AVATAR,
    ];
    $_SESSION['user_id'] = 1001;
    $_SESSION['username'] = DEMO_USERNAME;
    $_SESSION['user_type'] = 'standard';
    setFlash('success', 'Welcome back, Julia.');
    redirect('/dashboard.php');
}

setFlash('danger', 'Invalid credentials. Please try again.');
redirect('/login.php');
