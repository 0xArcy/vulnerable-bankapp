<?php
declare(strict_types=1);

require_once __DIR__ . '/includes/bootstrap.php';

if (isAuthenticated()) {
    redirect('/dashboard.php');
}

$flash = pullFlash();
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Modern Bank | Secure Sign In</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Public+Sans:wght@300;400;500;600;700&family=Sora:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="/assets/favicon.svg">
    <link rel="stylesheet" href="/css/style.css">
    <link rel="stylesheet" href="/css/brand.css">
    <script defer src="/js/brand.js"></script>
</head>
<body class="login-page">
<main class="login-shell">
    <section class="login-visual">
        <div class="visual-blur visual-blur-a"></div>
        <div class="visual-blur visual-blur-b"></div>
        <div class="login-copy">
            <p class="eyebrow">Modern Bank</p>
            <h1>Banking that feels premium, intelligent, and immediate.</h1>
            <p>Manage personal and business finances in one workspace with real-time balances, proactive insights, and frictionless payments.</p>
            <div class="trust-row">
                <article>
                    <strong>$2.8B+</strong>
                    <span>Assets managed</span>
                </article>
                <article>
                    <strong>98.9%</strong>
                    <span>Transaction uptime</span>
                </article>
                <article>
                    <strong>24/7</strong>
                    <span>Fraud monitoring</span>
                </article>
            </div>
        </div>
    </section>

    <section class="login-panel">
        <article class="panel-card">
            <div class="brand-ribbon"></div>
            <div class="logo-lockup">
                <span class="brand-emblem">
                    <img src="/assets/modernbank-mark.svg" alt="Modern Bank mark">
                </span>
                <div class="brand-copy">
                    <strong>Modern Bank</strong>
                    <small>Asteria Private Series</small>
                </div>
            </div>
            <div class="login-welcome">
                <h2>Welcome back</h2>
                <p>Sign in to view your portfolio and accounts.</p>
            </div>

            <?php if ($flash): ?>
                <div class="alert <?= htmlspecialchars($flash['type'], ENT_QUOTES) ?>">
                    <?= htmlspecialchars($flash['message'], ENT_QUOTES) ?>
                </div>
            <?php endif; ?>

            <form action="/authenticate.php" method="post" class="stack-form">
                <label for="username">Username</label>
                <input id="username" name="username" type="text" placeholder="e.g. julia.ross" required>

                <label for="password">Password</label>
                <input id="password" name="password" type="password" placeholder="Enter your password" required>

                <button type="submit">Sign In</button>
            </form>

            <aside class="demo-hint">
                <p><strong>Demo access</strong></p>
                <p>Username: <code><?= DEMO_USERNAME ?></code></p>
                <p>Password: <code><?= DEMO_PASSWORD ?></code></p>
            </aside>

            <aside class="bank-seal">
                <p>Digital Charter</p>
                <span>ID MB-CA-1142 · Toronto Financial Region</span>
            </aside>
        </article>
    </section>
</main>
</body>
</html>
