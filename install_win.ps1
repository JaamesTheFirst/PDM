# 🚀 Sustainable Transport App - Windows PowerShell Setup Script
# Run this script in PowerShell as Administrator
# Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

Write-Host "🚀 Setting up Sustainable Transport App development environment for Windows..." -ForegroundColor Green

# Function to print colored output
function Write-Success($message) {
    Write-Host "✅ $message" -ForegroundColor Green
}

function Write-Warning($message) {
    Write-Host "⚠️  $message" -ForegroundColor Yellow
}

function Write-Info($message) {
    Write-Host "ℹ️  $message" -ForegroundColor Blue
}

function Write-Error($message) {
    Write-Host "❌ $message" -ForegroundColor Red
}

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges. Please run PowerShell as Administrator."
    exit 1
}

Write-Success "Running with Administrator privileges"

# Install Chocolatey if not already installed
if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Info "Installing Chocolatey package manager..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Write-Success "Chocolatey installed successfully"
} else {
    Write-Success "Chocolatey already installed"
}

# Refresh environment
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install development tools
Write-Info "Installing development tools..."

$packages = @(
    "nodejs",
    "git",
    "postgresql --params '/Password:postgres'",
    "vscode",
    "flutter",
    "androidstudio",
    "docker-desktop",
    "googlechrome"
)

foreach ($package in $packages) {
    Write-Info "Installing $package..."
    try {
        choco install $package -y
        Write-Success "$package installed successfully"
    } catch {
        Write-Warning "Failed to install $package. You may need to install it manually."
    }
}

# Refresh environment variables
Write-Info "Refreshing environment variables..."
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Install global npm packages
Write-Info "Installing global npm packages..."
try {
    npm install -g @nestjs/cli prisma yarn
    Write-Success "Global npm packages installed"
} catch {
    Write-Warning "Failed to install npm packages. Please run 'npm install -g @nestjs/cli prisma yarn' manually after Node.js is fully installed."
}

# Create development directories
Write-Info "Creating development directories..."
$devPath = "$env:USERPROFILE\development"
if (!(Test-Path $devPath)) {
    New-Item -ItemType Directory -Path $devPath
    Write-Success "Development directory created at $devPath"
}

# Flutter doctor check
Write-Info "Running Flutter doctor..."
try {
    flutter doctor
} catch {
    Write-Warning "Flutter not yet available in PATH. Please restart your terminal and run 'flutter doctor'"
}

Write-Success "Windows development environment setup completed!"

Write-Warning "IMPORTANT NEXT STEPS:"
Write-Host ""
Write-Host "1. RESTART YOUR COMPUTER to ensure all environment variables are loaded" -ForegroundColor Yellow
Write-Host ""
Write-Host "2. Configure Git with your details:" -ForegroundColor Yellow
Write-Host "   git config --global user.name `"Your Name`""
Write-Host "   git config --global user.email `"your.email@example.com`""
Write-Host ""
Write-Host "3. Open Android Studio and complete setup wizard" -ForegroundColor Yellow
Write-Host "   - Install Android SDK"
Write-Host "   - Create Android Virtual Device (AVD)"
Write-Host ""
Write-Host "4. Start Docker Desktop" -ForegroundColor Yellow
Write-Host ""
Write-Host "5. Install VS Code extensions:" -ForegroundColor Yellow
Write-Host "   - Flutter (by Dart Code)"
Write-Host "   - Dart (by Dart Code)"
Write-Host "   - TypeScript and JavaScript Language Features"
Write-Host "   - Prisma"
Write-Host "   - GitLens"
Write-Host "   - Docker"
Write-Host ""
Write-Host "6. Clone and set up the project:" -ForegroundColor Yellow
Write-Host "   git clone https://github.com/your-username/sustainable-transport-app.git"
Write-Host "   cd sustainable-transport-app"
Write-Host "   cd backend && npm install"
Write-Host "   cp env.example .env"
Write-Host "   docker-compose up -d"
Write-Host "   npx prisma migrate dev"
Write-Host ""
Write-Host "7. Test Flutter setup:" -ForegroundColor Yellow
Write-Host "   flutter doctor"
Write-Host "   cd app && flutter pub get"
Write-Host "   flutter run -d chrome"
Write-Host ""

Write-Success "Setup script completed! 🚀"
Write-Info "For FlutterFlow integration, visit: https://flutterflow.io"
