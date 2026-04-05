#!/usr/bin/env php
<?php
/**
 * Modern Bank - CGI Admin Interface (PHP)
 * Alternative/supplementary admin endpoint for backend
 * 
 * VULNERABILITY: Unauthenticated command execution
 * Accessed via: http://backend:8080/cgi-bin/admin.php?action=exec&cmd=id
 */

// No authentication required (VULNERABILITY!)
header('Content-Type: application/json');

// Log queries (for CTF debugging)
$log_file = '/tmp/bank_admin_access.log';
@file_put_contents($log_file, date('Y-m-d H:i:s') . " - " . $_SERVER['REMOTE_ADDR'] . " - " . $_SERVER['REQUEST_URI'] . "\n", FILE_APPEND);

// Extract action
$action = $_GET['action'] ?? 'info';

// Windows credentials (exposed in CGI script!)
$windows_creds = array(
    'host' => '192.168.1.50',
    'username' => 'Administrator',
    'password' => 'ModernBank@2024!Admin',
    'database' => 'ModernBank'
);

// Handler for different actions
switch($action) {
    case 'info':
        // System information leak
        echo json_encode(array(
            'server' => 'Modern Bank Backend CGI',
            'php_version' => phpversion(),
            'os' => php_uname(),
            'hostname' => gethostname(),
            'windows_credentials' => $windows_creds,
            'exposed_files' => array(
                '/root/.ssh/id_rsa - SSH key for Database VM',
                '/etc/passwd - System user list',
                '/var/www/html/.env - Frontend configuration'
            )
        ));
        break;

    case 'exec':
        // VULNERABILITY: Command execution!
        $cmd = $_GET['cmd'] ?? 'whoami';
        
        // No validation - command injection possible
        $output = shell_exec(escapeshellcmd($cmd) . ' 2>&1');
        
        echo json_encode(array(
            'success' => true,
            'command' => $cmd,
            'output' => !empty($output) ? $output : '(empty output)'
        ));
        break;

    case 'file':
        // VULNERABILITY: Arbitrary file read
        $file = $_GET['file'] ?? '/etc/passwd';
        
        if (file_exists($file) && is_readable($file)) {
            $content = file_get_contents($file);
            echo json_encode(array(
                'success' => true,
                'file' => $file,
                'size' => strlen($content),
                'content' => $content
            ));
        } else {
            echo json_encode(array(
                'success' => false,
                'error' => 'File not found or not readable',
                'tried' => $file
            ));
        }
        break;

    case 'ssh_keys':
        // VULNERABILITY: Expose SSH keys for Database VM access
        $ssh_dir = '/root/.ssh';
        $response = array(
            'available_keys' => array(),
            'note' => 'These keys can be used to access the Windows Database VM'
        );
        
        if (is_dir($ssh_dir)) {
            foreach (glob($ssh_dir . '/id_*') as $key_file) {
                $response['available_keys'][] = array(
                    'file' => basename($key_file),
                    'path' => $key_file,
                    'readable' => is_readable($key_file)
                );
            }
        }
        
        echo json_encode($response);
        break;

    case 'connect_db':
        // VULNERABILITY: Database connection information
        echo json_encode(array(
            'message' => 'Use these credentials to connect to the Windows Database Server',
            'credentials' => $windows_creds,
            'connection_methods' => array(
                'sqlcmd' => "sqlcmd -S {$windows_creds['host']} -U {$windows_creds['username']} -P '{$windows_creds['password']}'",
                'impacket' => "impacket-mssqlclient -db {$windows_creds['database']} {$windows_creds['username']}:{$windows_creds['password']}@{$windows_creds['host']}",
                'connection_string' => "mssql://{$windows_creds['username']}:{$windows_creds['password']}@{$windows_creds['host']}:1433/{$windows_creds['database']}"
            )
        ));
        break;

    case 'service_status':
        // VULNERABILITY: Service status information
        $services = array(
            'ssh' => shell_exec('systemctl is-active ssh 2>/dev/null'),
            'apache' => shell_exec('systemctl is-active apache2 2>/dev/null'),
            'mysql' => shell_exec('systemctl is-active mysql 2>/dev/null'),
            'node' => shell_exec('pgrep node > /dev/null && echo "active" || echo "inactive"')
        );
        
        echo json_encode(array(
            'services' => $services,
            'running_users' => shell_exec('ps aux | grep -v grep | awk \'{print $1}\' | sort -u')
        ));
        break;

    default:
        echo json_encode(array(
            'error' => 'Unknown action',
            'available_actions' => array(
                'info' => 'System information and credentials',
                'exec' => 'Execute system command (cmd parameter)',
                'file' => 'Read arbitrary file (file parameter)',
                'ssh_keys' => 'List SSH keys available',
                'connect_db' => 'Database connection details',
                'service_status' => 'Backend service status'
            )
        ));
}
?>
