<?php
declare(strict_types=1);

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

const DEMO_USERNAME = 'julia.ross';
const DEMO_PASSWORD = 'BankDemo!2026';
const DEFAULT_AVATAR = '/uploads/default-avatar.svg';

function redirect(string $path): void
{
    header('Location: ' . $path);
    exit;
}

function isAuthenticated(): bool
{
    return !empty($_SESSION['user']) && is_array($_SESSION['user']);
}

function requireAuth(): void
{
    if (!isAuthenticated()) {
        redirect('/login.php');
    }
}

function setFlash(string $type, string $message): void
{
    $_SESSION['flash'] = ['type' => $type, 'message' => $message];
}

function pullFlash(): ?array
{
    if (empty($_SESSION['flash'])) {
        return null;
    }
    $flash = $_SESSION['flash'];
    unset($_SESSION['flash']);
    return $flash;
}

function formatCurrency(float $amount): string
{
    return '$' . number_format($amount, 2);
}

function currentUser(): array
{
    if (isAuthenticated()) {
        return $_SESSION['user'];
    }

    return [
        'id' => 1001,
        'username' => DEMO_USERNAME,
        'name' => 'Julia Ross',
        'email' => 'julia.ross@modernbank.local',
        'phone' => '(416) 555-0139',
        'member_since' => '2018',
        'tier' => 'Platinum',
        'avatar' => DEFAULT_AVATAR,
    ];
}

function getMockAccounts(): array
{
    return [
        [
            'name' => 'Everyday Checking',
            'number' => '...1902',
            'balance' => 12456.72,
            'delta' => 2.7,
            'type' => 'Checking',
        ],
        [
            'name' => 'Premium Savings',
            'number' => '...8038',
            'balance' => 86120.43,
            'delta' => 1.2,
            'type' => 'Savings',
        ],
        [
            'name' => 'Travel Rewards Card',
            'number' => '...5531',
            'balance' => -2294.08,
            'delta' => -8.4,
            'type' => 'Credit',
        ],
    ];
}

function getMockTransactions(): array
{
    return [
        ['date' => 'Apr 05', 'merchant' => 'Metro Grocer', 'category' => 'Food', 'account' => 'Checking', 'amount' => -142.85, 'status' => 'Completed'],
        ['date' => 'Apr 04', 'merchant' => 'CloudHost Pro', 'category' => 'Subscriptions', 'account' => 'Credit', 'amount' => -29.00, 'status' => 'Completed'],
        ['date' => 'Apr 03', 'merchant' => 'Payroll Deposit', 'category' => 'Income', 'account' => 'Checking', 'amount' => 4580.00, 'status' => 'Completed'],
        ['date' => 'Apr 01', 'merchant' => 'Aurora Utilities', 'category' => 'Bills', 'account' => 'Checking', 'amount' => -186.30, 'status' => 'Completed'],
        ['date' => 'Mar 29', 'merchant' => 'Harbor Travel', 'category' => 'Travel', 'account' => 'Credit', 'amount' => -824.64, 'status' => 'Completed'],
        ['date' => 'Mar 28', 'merchant' => 'ModernBank Transfer', 'category' => 'Transfer', 'account' => 'Savings', 'amount' => 1500.00, 'status' => 'Scheduled'],
    ];
}

function getMockInsights(): array
{
    return [
        'months' => ['Nov', 'Dec', 'Jan', 'Feb', 'Mar', 'Apr'],
        'cashflow' => [6400, 6120, 7025, 6880, 7190, 7350],
        'spend' => [3900, 3620, 4010, 3785, 4120, 3955],
    ];
}

