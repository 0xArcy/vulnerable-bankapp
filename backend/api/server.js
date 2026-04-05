#!/usr/bin/env node
/**
 * Modern Bank - Backend API Server
 * Deliberately vulnerable Node.js Express API
 * 
 * Vulnerabilities:
 * - SSRF via fetch endpoint
 * - Hardcoded Windows credentials
 * - Unauthenticated admin endpoints
 * - Command injection in callback parameters
 */

const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const axios = require('axios');
const os = require('os');
const { execSync, spawn } = require('child_process');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(bodyParser.json());
app.use(cors());

// VULNERABILITY: Hardcoded credentials for Windows Database Server
const WINDOWS_CREDS = {
    host: process.env.WINDOWS_HOST || '192.168.1.50',
    username: 'Administrator',
    password: 'ModernBank@2024!Admin',  // EXPOSED IN ENV
    database: 'ModernBank',
    port: 1433
};

// Store for tracking requests (logging)
let requestLog = [];

// ============================================================================
// VULNERABLE ENDPOINT 1: SSRF via Proxy/Fetch
// ============================================================================
app.post('/api/proxy', (req, res) => {
    /**
     * VULNERABILITY: Server-Side Request Forgery (SSRF)
     * Allows attacker to make requests to internal systems
     * 
     * Attack: POST /api/proxy
     * Body: {"url": "file:///etc/passwd"}
     *       or {"url": "http://192.168.1.50:1433"}
     */
    const { url, method = 'GET' } = req.body;
    
    if (!url) {
        return res.status(400).json({ error: 'URL parameter required' });
    }

    // VULNERABILITY: No URL validation - allows file://, gopher://, etc.
    axios({
        method: method,
        url: url,
        timeout: 5000,
        maxRedirects: 5,
        validateStatus: () => true  // Accept any status code
    })
    .then(response => {
        res.json({
            status: response.status,
            headers: response.headers,
            data: response.data.toString().substring(0, 5000)  // Limit response
        });
    })
    .catch(error => {
        res.status(500).json({
            error: error.message,
            details: error.response?.data || null
        });
    });
});

// ============================================================================
// VULNERABLE ENDPOINT 2: Unauthenticated Admin Endpoint
// ============================================================================
app.get('/cgi-bin/admin.php', (req, res) => {
    /**
     * VULNERABILITY: Unauthenticated Admin Interface
     * Allows attacker to execute commands, query database, etc.
     * 
     * Attack: GET /cgi-bin/admin.php?action=info
     *         GET /cgi-bin/admin.php?action=exec&cmd=id
     *         GET /cgi-bin/admin.php?action=db&query=SELECT...
     */
    const action = req.query.action || 'info';
    
    // VULNERABILITY: No authentication check!
    
    try {
        switch(action) {
            case 'info':
                // System information leak
                res.json({
                    server: 'Modern Bank Backend',
                    version: '1.0.0',
                    environment: process.env.NODE_ENV || 'production',
                    uptime: process.uptime(),
                    hostname: os.hostname(),
                    platform: os.platform(),
                    windows_host: WINDOWS_CREDS.host,
                    windows_user: WINDOWS_CREDS.username,
                    // VULNERABILITY: Credentials exposed!
                    database_credentials: WINDOWS_CREDS
                });
                break;

            case 'exec':
                // VULNERABILITY: Command Injection
                const cmd = req.query.cmd || 'whoami';
                try {
                    const output = execSync(cmd, { 
                        encoding: 'utf8',
                        maxBuffer: 1024 * 1024 * 10
                    });
                    res.json({ 
                        success: true,
                        command: cmd,
                        output: output
                    });
                } catch(e) {
                    res.json({
                        success: false,
                        command: cmd,
                        error: e.message
                    });
                }
                break;

            case 'files':
                // VULNERABILITY: File listing / enumeration
                const path = req.query.path || '/etc';
                try {
                    const output = execSync(`ls -la "${path}"`, {
                        encoding: 'utf8'
                    });
                    res.json({
                        success: true,
                        path: path,
                        files: output
                    });
                } catch(e) {
                    res.json({
                        success: false,
                        error: e.message
                    });
                }
                break;

            case 'db':
                // VULNERABILITY: Database access interface
                const query = req.query.query || 'SELECT 1';
                res.json({
                    credentials: WINDOWS_CREDS,
                    proposed_query: query,
                    note: 'Use Windows credentials above to connect to database',
                    connection_string: `mssql://${WINDOWS_CREDS.username}:${WINDOWS_CREDS.password}@${WINDOWS_CREDS.host}:${WINDOWS_CREDS.port}/${WINDOWS_CREDS.database}`
                });
                break;

            default:
                res.json({
                    error: 'Unknown action',
                    available_actions: ['info', 'exec', 'files', 'db']
                });
        }
    } catch(error) {
        res.status(500).json({ error: error.message });
    }
});

