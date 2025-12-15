[CmdletBinding()]
param(
    [switch]$Mock = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host "Usage: .\release-run.ps1 [-Mock]" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Gray
    Write-Host "  -Mock    Run Flutter app with mock location enabled" -ForegroundColor Gray
    Write-Host "  -Help    Show this help message" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Example:" -ForegroundColor Gray
    Write-Host "  .\release-run.ps1         # Normal run" -ForegroundColor Gray
    Write-Host "  .\release-run.ps1 -Mock   # Run with mock location" -ForegroundColor Gray
    exit 0
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  EcoMove - One-Click Release Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if WSL is available
$wslAvailable = Get-Command wsl -ErrorAction SilentlyContinue
if (-not $wslAvailable) {
    Write-Host "ERROR: WSL is not available. Please install WSL first." -ForegroundColor Red
    exit 1
}

# Check if Flutter is available
$flutterAvailable = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterAvailable) {
    Write-Host "ERROR: Flutter is not installed or not in PATH." -ForegroundColor Red
    Write-Host "Please install Flutter and add it to your PATH." -ForegroundColor Yellow
    exit 1
}

# Get paths
$scriptPath  = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath

Write-Host "Project root: $projectRoot" -ForegroundColor Green
Write-Host ""

# Step 1: Run spin-up.sh in WSL
Write-Host "Step 1: Starting backend services..." -ForegroundColor Yellow
Write-Host ""

$spinUpScriptWin = Join-Path $scriptPath "spin-up.sh"
if (-not (Test-Path $spinUpScriptWin)) {
    Write-Host "ERROR: spin-up.sh not found at: $spinUpScriptWin" -ForegroundColor Red
    exit 1
}

function Convert-ToWslPath([string]$winPath) {
    $full  = (Resolve-Path $winPath).Path
    $drive = $full.Substring(0,1).ToLower()
    $rest  = $full.Substring(2).Replace('\','/')
    return "/mnt/$drive$rest"
}

# Corre o spin-up a partir da raiz do projecto (só UMA vez)
$projectRootWsl = Convert-ToWslPath $projectRoot
$cmd = "cd '$projectRootWsl' && chmod +x ./scripts/spin-up.sh && bash ./scripts/spin-up.sh"

wsl.exe bash -lc $cmd
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Spin-up script failed. Please check the errors above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Backend services started successfully!" -ForegroundColor Green
Write-Host ""

# Wait a bit for services to be ready
Write-Host "Waiting 5 seconds for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Step 2: Install Flutter dependencies
Write-Host ""
Write-Host "Step 2: Installing Flutter dependencies..." -ForegroundColor Yellow
Write-Host ""

$frontendDir = Join-Path $projectRoot "Frontend"
if (-not (Test-Path $frontendDir)) {
    Write-Host "ERROR: Frontend directory not found at: $frontendDir" -ForegroundColor Red
    exit 1
}

Push-Location $frontendDir
try {
    Write-Host "Running flutter pub get..." -ForegroundColor Gray
    flutter pub get | Out-Null

    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: flutter pub get had issues, but continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "Flutter dependencies installed" -ForegroundColor Green
    }
}
catch {
    Write-Host "WARNING: Could not run flutter pub get, but continuing..." -ForegroundColor Yellow
}
finally {
    Pop-Location
}

# Step 3: Run Flutter app
Write-Host ""
Write-Host "Step 3: Starting Flutter app..." -ForegroundColor Yellow
Write-Host ""

Push-Location $frontendDir
try {
    if ($Mock) {
        Write-Host "Running with MOCK LOCATION enabled" -ForegroundColor Magenta
        Write-Host ""
        flutter run --dart-define=MOCK_LOCATION=true
    } else {
        Write-Host "Running in NORMAL mode" -ForegroundColor Cyan
        Write-Host ""
        flutter run
    }
}
catch {
    Write-Host "ERROR: Flutter run failed. Check the output above." -ForegroundColor Red
    throw
}
finally {
    Pop-Location
}
