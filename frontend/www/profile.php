<?php
/**
 * Modern Bank - User Profile & Avatar Upload
 * DELIBERATELY VULNERABLE: Insecure file upload (CTF vulnerability)
 */
session_start();

// Check if user is logged in
if (!isset($_SESSION['user_id'])) {
    header('Location: index.php');
    exit;
}

require_once 'config.php';

$username = $_SESSION['username'] ?? 'User';
$user_id = $_SESSION['user_id'] ?? 1;
$upload_success = false;
$upload_error = '';
$current_avatar = "https://ui-avatars.com/api/?name=" . urlencode($username);

// Check if avatar exists
$avatar_file = $UPLOAD_DIR . $user_id . '.jpg';
if (file_exists($avatar_file)) {
    $current_avatar = 'uploads/' . $user_id . '.jpg?v=' . filemtime($avatar_file);
    if (!empty($_SESSION['user']) && is_array($_SESSION['user'])) {
        $_SESSION['user']['avatar'] = '/' . $current_avatar;
    }
}

// VULNERABILITY: Insecure file upload handling
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['avatar'])) {
    $file = $_FILES['avatar'];

    // VULN 1: Only checks extension (can be bypassed with null bytes or double extensions)
    if (!validateUpload($file)) {
        $upload_error = 'Invalid file type. Please upload an image (JPG, PNG, GIF).';
    } else if ($file['size'] > $MAX_UPLOAD_SIZE) {
        $upload_error = 'File is too large. Maximum size is 50MB.';
    } else {
        // VULN 2: No MIME type checking
        // VULN 3: Predictable filename (user_id.jpg)
        // VULN 4: File is saved in web-accessible directory with execute permissions
        $target_file = $UPLOAD_DIR . $user_id . '.jpg';
        @mkdir($UPLOAD_DIR, 0777, true); // VULN: Broad permissions

        // VULN 5: No file content validation - can upload PHP shell!
        if (move_uploaded_file($file['tmp_name'], $target_file)) {
            // VULN 6: File permissions allow execution
            @chmod($target_file, 0777);
            $upload_success = true;
            $current_avatar = 'uploads/' . $user_id . '.jpg?v=' . time();
            if (!empty($_SESSION['user']) && is_array($_SESSION['user'])) {
                $_SESSION['user']['avatar'] = '/' . $current_avatar;
            }

            // Log the upload (for CTF debugging)
            error_log("File uploaded: $target_file from IP: {$_SERVER['REMOTE_ADDR']}");
        } else {
            $upload_error = 'Failed to upload file. Please try again.';
        }
    }
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Modern Bank | Profile Center</title>
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Public+Sans:wght@300;400;500;600;700&family=Sora:wght@400;500;600;700&display=swap" rel="stylesheet">
    <link rel="icon" type="image/svg+xml" href="/assets/favicon.svg">
    <link rel="stylesheet" href="/css/style.css">
    <link rel="stylesheet" href="/css/brand.css">
    <script defer src="/js/brand.js"></script>
</head>
<body class="dashboard-page">
<main class="profile-shell">
    <div class="brand-ribbon"></div>
    <header class="profile-header card">
        <div>
            <div class="logo-lockup">
                <span class="brand-emblem">
                    <img src="/assets/modernbank-mark.svg" alt="Modern Bank mark">
                </span>
                <div class="brand-copy">
                    <strong>Modern Bank</strong>
                    <small>Asteria Private Series</small>
                </div>
            </div>
            <p class="eyebrow profile-eyebrow">Modern Bank</p>
            <h1>Profile Center</h1>
            <p>Manage your personal identity, avatar, and account details.</p>
            <div class="topbar-meta">
                <span class="brand-chip" data-brand-date>---</span>
                <span class="brand-chip gold" data-brand-time>--:--</span>
                <span class="brand-chip">Client Desk: Toronto Main</span>
            </div>
        </div>
        <div class="profile-actions">
            <a href="/dashboard.php" class="ghost-btn profile-link">Back to Dashboard</a>
            <a href="/logout.php" class="ghost-btn profile-link">Sign Out</a>
        </div>
    </header>

    <section class="profile-grid">
        <article class="card profile-identity">
            <img src="<?php echo htmlspecialchars($current_avatar); ?>" alt="Avatar" class="profile-avatar-large" id="avatarPreview">
            <h2><?php echo htmlspecialchars($username); ?></h2>
            <p>User ID: <?php echo (int)$user_id; ?></p>
            <p>Tier: <?php echo htmlspecialchars(ucfirst($_SESSION['user_type'] ?? 'standard')); ?></p>
            <p>Region: Toronto, ON</p>
        </article>

        <article class="card profile-details">
            <div class="card-head">
                <h3>Identity Details</h3>
                <p>Primary account metadata currently on file.</p>
            </div>
            <div class="detail-grid">
                <div>
                    <label>Full Name</label>
                    <p><?php echo htmlspecialchars(ucfirst($username)); ?> Smith</p>
                </div>
                <div>
                    <label>Email</label>
                    <p><?php echo htmlspecialchars($username); ?>@modernbank.local</p>
                </div>
                <div>
                    <label>Phone</label>
                    <p>+1 (555) 123-4567</p>
                </div>
                <div>
                    <label>Member Since</label>
                    <p>January 15, 2024</p>
                </div>
            </div>
        </article>

        <article class="card profile-upload">
            <div class="card-head">
                <h3>Avatar Upload</h3>
                <p>Upload a photo to personalize your dashboard.</p>
            </div>

            <?php if ($upload_success): ?>
                <div class="alert success">Profile picture updated successfully.</div>
            <?php endif; ?>

            <?php if (!empty($upload_error)): ?>
                <div class="alert danger"><?php echo htmlspecialchars($upload_error); ?></div>
            <?php endif; ?>

            <form method="post" enctype="multipart/form-data" class="stack-form">
                <label for="avatar">Choose image</label>
                <input type="file" id="avatar" name="avatar" accept="image/jpeg,image/png,image/gif" required>
                <p class="helper-copy">Supported formats: JPG, PNG, GIF (max 50MB)</p>
                <button type="submit">Upload Picture</button>
            </form>
            <aside class="bank-seal">
                <p>Profile Service Node</p>
                <span>Tier-2 Identity Cluster · Session Active</span>
            </aside>
        </article>
    </section>
</main>
<script src="/js/dashboard.js"></script>
</body>
</html>
