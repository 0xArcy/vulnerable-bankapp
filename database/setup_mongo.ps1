# Setup Database (MongoDB on Windows 10)
# Requirements: Run as Administrator

param (
    [string]$BackendIP = "10.0.10.102",
    [string]$DbUser = "modernbank_app",
  [string]$DbPassword = "ModernBankMongo!2026",
  [string]$DbName = "modernbank",
  [string]$AdminUser = "modernbank_admin",
  [string]$AdminPassword = ""
)

Write-Host "Setting up modernbank database on Windows..."
# Ensure Admin
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Warning "Please run Windows PowerShell as Administrator."
    Exit
}

$MongoUrl = "https://fastdl.mongodb.org/windows/mongodb-windows-x86_64-8.2.6-signed.msi"
$InstallerPath = "$env:TEMP\mongodb.msi"

function Get-MongoServerPath {
    $roots = Get-ChildItem -Path "C:\Program Files\MongoDB\Server" -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending

    foreach ($root in $roots) {
        if (Test-Path (Join-Path $root.FullName "bin\mongod.exe")) {
            return $root.FullName
        }
    }

    return $null
}

function Get-MongoShellPath {
  $command = Get-Command mongosh -ErrorAction SilentlyContinue
  if ($command -and $command.Source -and (Test-Path $command.Source)) {
    return $command.Source
  }

  $candidates = @(
    (Join-Path $MongoBinPath "mongosh.exe"),
    "C:\Program Files\MongoDB\mongosh\bin\mongosh.exe",
    (Join-Path $MongoBinPath "mongo.exe")
  )

  return $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}

$MongoPath = Get-MongoServerPath

