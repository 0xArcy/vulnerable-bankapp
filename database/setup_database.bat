@echo off
REM ============================================================================
REM Modern Bank - Windows Database VM Setup Script (Batch)
REM Usage: setup_database.bat <BACKEND_IP>
REM 
REM This script:
REM - Installs SQL Server Express (if not installed)
REM - Creates the ModernBank database
REM - Populates sample data
REM - Configures firewall rules
REM - Enables vulnerable services
REM ============================================================================

setlocal enabledelayedexpansion
set "BACKEND_IP=%1"
if "!BACKEND_IP!"=="" set "BACKEND_IP=192.168.1.100"

set "SCRIPT_DIR=%~dp0"
set "LOG_FILE=%TEMP%\modernbank_db_setup.log"

echo. >> "%LOG_FILE%"
echo [%date% %time%] Starting Modern Bank Database Setup >> "%LOG_FILE%"
echo Backend IP: %BACKEND_IP% >> "%LOG_FILE%"

REM ============================================================================
REM Check for Administrator privileges
REM ============================================================================
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if NOT errorlevel 0 (
    echo [ERROR] This script requires Administrator privileges
    echo Please run Command Prompt as Administrator
    pause
    exit /b 1
)

echo.
echo ============================================================================
echo Modern Bank - Windows Database Tier Setup
echo ============================================================================
echo.
echo Backend IP: %BACKEND_IP%
echo Log File: %LOG_FILE%
echo.

REM ============================================================================
REM 1. Check if SQL Server is installed
REM ============================================================================
echo Checking for SQL Server installation...
reg query "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server" >nul 2>&1
if errorlevel 1 (
    echo [WARNING] SQL Server not detected. You may need to install it manually.
    echo Please download SQL Server Express from:
    echo https://www.microsoft.com/en-us/sql-server/sql-server-downloads
    echo.
    pause
) else (
    echo [OK] SQL Server is installed
)

REM ============================================================================
REM 2. Create vulnerable admin user (if not exists)
REM ============================================================================
echo.
echo Creating local admin user...
net localgroup Administrators | find "BankAdmin" >nul 2>&1
if errorlevel 1 (
    net user BankAdmin ModernBank@2024!Admin /add 2>nul
    net localgroup Administrators BankAdmin /add 2>nul
    echo [OK] Created BankAdmin user
) else (
    echo [OK] BankAdmin user already exists
)

REM ============================================================================
REM 3. Create database folder
REM ============================================================================
set "DB_PATH=%ProgramFiles%\ModernBank"
if not exist "%DB_PATH%" mkdir "%DB_PATH%"
echo [OK] Database path created: %DB_PATH%

REM ============================================================================
REM 4. Execute SQL Server configuration
REM ============================================================================
if exist "%SCRIPT_DIR%schema.sql" (
    echo.
    echo Deploying database schema...
    
    REM Try using sqlcmd if available
    where sqlcmd >nul 2>&1
    if not errorlevel 1 (
        echo Executing SQL schema deployment...
        sqlcmd -S localhost\SQLEXPRESS -i "%SCRIPT_DIR%schema.sql" >> "%LOG_FILE%" 2>&1
        if not errorlevel 1 (
            echo [OK] Schema deployed successfully
        ) else (
            echo [WARNING] Schema deployment may have encountered issues
            echo Check %LOG_FILE% for details
        )
    ) else (
        echo [INFO] sqlcmd not in PATH
        echo Please execute manually:
        echo   sqlcmd -S localhost\SQLEXPRESS -i "%SCRIPT_DIR%schema.sql"
    )
) else (
    echo [WARNING] schema.sql not found at %SCRIPT_DIR%
)

REM ============================================================================
REM 5. Enable Named Pipes protocol (for internal access)
REM ============================================================================
echo.
echo Enabling SQL Server Named Pipes...
reg add "HKLM\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL16.SQLEXPRESS\MSSQLServer\SuperSocketNetLib\Sm" /v Enabled /t REG_DWORD /d 1 /f >nul 2>&1
echo [OK] Named Pipes enabled

