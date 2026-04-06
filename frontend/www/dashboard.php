<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/bootstrap.php';
requireAuth();

$user = currentUser();
$accounts = getMockAccounts();
$transactions = getMockTransactions();
$insights = getMockInsights();
$flash = pullFlash();

$totalBalance = 0.0;
foreach ($accounts as $account) {
    $totalBalance += (float)$account['balance'];
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Modern Bank | Dashboard</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Public+Sans:wght@300;400;500;600;700&family=Sora:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="/assets/favicon.svg">
    <link rel="stylesheet" href="/css/style.css">
    <link rel="stylesheet" href="/css/brand.css">
    <script defer src="/js/brand.js"></script>
    <script defer src="https://cdn.jsdelivr.net/npm/chart.js@4.4.6/dist/chart.umd.min.js"></script>
    <script>
        window.bankData = <?= json_encode($insights, JSON_UNESCAPED_SLASHES) ?>;
    </script>
    <script defer src="/js/dashboard.js"></script>
</head>
<body class="dashboard-page">
<div class="app-shell">
    <aside class="sidebar">
        <div class="brand-row">
            <span class="brand-emblem">
                <img src="/assets/modernbank-mark.svg" alt="Modern Bank mark">
            </span>
            <div class="brand-copy">
                <strong>Modern Bank</strong>
                <small>Asteria Wealth Network</small>
            </div>
        </div>
        <nav class="menu">
            <a href="#overview" class="menu-link active">Overview</a>
            <a href="#accounts" class="menu-link">Accounts</a>
            <a href="#payments" class="menu-link">Payments</a>
            <a href="#cards" class="menu-link">Cards</a>
            <a href="#investments" class="menu-link">Investments</a>
            <a href="#security" class="menu-link">Security</a>
        </nav>
        <div class="sidebar-foot">
            <p>Support line</p>
            <strong>1-800-MODERN-1</strong>
        </div>
    </aside>

    <main class="main-view">
        <div class="brand-ribbon"></div>
        <?php if ($flash): ?>
            <div class="alert <?= htmlspecialchars($flash['type'], ENT_QUOTES) ?>">
                <?= htmlspecialchars($flash['message'], ENT_QUOTES) ?>
            </div>
        <?php endif; ?>

        <header class="topbar">
            <div>
                <p class="eyebrow">Good afternoon, <?= htmlspecialchars(explode(' ', (string)$user['name'])[0], ENT_QUOTES) ?></p>
                <h1>Your Financial Command Center</h1>
                <div class="topbar-meta">
                    <span class="brand-chip live"><span class="dot"></span>Systems Nominal</span>
                    <span class="brand-chip" data-brand-date>---</span>
                    <span class="brand-chip gold" data-brand-time>--:--</span>
                    <span class="brand-chip">Region: CA-ON East</span>
                </div>
            </div>
            <div class="topbar-user">
                <img src="<?= htmlspecialchars((string)$user['avatar'], ENT_QUOTES) ?>" alt="Profile avatar" class="avatar-large">
                <div>
                    <strong><?= htmlspecialchars((string)$user['name'], ENT_QUOTES) ?></strong>
                    <span><?= htmlspecialchars((string)$user['tier'], ENT_QUOTES) ?> Member</span>
                </div>
                <span class="primary-pill"><span class="dot"></span>Trusted Session</span>
                <a href="/logout.php" class="ghost-btn">Sign Out</a>
            </div>
        </header>

        <section class="kpi-grid section-target" id="overview">
            <article class="kpi-card">
                <p>Total Portfolio</p>
                <h2 class="count" data-format="currency" data-value="<?= number_format($totalBalance, 2, '.', '') ?>">$0.00</h2>
                <span>Across all products</span>
            </article>
            <article class="kpi-card">
                <p>Monthly Income</p>
                <h2 class="count" data-format="currency" data-value="7350.00">$0.00</h2>
                <span>+4.8% vs last month</span>
            </article>
            <article class="kpi-card">
                <p>Upcoming Bills</p>
                <h2 class="count" data-format="currency" data-value="1296.84">$0.00</h2>
                <span>Due in next 10 days</span>
            </article>
            <article class="kpi-card">
                <p>Reward Points</p>
                <h2 class="count" data-format="number" data-value="98120">0</h2>
                <span>Travel tier unlocked</span>
            </article>
        </section>

        <section class="content-grid">
            <article class="card chart-card section-target" id="investments">
                <div class="card-head">
                    <h3>Cashflow Trend</h3>
                    <p>Income vs spending over 6 months</p>
                </div>
                <div class="chart-wrap">
                    <canvas id="cashflowChart"></canvas>
                </div>
            </article>

            <article class="card accounts-card section-target" id="accounts">
                <div class="card-head">
                    <h3>Accounts</h3>
                    <p>Live balances and daily movement</p>
                </div>
                <div class="account-list">
                    <?php foreach ($accounts as $account): ?>
                        <div class="account-row">
                            <div>
                                <strong><?= htmlspecialchars((string)$account['name'], ENT_QUOTES) ?></strong>
                                <span><?= htmlspecialchars((string)$account['type'], ENT_QUOTES) ?> · <?= htmlspecialchars((string)$account['number'], ENT_QUOTES) ?></span>
                            </div>
                            <div class="align-right">
                                <strong><?= formatCurrency((float)$account['balance']) ?></strong>
                                <span class="<?= ((float)$account['delta'] >= 0) ? 'delta-up' : 'delta-down' ?>">
                                    <?= ((float)$account['delta'] >= 0 ? '+' : '') . number_format((float)$account['delta'], 1) ?>%
                                </span>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            </article>

            <article class="card transaction-card section-target" id="cards">
                <div class="card-head">
                    <h3>Recent Transactions</h3>
                    <p>Latest movement across your accounts</p>
                </div>
                <div class="table-wrap">
                    <table>
                        <thead>
                        <tr>
                            <th>Date</th>
                            <th>Merchant</th>
                            <th>Category</th>
                            <th>Account</th>
                            <th>Amount</th>
                            <th>Status</th>
                        </tr>
                        </thead>
                        <tbody>
                        <?php foreach ($transactions as $row): ?>
                            <tr>
                                <td><?= htmlspecialchars((string)$row['date'], ENT_QUOTES) ?></td>
                                <td><?= htmlspecialchars((string)$row['merchant'], ENT_QUOTES) ?></td>
                                <td><?= htmlspecialchars((string)$row['category'], ENT_QUOTES) ?></td>
                                <td><?= htmlspecialchars((string)$row['account'], ENT_QUOTES) ?></td>
                                <td class="<?= ((float)$row['amount'] >= 0) ? 'delta-up' : 'delta-down' ?>">
                                    <?= ((float)$row['amount'] >= 0 ? '+' : '-') . formatCurrency(abs((float)$row['amount'])) ?>
                                </td>
                                <td>
                                    <span class="status-pill"><?= htmlspecialchars((string)$row['status'], ENT_QUOTES) ?></span>
                                </td>
                            </tr>
                        <?php endforeach; ?>
                        </tbody>
                    </table>
                </div>
            </article>

            <article class="card transfer-card section-target" id="payments">
                <div class="card-head">
                    <h3>Quick Transfer</h3>
                    <p>Move money in seconds</p>
                </div>
                <form class="stack-form" id="quickTransferForm">
                    <label for="fromAccount">From account</label>
                    <select id="fromAccount">
                        <option>Everyday Checking (...1902)</option>
                        <option>Premium Savings (...8038)</option>
                    </select>

                    <label for="toAccount">To account</label>
                    <select id="toAccount">
                        <option>Travel Rewards Card (...5531)</option>
                        <option>Premium Savings (...8038)</option>
                    </select>

                    <label for="transferAmount">Amount</label>
                    <input id="transferAmount" type="number" step="0.01" placeholder="0.00">
                    <button type="button" id="transferReviewBtn">Review Transfer</button>
                </form>
                <div id="transferFeedback" class="transfer-feedback" aria-live="polite"></div>
            </article>

            <article class="card profile-card section-target" id="security">
                <div class="card-head">
                    <h3>Profile</h3>
                    <p>Identity and personalization</p>
                </div>
                <div class="profile-meta">
                    <img src="<?= htmlspecialchars((string)$user['avatar'], ENT_QUOTES) ?>" alt="Profile avatar" class="avatar-hero" id="avatarPreview">
                    <div>
                        <strong><?= htmlspecialchars((string)$user['name'], ENT_QUOTES) ?></strong>
                        <p><?= htmlspecialchars((string)$user['email'], ENT_QUOTES) ?></p>
                        <p><?= htmlspecialchars((string)$user['phone'], ENT_QUOTES) ?></p>
                    </div>
                </div>
                <form class="upload-form" action="/profile.php" method="get">
                    <p class="profile-note">Manage photo upload, account identity, and personal settings in your profile center.</p>
                    <button type="submit">Open Profile Center</button>
                </form>
            </article>
        </section>
    </main>
</div>
</body>
</html>
