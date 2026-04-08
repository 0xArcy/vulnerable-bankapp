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
}

// VULNERABILITY: Insecure file upload handling
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['avatar'])) {
    $file = $_FILES['avatar'];
    
    // NO VALIDATION - ACCEPTS ANY FILE TYPE
    if (!validateUpload($file)) {
        $upload_error = 'Failed to validate file.';
    } else if ($file['size'] > $MAX_UPLOAD_SIZE) {
        $upload_error = 'File is too large. Maximum size is 50MB.';
    } else {
        // DELIBERATE VULNERABILITY: 
        // - No MIME type checking
        // - Predictable filename (user_id.jpg)
        // - File is saved in web-accessible directory with execute permissions
        // - ANY FILE TYPE CAN BE UPLOADED (including PHP shells!)
        
        // Upload with user_id and original extension
        $ext = pathinfo($file['name'], PATHINFO_EXTENSION);
        $target_file = $UPLOAD_DIR . $user_id . '.' . $ext;
        @mkdir($UPLOAD_DIR, 0777, true); // VULN: Broad permissions
        
        // NO FILE CONTENT VALIDATION - DIRECTLY UPLOAD!
        if (move_uploaded_file($file['tmp_name'], $target_file)) {
            // VULN: File permissions allow execution
            @chmod($target_file, 0777);
            $upload_success = true;
            $current_avatar = 'uploads/' . $user_id . '.' . $ext . '?v=' . time();
            
            // Log the upload (for CTF debugging)
            error_log("File uploaded: $target_file from IP: {$_SERVER['REMOTE_ADDR']}");
        } else {
            $upload_error = 'Failed to upload file. Please try again.';
        }
    }
}
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Profile - Modern Bank</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.10.0/font/bootstrap-icons.css">
    <link rel="stylesheet" href="css/style.css">
</head>
<body>
    <!-- Navigation -->
    <nav class="navbar navbar-expand-lg navbar-dark bg-primary sticky-top">
        <div class="container-fluid">
            <a class="navbar-brand" href="dashboard.php">🏦 Modern Bank</a>
            <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#navbarNav">
                <span class="navbar-toggler-icon"></span>
            </button>
            <div class="collapse navbar-collapse" id="navbarNav">
                <ul class="navbar-nav ms-auto">
                    <li class="nav-item">
                        <a class="nav-link" href="dashboard.php">Dashboard</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link active" href="profile.php">Profile</a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" href="logout.php">Logout</a>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container py-4">
        <div class="row mb-4">
            <div class="col-12">
                <h1 class="h3">User Profile</h1>
                <p class="text-muted">Manage your account settings and preferences</p>
            </div>
        </div>

        <div class="row">
            <div class="col-md-4 mb-4">
                <div class="card shadow-sm border-0">
                    <div class="card-body text-center">
                        <h6 class="text-muted mb-3">Profile Picture</h6>
                        <img src="<?php echo htmlspecialchars($current_avatar); ?>" 
                             alt="Avatar" class="rounded-circle mb-3" style="width: 150px; height: 150px; object-fit: cover;">
                        <h5><?php echo htmlspecialchars($username); ?></h5>
                        <p class="text-muted small">User ID: <?php echo $user_id; ?></p>
                        <p class="text-muted small">Account Type: <?php echo ucfirst($_SESSION['user_type'] ?? 'standard'); ?></p>
                    </div>
                </div>
            </div>

            <div class="col-md-8">
                <div class="card shadow-sm border-0 mb-4">
                    <div class="card-header bg-light">
                        <h5 class="mb-0">Profile Information</h5>
                    </div>
                    <div class="card-body">
                        <div class="row mb-3">
                            <div class="col-md-6">
                                <label class="form-label text-muted small">Full Name</label>
                                <p class="form-control-plaintext"><?php echo htmlspecialchars(ucfirst($username)); ?> Smith</p>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label text-muted small">Email</label>
                                <p class="form-control-plaintext"><?php echo htmlspecialchars($username); ?>@modernbank.local</p>
                            </div>
                        </div>
                        <div class="row mb-3">
                            <div class="col-md-6">
                                <label class="form-label text-muted small">Phone</label>
                                <p class="form-control-plaintext">+1 (555) 123-4567</p>
                            </div>
                            <div class="col-md-6">
                                <label class="form-label text-muted small">Member Since</label>
                                <p class="form-control-plaintext">January 15, 2024</p>
                            </div>
                        </div>
                    </div>
                </div>

                <div class="card shadow-sm border-0">
                    <div class="card-header bg-light">
                        <h5 class="mb-0">Update Profile Picture</h5>
                    </div>
                    <div class="card-body">
                        <?php if ($upload_success): ?>
                            <div class="alert alert-success alert-dismissible fade show" role="alert">
                                <i class="bi bi-check-circle"></i> Profile picture updated successfully!
                                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                            </div>
                        <?php endif; ?>
                        
                        <?php if (!empty($upload_error)): ?>
                            <div class="alert alert-danger alert-dismissible fade show" role="alert">
                                <i class="bi bi-exclamation-circle"></i> <?php echo htmlspecialchars($upload_error); ?>
                                <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
                            </div>
                        <?php endif; ?>

                        <form method="POST" enctype="multipart/form-data">
                            <div class="mb-3">
                                <label for="avatar" class="form-label">Choose Image</label>
                                <input type="file" class="form-control" id="avatar" name="avatar" required>
                                <small class="text-muted d-block mt-2">
                                    <i class="bi bi-info-circle"></i> Any file type accepted (JPG, PNG, GIF, etc.)
                                </small>
                            </div>
                            <button type="submit" class="btn btn-primary">
                                <i class="bi bi-upload"></i> Upload Picture
                            </button>
                        </form>

                        <hr class="my-4">

                        <div class="alert alert-info" role="alert">
                            <i class="bi bi-shield-check"></i>
                            <strong>Security Notice:</strong> Your profile picture is stored securely and only 
                            accessible to you.
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
