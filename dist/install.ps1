# os-tracker Windows Installer
# Usage:
#   irm https://raw.githubusercontent.com/mael-app/os-tracker/main/dist/install.ps1 | iex

[CmdletBinding()]
param (
    [string]$Repo = "mael-app/os-tracker",
    [string]$InstallDir = "$env:LOCALAPPDATA\os-tracker",
    [string]$ConfigDir = "$env:APPDATA\os-tracker",
    [switch]$NoService
)

$ErrorActionPreference = "Stop"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "=== os-tracker Windows Setup ===" -ForegroundColor Cyan

# 1. Fetch latest release version
Write-Host "Fetching latest release from GitHub ($Repo)..."
$LatestReleaseUrl = "https://api.github.com/repos/$Repo/releases/latest"
try {
    $ReleaseInfo = Invoke-RestMethod -Uri $LatestReleaseUrl -Headers @{ "User-Agent" = "os-tracker-installer" }
    $TagName = $ReleaseInfo.tag_name
} catch {
    Write-Error "Failed to fetch latest release from $LatestReleaseUrl : $_"
    exit 1
}

if (-not $TagName) {
    Write-Error "Could not resolve latest release tag."
    exit 1
}

Write-Host "Latest release is $TagName" -ForegroundColor Green

# 2. Download zip asset
$ZipName = "os-tracker-x86_64-pc-windows-msvc.zip"
$DownloadUrl = "https://github.com/$Repo/releases/download/$TagName/$ZipName"
$TempZip = Join-Path $env:TEMP "$ZipName"
$TempExtract = Join-Path $env:TEMP "os-tracker-extract"

Write-Host "Downloading $DownloadUrl..."
Invoke-WebRequest -Uri $DownloadUrl -OutFile $TempZip -UseBasicParsing

# 3. Extract executable
if (Test-Path $TempExtract) {
    Remove-Item -Recurse -Force $TempExtract
}
Expand-Archive -Path $TempZip -DestinationPath $TempExtract -Force

$SourceExe = Join-Path $TempExtract "os-tracker.exe"
if (-not (Test-Path $SourceExe)) {
    $Found = Get-ChildItem -Path $TempExtract -Filter "os-tracker.exe" -Recurse | Select-Object -First 1
    if ($Found) {
        $SourceExe = $Found.FullName
    }
}

if (-not $SourceExe -or -not (Test-Path $SourceExe)) {
    Write-Error "Could not find os-tracker.exe inside release zip archive."
    exit 1
}

# 4. Stop running process / task if any, before replacing binary
$ExistingProcess = Get-Process -Name "os-tracker" -ErrorAction SilentlyContinue
if ($ExistingProcess) {
    Write-Host "Stopping running os-tracker process..."
    Stop-Process -Name "os-tracker" -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 1
}

# 5. Install to destination
if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
}

$TargetExe = Join-Path $InstallDir "os-tracker.exe"
Copy-Item -Path $SourceExe -Destination $TargetExe -Force
Write-Host "Installed binary to $TargetExe" -ForegroundColor Green

# Cleanup temp files
Remove-Item -Force $TempZip -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $TempExtract -ErrorAction SilentlyContinue

# 6. Ensure InstallDir is in User PATH
$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
$Paths = $UserPath -split ';' | Where-Object { $_ -ne "" }
if ($Paths -notcontains $InstallDir) {
    [Environment]::SetEnvironmentVariable("Path", "$UserPath;$InstallDir", "User")
    $env:Path = "$env:Path;$InstallDir"
    Write-Host "Added $InstallDir to User PATH." -ForegroundColor Yellow
}

# 7. Create default configuration if absent
if (-not (Test-Path $ConfigDir)) {
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
}

$ConfigFile = Join-Path $ConfigDir "config.toml"
if (-not (Test-Path $ConfigFile)) {
    $DefaultConfig = @"
api_url = "https://os-tracker.mael-app.workers.dev"
token = "your-secret-token-here"
interval_secs = 120
"@
    Set-Content -Path $ConfigFile -Value $DefaultConfig -Encoding utf8
    Write-Host "Created configuration template at: $ConfigFile" -ForegroundColor Green
    Write-Host "Please update your token in $ConfigFile before starting the service!" -ForegroundColor Yellow
} else {
    Write-Host "Existing configuration found at: $ConfigFile"
}

# 8. Setup Task Scheduler for background auto-start
if (-not $NoService) {
    $TaskName = "os-tracker"
    Write-Host "Configuring Windows Task Scheduler for background execution..."

    $Action = New-ScheduledTaskAction -Execute $TargetExe
    $Trigger = New-ScheduledTaskTrigger -AtLogon
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Days 0) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)

    try {
        Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Description "OS Tracker Daemon" -Force | Out-Null
        Write-Host "Scheduled task '$TaskName' registered successfully." -ForegroundColor Green

        $ConfigContent = Get-Content -Path $ConfigFile -Raw
        if ($ConfigContent -notmatch "your-secret-token-here") {
            Start-ScheduledTask -TaskName $TaskName
            Write-Host "Started '$TaskName' background task." -ForegroundColor Green
        } else {
            Write-Host "Edit $ConfigFile then run: Start-ScheduledTask -TaskName os-tracker" -ForegroundColor Yellow
        }
    } catch {
        Write-Warning "Could not register scheduled task automatically: $_"
        Write-Host "You can run os-tracker manually or create a startup shortcut."
    }
}

Write-Host ""
Write-Host "=== os-tracker installed successfully! ===" -ForegroundColor Cyan
Write-Host "Config file: $ConfigFile"
Write-Host "Binary:      $TargetExe"
Write-Host ""
Write-Host "Commands:"
Write-Host "  Start service:   Start-ScheduledTask -TaskName os-tracker"
Write-Host "  Stop service:    Stop-ScheduledTask -TaskName os-tracker"
Write-Host "  Check status:    Get-ScheduledTask -TaskName os-tracker"
Write-Host "  Run manually:    os-tracker"
