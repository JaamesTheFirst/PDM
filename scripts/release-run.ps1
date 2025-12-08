# ===========================================
# One-Click Release Script for Windows
# Runs spin-up.sh and Flutter app
# ===========================================

param(
    [switch]$Mock = $false,
    [switch]$Help = $false
)

if ($Help) {
    Write-Host "Usage: .\release-run.ps1 [-Mock]"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -Mock    Run Flutter app with mock location enabled"
    Write-Host "  -Help    Show this help message"
    Write-Host ""
    Write-Host "Example:"
    Write-Host "  .\release-run.ps1          # Normal run"
    Write-Host "  .\release-run.ps1 -Mock   # Run with mock location"
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

# Get the project root directory (where this script is located)
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Split-Path -Parent $scriptPath

Write-Host "📁 Project root: $projectRoot" -ForegroundColor Green
Write-Host ""

# Step 1: Run spin-up.sh in WSL
Write-Host "🚀 Step 1: Starting backend services..." -ForegroundColor Yellow
Write-Host ""

$spinUpScript = Join-Path $scriptPath "spin-up.sh"
wsl bash $spinUpScript

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "ERROR: Spin-up script failed. Please check the errors above." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Backend services started successfully!" -ForegroundColor Green
Write-Host ""

# Step 2: Wait a bit for services to be ready
Write-Host "⏳ Waiting 5 seconds for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Step 2.5: Install Flutter dependencies (first-time setup)
Write-Host ""
Write-Host "📦 Step 2: Installing Flutter dependencies..." -ForegroundColor Yellow
Write-Host ""

$frontendDir = Join-Path $projectRoot "Frontend"

if (-not (Test-Path $frontendDir)) {
    Write-Host "ERROR: Frontend directory not found at: $frontendDir" -ForegroundColor Red
    exit 1
}

Push-Location $frontendDir

try {
    # Run flutter pub get (idempotent - safe to run multiple times)
    Write-Host "Running 'flutter pub get'..." -ForegroundColor Gray
    flutter pub get | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "WARNING: flutter pub get had issues, but continuing..." -ForegroundColor Yellow
    } else {
        Write-Host "✅ Flutter dependencies installed" -ForegroundColor Green
    }
} catch {
    Write-Host "WARNING: Could not run flutter pub get, but continuing..." -ForegroundColor Yellow
} finally {
    Pop-Location
}

# Step 3: Run Flutter app
Write-Host ""
Write-Host "📱 Step 3: Starting Flutter app..." -ForegroundColor Yellow
Write-Host ""

Push-Location $frontendDir

try {
    if ($Mock) {
        Write-Host "🎭 Running with MOCK LOCATION enabled" -ForegroundColor Magenta
        Write-Host ""
        flutter run --dart-define=MOCK_LOCATION=true
    } else {
        Write-Host "📍 Running in NORMAL mode" -ForegroundColor Cyan
        Write-Host ""
        flutter run
    }
} finally {
    Pop-Location
}

