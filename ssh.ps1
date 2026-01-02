Write-Host "=== SSHD AUTO-CHECK & FIX SCRIPT ===" -ForegroundColor Cyan

# Check OpenSSH Server
$sshServer = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
if ($sshServer.State -ne "Installed") {
    Write-Host "Installing OpenSSH Server..." -ForegroundColor Yellow
    Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
} else {
    Write-Host "OpenSSH Server already installed." -ForegroundColor Green
}

# Ensure sshd service exists
if (-not (Get-Service sshd -ErrorAction SilentlyContinue)) {
    Write-Host "Registering sshd service..." -ForegroundColor Yellow
    & "C:\Windows\System32\OpenSSH\ssh-keygen.exe" -A
}

# Start sshd
$sshd = Get-Service sshd
if ($sshd.Status -ne "Running") {
    Write-Host "Starting sshd service..." -ForegroundColor Yellow
    Start-Service sshd
}

# Auto-start
Set-Service sshd -StartupType Automatic

# Firewall rule
if (-not (Get-NetFirewallRule -DisplayName "OpenSSH Server (sshd)" -ErrorAction SilentlyContinue)) {
    Write-Host "Creating firewall rule..." -ForegroundColor Yellow
    New-NetFirewallRule -Name sshd -DisplayName "OpenSSH Server (sshd)" -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22
}

# Set PowerShell as default SSH shell
Write-Host "Setting PowerShell as default SSH shell..." -ForegroundColor Yellow
New-ItemProperty `
  -Path "HKLM:\SOFTWARE\OpenSSH" `
  -Name DefaultShell `
  -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
  -PropertyType String `
  -Force

# Restart sshd to apply shell change
Restart-Service sshd

Write-Host "=== SSHD SETUP COMPLETE ===" -ForegroundColor Cyan

