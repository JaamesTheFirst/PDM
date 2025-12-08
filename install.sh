#!/bin/bash

# 🚀 Sustainable Transport App - Automated Setup Script
# Run this script to install most dependencies automatically

set -e  # Exit on any error

echo "🚀 Setting up Sustainable Transport App development environment..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_status "Detected macOS - proceeding with macOS-specific setup"
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_warning "Homebrew not found. Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
        print_status "Homebrew already installed"
    fi
    
    # Install core dependencies via Homebrew
    print_status "Installing core dependencies..."
    brew install git node postgresql postgis
    
    # Install global npm packages
    print_status "Installing global npm packages..."
    npm install -g @nestjs/cli prisma yarn
    
    # Start PostgreSQL
    print_status "Starting PostgreSQL service..."
    brew services start postgresql
    
    # Install Flutter (manual step)
    print_warning "Flutter installation requires manual steps:"
    echo "1. Download Flutter SDK from: https://flutter.dev/docs/get-started/install"
    echo "2. Extract to ~/development/flutter"
    echo "3. Add to PATH: export PATH=\"\$PATH:\$HOME/development/flutter/bin\""
    echo "4. Run: flutter doctor"
    
else
    print_warning "Non-macOS system detected. Please follow manual setup instructions in docs/SETUP.md"
fi

# Create development directory structure
print_status "Creating development directories..."
mkdir -p ~/development
mkdir -p ~/development/flutter

# Set up environment variables
print_status "Setting up environment variables..."
SHELL_PROFILE=""
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_PROFILE="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_PROFILE="$HOME/.bash_profile"
fi

if [[ -n "$SHELL_PROFILE" ]]; then
    # Add Flutter to PATH
    if ! grep -q "flutter/bin" "$SHELL_PROFILE"; then
        echo 'export PATH="$PATH:$HOME/development/flutter/bin"' >> "$SHELL_PROFILE"
        print_status "Added Flutter to PATH in $SHELL_PROFILE"
    fi
    
    # Add Android SDK to PATH (if exists)
    if [[ -d "$HOME/Library/Android/sdk" ]]; then
        if ! grep -q "ANDROID_HOME" "$SHELL_PROFILE"; then
            echo 'export ANDROID_HOME=$HOME/Library/Android/sdk' >> "$SHELL_PROFILE"
            echo 'export PATH=$PATH:$ANDROID_HOME/emulator' >> "$SHELL_PROFILE"
            echo 'export PATH=$PATH:$ANDROID_HOME/tools' >> "$SHELL_PROFILE"
            echo 'export PATH=$PATH:$ANDROID_HOME/tools/bin' >> "$SHELL_PROFILE"
            echo 'export PATH=$PATH:$ANDROID_HOME/platform-tools' >> "$SHELL_PROFILE"
            print_status "Added Android SDK to PATH"
        fi
    fi
fi

# Verify installations
print_status "Verifying installations..."

if command -v git &> /dev/null; then
    print_status "Git: $(git --version)"
else
    print_error "Git installation failed"
fi

if command -v node &> /dev/null; then
    print_status "Node.js: $(node --version)"
else
    print_error "Node.js installation failed"
fi

if command -v npm &> /dev/null; then
    print_status "npm: $(npm --version)"
else
    print_error "npm installation failed"
fi

if command -v psql &> /dev/null; then
    print_status "PostgreSQL: $(psql --version)"
else
    print_error "PostgreSQL installation failed"
fi

# Final instructions
echo ""
print_status "Setup completed! Next steps:"
echo ""
echo "1. Install Flutter manually (see instructions above)"
echo "2. Install Android Studio or Xcode for mobile development"
echo "3. Install VS Code with recommended extensions"
echo "4. Run 'flutter doctor' to verify Flutter setup"
echo "5. Clone the project repository"
echo "6. Follow the CONTRIBUTING.md guide"
echo ""
print_warning "Don't forget to restart your terminal or run 'source $SHELL_PROFILE' to reload environment variables"
echo ""
print_status "Happy coding! 🚀"