if (-not $MongoPath) {
    Write-Host "Downloading MongoDB..."
    Invoke-WebRequest -Uri $MongoUrl -OutFile $InstallerPath
    Write-Host "Installing MongoDB..."
    Start-Process msiexec.exe -Wait -ArgumentList "/i `"$InstallerPath`" ADDLOCAL=ServerService /qn /norestart"
    Start-Sleep -Seconds 5
    $MongoPath = Get-MongoServerPath
}

if (-not $MongoPath) {
    throw "MongoDB Community Server installation was not detected under C:\Program Files\MongoDB\Server"
}

$MongoBinPath = Join-Path $MongoPath "bin"
$MongoCfgPath = Join-Path $MongoBinPath "mongod.cfg"
$MongoLogPath = Join-Path $MongoPath "log"
$MongoDataPath = Join-Path $MongoPath "data"
$StateDir = Join-Path $env:ProgramData "ModernBank"
$AdminCredPath = Join-Path $StateDir "mongo-admin.json"

New-Item -ItemType Directory -Force -Path $MongoLogPath | Out-Null
New-Item -ItemType Directory -Force -Path $MongoDataPath | Out-Null
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

$MongoClient = Get-MongoShellPath

if (-not $MongoClient) {
  Write-Host "MongoDB server is installed, but MongoDB Shell is missing. Attempting to install mongosh..."

  if (Get-Command winget -ErrorAction SilentlyContinue) {
    Start-Process winget -Wait -ArgumentList "install", "--id", "MongoDB.Shell", "-e", "--accept-source-agreements", "--accept-package-agreements"
  } else {
    Write-Warning "winget is not available. Install MongoDB Shell manually from https://www.mongodb.com/try/download/shell"
  }

  $env:Path += ";C:\Program Files\MongoDB\mongosh\bin"
  $MongoClient = Get-MongoShellPath

  if (-not $MongoClient) {
    throw "Could not find mongosh.exe or mongo.exe after attempting shell install. Install MongoDB Shell, then rerun setup_mongo.ps1."
  }
}

$ConfigCdata = @"
systemLog:
  destination: file
  path: $MongoLogPath\mongod.log
  logAppend: true
storage:
  dbPath: $MongoDataPath
net:
  port: 27017
  bindIp: 0.0.0.0
security:
  authorization: enabled
"@
$ConfigCdata | Out-File -FilePath $MongoCfgPath -Encoding ASCII -Force

function New-RandomSecret {
  param(
    [int]$Bytes = 24
  )

  $buffer = New-Object byte[] $Bytes
  [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buffer)
  return ([BitConverter]::ToString($buffer)).Replace("-", "").ToLowerInvariant()
}

function Get-AdminCredentials {
  if ([string]::IsNullOrWhiteSpace($AdminPassword) -and (Test-Path $AdminCredPath)) {
    $saved = Get-Content $AdminCredPath -Raw | ConvertFrom-Json
    return @{
      User = [string]$saved.user
      Password = [string]$saved.password
    }
  }

  if ([string]::IsNullOrWhiteSpace($AdminPassword)) {
    $script:AdminPassword = New-RandomSecret
  }

  return @{
    User = $AdminUser
    Password = $AdminPassword
  }
}

function Save-AdminCredentials {
  param(
    [string]$User,
    [string]$Password
  )

  @{
    user = $User
    password = $Password
  } | ConvertTo-Json | Out-File -FilePath $AdminCredPath -Encoding ASCII -Force
}

function Invoke-MongoEval {
  param(
    [string]$Eval,
    [hashtable]$Credentials,
    [switch]$Quiet
  )

  $mongoArgs = @("--host", "127.0.0.1", "--port", "27017")

  if ($Quiet) {
    $mongoArgs += "--quiet"
  }

  if ($Credentials) {
    $mongoArgs += @(
      "-u", $Credentials.User,
      "-p", $Credentials.Password,
      "--authenticationDatabase", "admin"
    )
  }

  $mongoArgs += @("--eval", $Eval)
  return (& $MongoClient @mongoArgs)
}

function Test-AdminCredentials {
  param(
    [hashtable]$Credentials
  )

  try {
    $result = Invoke-MongoEval -Credentials $Credentials -Quiet -Eval "db.getSiblingDB('admin').runCommand({ connectionStatus: 1 }).ok"
    return ($result | Out-String) -match "1"
  } catch {
    return $false
  }
}

function Initialize-AdminUser {
  param(
    [hashtable]$Credentials
  )

  $bootstrapAdminEval = @"
db = db.getSiblingDB('admin');
existingAdmin = db.getUser('$($Credentials.User)');
if (existingAdmin) {
  db.updateUser('$($Credentials.User)', { pwd: '$($Credentials.Password)', roles: [ { role: 'root', db: 'admin' } ] });
} else {
  db.createUser({ user: '$($Credentials.User)', pwd: '$($Credentials.Password)', roles: [ { role: 'root', db: 'admin' } ] });
}
"@

  Invoke-MongoEval -Eval $bootstrapAdminEval | Out-Null
  Save-AdminCredentials -User $Credentials.User -Password $Credentials.Password
}

Write-Host "Restarting MongoDB service..."
if (Get-Service -Name "MongoDB" -ErrorAction SilentlyContinue) {
    Restart-Service -Name "MongoDB" -Force
} else {
    & (Join-Path $MongoBinPath "mongod.exe") --config $MongoCfgPath --install | Out-Null
    Start-Service -Name "MongoDB"
}

Write-Host "Creating app user... Please give it 10 seconds..."
Start-Sleep -Seconds 10

$AdminCredentials = Get-AdminCredentials

if (-not (Test-AdminCredentials -Credentials $AdminCredentials)) {
  Write-Host "Bootstrapping MongoDB admin account..."

  try {
    Initialize-AdminUser -Credentials $AdminCredentials
  } catch {
    throw "Unable to create or authenticate the MongoDB admin user. If this host has stale MongoDB users from an earlier install, clear the demo data or provide the existing admin credentials and rerun the script. Original error: $($_.Exception.Message)"
  }
}

$MongoEval = @"
db = db.getSiblingDB('admin');
existingUser = db.getUser('$DbUser');
if (existingUser) {
  db.updateUser('$DbUser', { pwd: '$DbPassword', roles: [ { role: 'readWrite', db: '$DbName' } ] });
} else {
  db.createUser({ user: '$DbUser', pwd: '$DbPassword', roles: [ { role: 'readWrite', db: '$DbName' } ] });
}
"@

Invoke-MongoEval -Credentials $AdminCredentials -Eval $MongoEval | Out-Null

Write-Host "Firewall: Allowing MongoDB port 27017 from Backend IP..."
Get-NetFirewallRule -DisplayName "MongoDB from Backend" -ErrorAction SilentlyContinue | Remove-NetFirewallRule -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName "MongoDB from Backend" -Direction Inbound -LocalPort 27017 -Protocol TCP -RemoteAddress $BackendIP -Action Allow | Out-Null

Write-Host "MongoDB Community Server configured on Windows 10 (10.0.10.106)."
Write-Host "Database: $DbName"
Write-Host "Application user: $DbUser"
Write-Host "Bootstrap admin credential file: $AdminCredPath"
Write-Host "Allowed backend IP: $BackendIP"