// ============================================================================
// VULNERABLE ENDPOINT 3: Callback Injection
// ============================================================================
app.post('/api/callback', (req, res) => {
    /**
     * VULNERABILITY: Callback parameter injection leading to RCE
     * 
     * Attack: POST /api/callback
     * Body: {"callback": "calcapi.execute('whoami')"}
     */
    const { callback, data } = req.body;
    
    if (!callback) {
        return res.status(400).json({ error: 'Callback parameter required' });
    }

    try {
        // VULNERABILITY: eval() equivalent - RCE!
        const result = Function(`"use strict"; return (${callback})`)();
        res.json({ result: result });
    } catch(e) {
        res.statusCode = 500;
        res.json({ error: e.message });
    }
});

// ============================================================================
// VULNERABLE ENDPOINT 4: Exposed Config
// ============================================================================
app.get('/api/config', (req, res) => {
    /**
     * VULNERABILITY: Configuration dump
     * Exposes all internal settings and credentials
     */
    res.json({
        app_name: 'Modern Bank Backend',
        version: '1.0.0',
        node_env: process.env.NODE_ENV,
        windows_credentials: WINDOWS_CREDS,
        frontend_ip: process.env.FRONTEND_IP || 'Unknown',
        api_key: process.env.API_KEY || 'super_secret_api_key_12345',
        database: {
            type: 'MSSQL',
            host: WINDOWS_CREDS.host,
            port: WINDOWS_CREDS.port,
            user: WINDOWS_CREDS.username,
            password: WINDOWS_CREDS.password
        },
        debug: true
    });
});

// ============================================================================
// VULNERABLE ENDPOINT 5: Exposed Logs
// ============================================================================
app.get('/api/logs', (req, res) => {
    /**
     * VULNERABILITY: Unauthenticated log access
     * Could contain sensitive information
     */
    const limit = parseInt(req.query.limit) || 100;
    res.json({
        total_requests: requestLog.length,
        logs: requestLog.slice(-limit),
        note: 'All internal requests logged'
    });
});

// ============================================================================
// Legitimate Endpoints (for CTF setup)
// ============================================================================
app.get('/api/health', (req, res) => {
    res.json({ 
        status: 'ok',
        timestamp: new Date().toISOString()
    });
});

app.post('/api/authenticate', (req, res) => {
    const { username, password } = req.body;
    
    // Mock authentication
    if (username === 'admin' && password === 'admin123') {
        res.json({
            token: 'mock_token_' + Date.now(),
            user: { id: 1, username: 'admin', role: 'admin' }
        });
    } else {
        res.status(401).json({ error: 'Invalid credentials' });
    }
});

// ============================================================================
// Request logging middleware
// ============================================================================
app.use((req, res, next) => {
    requestLog.push({
        timestamp: new Date().toISOString(),
        method: req.method,
        path: req.path,
        query: req.query,
        ip: req.ip
    });
    
    // Keep only last 1000 requests
    if (requestLog.length > 1000) {
        requestLog.shift();
    }
    
    next();
});

// ============================================================================
// Error handling
// ============================================================================
app.use((err, req, res, next) => {
    console.error('Error:', err);
    res.status(500).json({
        error: 'Internal Server Error',
        message: err.message
    });
});

// ============================================================================
// Server startup
// ============================================================================
app.listen(PORT, () => {
    console.log('╔══════════════════════════════════════════════════════╗');
    console.log('║     Modern Bank - Backend API Server Started         ║');
    console.log('╚══════════════════════════════════════════════════════╝');
    console.log(`\nServer running on port ${PORT}`);
    console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
    console.log(`\nEndpoints:\n`);
    console.log('  GET  /api/health              - Health check');
    console.log('  GET  /api/config              - VULNERABLE: Expose config');
    console.log('  GET  /cgi-bin/admin.php       - VULNERABLE: Admin interface');
    console.log('  POST /api/proxy               - VULNERABLE: SSRF');
    console.log('  POST /api/callback            - VULNERABLE: RCE via callback');
    console.log('  GET  /api/logs                - VULNERABLE: Expose logs');
    console.log('  POST /api/authenticate        - Mock authentication\n');
});

// Keep process running
process.on('SIGINT', () => {
    console.log('\n\nServer shutting down...');
    process.exit(0);
});
