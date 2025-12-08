#!/bin/bash

# 🚀 Sustainable Transport App - Windows Setup Script
# This script sets up the development environment for Windows team members
# Run this script in Git Bash or WSL (Windows Subsystem for Linux)

set -e  # Exit on any error

echo "🚀 Setting up Sustainable Transport App development environment for Windows..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if running on Windows (Git Bash/WSL)
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "linux-gnu"* ]]; then
    print_status "Detected Windows environment - proceeding with Windows setup"
else
    print_error "This script is designed for Windows. Use install.sh for macOS."
    exit 1
fi

# Check if Chocolatey is installed (Windows package manager)
if ! command -v choco &> /dev/null; then
    print_warning "Chocolatey not found. Installing Chocolatey..."
    print_info "Please run this command in an Administrator PowerShell:"
    echo "Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))"
    print_warning "After installing Chocolatey, reopen Git Bash as Administrator and run this script again."
    exit 1
fi

print_status "Chocolatey package manager found"

# Install core development tools
print_status "Installing core development tools..."

# Node.js and npm
print_info "Installing Node.js..."
choco install nodejs -y

# Git (if not already installed)
print_info "Installing Git..."
choco install git -y

# PostgreSQL
print_info "Installing PostgreSQL..."
choco install postgresql --params '/Password:postgres' -y

# Visual Studio Code
print_info "Installing Visual Studio Code..."
choco install vscode -y

# Flutter SDK
print_info "Installing Flutter SDK..."
choco install flutter -y

# Android Studio (for Android development)
print_info "Installing Android Studio..."
choco install androidstudio -y

# Docker Desktop (for database)
print_info "Installing Docker Desktop..."
choco install docker-desktop -y

# Chrome (for web development)
print_info "Installing Google Chrome..."
choco install googlechrome -y

print_status "Core tools installation completed!"

# Refresh environment variables
print_status "Refreshing environment variables..."
refreshenv

# Install global npm packages
print_status "Installing global npm packages..."
npm install -g @nestjs/cli prisma yarn

# Configure Git (user will need to set their own details)
print_warning "Git configuration needed:"
echo "Please run these commands with your details:"
echo "git config --global user.name \"Your Name\""
echo "git config --global user.email \"your.email@example.com\""

# Flutter doctor check
print_status "Running Flutter doctor to check setup..."
flutter doctor

# Create development directories
print_status "Creating development directories..."
mkdir -p ~/development

# PostgreSQL setup instructions
print_warning "PostgreSQL setup instructions:"
echo "1. PostgreSQL has been installed with password 'postgres'"
echo "2. Default user: postgres"
echo "3. Default port: 5432"
echo "4. To connect: psql -U postgres -h localhost"

# Android Studio setup instructions
print_warning "Android Studio setup required:"
echo "1. Open Android Studio"
echo "2. Follow the setup wizard"
echo "3. Install Android SDK"
echo "4. Create an Android Virtual Device (AVD)"
echo "5. Run 'flutter doctor' to verify Android setup"

# Docker setup instructions
print_warning "Docker setup instructions:"
echo "1. Start Docker Desktop"
echo "2. Wait for Docker to fully start"
echo "3. You can now use docker-compose commands"

# VS Code extensions to install
print_warning "Recommended VS Code extensions to install:"
echo "1. Flutter (by Dart Code)"
echo "2. Dart (by Dart Code)"
echo "3. TypeScript and JavaScript Language Features"
echo "4. Prisma"
echo "5. GitLens"
echo "6. Docker"

# Final verification commands
print_status "Verification commands to run:"
echo "node --version"
echo "npm --version"
echo "flutter --version"
echo "git --version"
echo "docker --version"

# Project setup instructions
print_status "Project setup instructions:"
echo ""
echo "1. Clone the project repository:"
echo "   git clone https://github.com/your-username/sustainable-transport-app.git"
echo "   cd sustainable-transport-app"
echo ""
echo "2. Install backend dependencies:"
echo "   cd backend"
echo "   npm install"
echo ""
echo "3. Set up environment variables:"
echo "   cp env.example .env"
echo "   # Edit .env with your database settings"
echo ""
echo "4. Start Docker containers:"
echo "   cd .."
echo "   docker-compose up -d"
echo ""
echo "5. Run database migrations:"
echo "   cd backend"
echo "   npx prisma migrate dev"
echo ""
echo "6. Start development server:"
echo "   npm run start:dev"
echo ""
echo "7. Create Flutter app:"
echo "   cd ../app"
echo "   flutter pub get"
echo "   flutter run -d chrome"
echo ""

print_status "Windows development environment setup completed!"
print_info "Please restart your terminal/command prompt to ensure all environment variables are loaded."
print_info "If you encounter any issues, check the troubleshooting section in docs/SETUP.md"

echo ""
print_status "Happy coding! 🚀"
print_info "For FlutterFlow integration, visit: https://flutterflow.io"
print_info "Team collaboration: Use the preview branch for integration testing"