REM ============================================================================
REM 6. Create malicious scheduled task (for lateral movement demo)
REM ============================================================================
echo.
echo Creating scheduled task for demo purposes...
setlocal
set "TASK_NAME=ModernBankAdminTask"
tasklist /fi "TASKNAME eq %TASK_NAME%" 2>nul | find /i /n "%TASK_NAME%">nul
if not errorlevel 1 (
    echo [OK] Task already exists
) else (
    echo Creating %TASK_NAME%...
    schtasks /create /tn "%TASK_NAME%" /tr "notepad.exe" /sc once /st 23:59 /f >nul 2>&1
    if not errorlevel 1 (
        echo [OK] Scheduled task created
    ) else (
        echo [INFO] Could not create scheduled task (may already exist)
    )
)
endlocal

REM ============================================================================
REM 7. Create exposed credentials file
REM ============================================================================
echo.
echo Creating credentials file...
(
    echo === Modern Bank Database VM - Credentials ===
    echo Discovered: %date% %time%
    echo.
    echo Administrator Access:
    echo - Username: Administrator
    echo - Password: ModernBank@2024!Admin
    echo - RDP Port: 3389
    echo.
    echo SQL Server Database:
    echo - Server: localhost or %%COMPUTERNAME%%
    echo - Instance: SQLEXPRESS
    echo - Database: ModernBank
    echo - Admin User: Administrator
    echo - App User: bankapp
    echo - App Password: BankApp@2024!Insecure
    echo.
    echo Backend Access From:
    echo - IP: %BACKEND_IP%
    echo.
    echo Firewall should allow:
    echo - RDP (3389) from Backend
    echo - MSSQL (1433) from Backend
    echo - SMB (445) from Backend
) > "%DB_PATH%\CREDENTIALS.txt"

echo [OK] Credentials file created: %DB_PATH%\CREDENTIALS.txt

REM ============================================================================
REM 8. Configure Windows Firewall
REM ============================================================================
echo.
echo Configuring Windows Firewall...

REM Open RDP from Backend
netsh advfirewall firewall add rule name="RDP from Backend" dir=in action=allow protocol=tcp localport=3389 remoteip=%BACKEND_IP% >nul 2>&1

REM Open MSSQL from Backend
netsh advfirewall firewall add rule name="MSSQL from Backend" dir=in action=allow protocol=tcp localport=1433 remoteip=%BACKEND_IP% >nul 2>&1

REM Open SMB from Backend
netsh advfirewall firewall add rule name="SMB from Backend" dir=in action=allow protocol=tcp localport=445 remoteip=%BACKEND_IP% >nul 2>&1

echo [OK] Firewall rules configured

REM ============================================================================
REM 9. Enable services
REM ============================================================================
echo.
echo Enabling required services...

REM Ensure SQL Server is running
net start MSSQL$SQLEXPRESS >nul 2>&1
echo [OK] SQL Server service started

REM Ensure SSH is running (for lateral movement testing)
if exist "%SYSTEMROOT%\System32\OpenSSH\sshd.exe" (
    net start sshd >nul 2>&1
    echo [OK] SSH service started
)

REM ============================================================================
REM 10. Summary
REM ============================================================================
echo.
echo ============================================================================
echo Database Setup Complete!
echo ============================================================================
echo.
echo Windows VM: %COMPUTERNAME%
echo Backend IP: %BACKEND_IP%
echo Log File: %LOG_FILE%
echo Credentials: %DB_PATH%\CREDENTIALS.txt
echo.
echo SQL Server Connections:
echo   sqlcmd -S localhost\SQLEXPRESS
echo   sqlcmd -S %COMPUTERNAME%\SQLEXPRESS
echo.
echo Administrator Credentials:
echo   Username: Administrator
echo   Password: ModernBank@2024!Admin
echo.
echo Database Access:
echo   Database: ModernBank
echo   Admin User: bankapp / BankApp@2024!Insecure
echo.
echo Vulnerable Services:
echo   - RDP (3389) - Unauthenticated access possible
echo   - MSSQL (1433) - Weak credentials
echo   - SMB (445) - File sharing enabled
echo   - Scheduled Tasks - Potentially executable
echo.
echo Attack Path:
echo   1. From Backend VM, scan for database services
echo   2. Use exposed credentials to connect to MSSQL
echo   3. Query banking data
echo   4. Escalate privileges via task scheduling
echo   5. Access admin services
echo.

echo.
echo Press any key to continue...
pause >nul

endlocal
