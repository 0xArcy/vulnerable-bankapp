<?php
/**
 * Modern Bank - Frontend Configuration
 * DELIBERATELY VULNERABLE: Exposed credentials (for CTF purposes)
 */

// Database configuration
define('DB_TYPE', 'MySQL');
define('DB_HOST', getenv('BACKEND_IP') ?: 'localhost');
define('DB_PORT', 3306);
define('DB_USER', 'bankapp');
define('DB_PASS', 'BankApp@2024!Insecure');

// Backend API configuration
define('BACKEND_URL', 'http://' . (getenv('BACKEND_IP') ?: 'localhost') . ':8080');
define('BACKEND_API_KEY', 'super_secret_api_key_12345');

// Session configuration
define('SESSION_TIMEOUT', 3600);

// VULNERABILITY: Exposed SSH credentials for Backend VM
// These should be in a secure vault, but are hardcoded here for CTF
define('BACKEND_SSH_USER', 'deploy');
define('BACKEND_SSH_PASS', 'DeployPass123!Vulnerable');
define('BACKEND_SSH_PORT', 22);

// File upload settings (VULNERABLE)
$MAX_UPLOAD_SIZE = 50 * 1024 * 1024; // 50MB
$ALLOWED_EXTENSIONS = array('jpg', 'jpeg', 'png', 'gif'); // Client-side validation only
$UPLOAD_DIR = __DIR__ . '/uploads/';

// Mock banking data
$BANKS = array(
    'BANK001' => 'First National Bank',
    'BANK002' => 'SecureVault Finance',
    'BANK003' => 'Digital Banking Co'
);

/**
 * VULNERABILITY: Weak file upload validation
 * - No server-side MIME type checking
 * - Extension whitelist bypassed
 * - Permissions allow script execution
 */
function validateUpload($file) {
    global $ALLOWED_EXTENSIONS;
    // Only checks extension (weak!)
    $ext = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
    if (!in_array($ext, $ALLOWED_EXTENSIONS)) {
        return false;
    }
    return true;
}

?>
