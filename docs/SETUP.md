# 🚀 Project Setup Guide

Complete installation guide for the Sustainable Transport Grid App development environment.

## 📋 Prerequisites Checklist

Before starting, ensure you have:

- [ ] macOS (for iOS development) or Windows/Linux (Android only)
- [ ] At least 8GB RAM
- [ ] 10GB free disk space
- [ ] Stable internet connection

## 🛠️ Core Development Tools

### 1. Git (Version Control)
```bash
# Check if Git is installed
git --version

# If not installed, install via Homebrew (macOS)
brew install git

# Or download from: https://git-scm.com/
```

### 2. Node.js & npm (Backend)
```bash
# Install Node.js 18+ (LTS recommended)
# Download from: https://nodejs.org/

# Verify installation
node --version  # Should be 18.x or higher
npm --version   # Should be 9.x or higher

# Install yarn (optional, but recommended)
npm install -g yarn
```

### 3. Flutter SDK (Mobile App)
```bash
# Download Flutter SDK
# Go to: https://flutter.dev/docs/get-started/install

# Extract to ~/development/flutter (or your preferred location)
# Add to PATH in your shell profile (~/.zshrc or ~/.bash_profile)

# Add these lines to your shell profile:
export PATH="$PATH:$HOME/development/flutter/bin"

# Reload your shell
source ~/.zshrc  # or ~/.bash_profile

# Verify installation
flutter --version
flutter doctor
```

### 4. PostgreSQL + PostGIS (Database)
```bash
# macOS - Install via Homebrew
brew install postgresql postgis

# Start PostgreSQL service
brew services start postgresql

# Create a database user (optional)
createuser -s postgres

# Install PostGIS extension (run in psql)
psql -d postgres
CREATE EXTENSION postgis;
\q
```

### 5. Development IDEs
Choose one or more:

**VS Code (Recommended)**
- Download: https://code.visualstudio.com/
- Extensions to install:
  - Flutter
  - Dart
  - TypeScript and JavaScript Language Features
  - Prisma
  - PostgreSQL
  - GitLens

**Android Studio (For Android development)**
- Download: https://developer.android.com/studio
- Install Flutter plugin when prompted

**Xcode (macOS only, for iOS development)**
- Install from Mac App Store
- Install Xcode Command Line Tools: `xcode-select --install`

## 📱 Mobile Development Setup

### Android Setup
```bash
# Install Android SDK (usually comes with Android Studio)
# Set ANDROID_HOME environment variable

# Add to your shell profile:
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Create Android Virtual Device (AVD)
flutter emulators --create --name pixel_7
```

### iOS Setup (macOS only)
```bash
# Install Xcode from App Store
# Install iOS Simulator
# Accept Xcode license
sudo xcodebuild -license accept

# Install iOS development tools
flutter doctor --android-licenses
```

## 🔧 Backend Dependencies

### NestJS & TypeScript
```bash
# Install NestJS CLI globally
npm install -g @nestjs/cli

# Verify installation
nest --version
```

### Database Tools
```bash
# Install Prisma CLI globally
npm install -g prisma

# Install database GUI (optional)
# TablePlus: https://tableplus.com/
# Or pgAdmin: https://www.pgadmin.org/
```

## 🧪 Testing Your Setup

### 1. Flutter Doctor
```bash
flutter doctor
```
This should show all green checkmarks. Fix any issues it reports.

### 2. Test Node.js
```bash
node --version
npm --version
```

### 3. Test PostgreSQL
```bash
psql -d postgres -c "SELECT version();"
```

### 4. Test NestJS
```bash
nest new test-app
cd test-app
npm run start:dev
# Should start server on http://localhost:3000
```

## 📦 Project-Specific Dependencies

Once the project is created, you'll need these packages:

### Backend (NestJS)
```bash
cd backend
npm install @nestjs/core @nestjs/common @nestjs/platform-express
npm install @nestjs/jwt @nestjs/passport passport passport-jwt
npm install @nestjs/config
npm install prisma @prisma/client
npm install class-validator class-transformer
npm install bcryptjs
npm install @types/bcryptjs --save-dev
```

### Frontend (Flutter)
```bash
cd app
flutter pub add http
flutter pub add dio
flutter pub add google_maps_flutter
flutter pub add geolocator
flutter pub add flutter_secure_storage
flutter pub add provider
flutter pub add shared_preferences
```

## 🚨 Common Issues & Solutions

### Flutter Issues
```bash
# If Flutter doctor shows issues:
flutter doctor --android-licenses
flutter clean
flutter pub get

# If Android SDK not found:
export ANDROID_HOME=$HOME/Library/Android/sdk
```

### Node.js Issues
```bash
# Clear npm cache
npm cache clean --force

# Use specific Node version (if needed)
nvm install 18
nvm use 18
```

### PostgreSQL Issues
```bash
# Reset PostgreSQL password
brew services stop postgresql
brew services start postgresql
```

## ✅ Final Verification

Run this checklist before starting development:

- [ ] `git --version` works
- [ ] `node --version` shows 18+
- [ ] `npm --version` works
- [ ] `flutter doctor` shows all green
- [ ] `psql -d postgres` connects
- [ ] `nest --version` works
- [ ] Android/iOS emulator available
- [ ] VS Code with extensions installed

## 🆘 Getting Help

If you encounter issues:

1. Check Flutter doctor: `flutter doctor -v`
2. Check Node.js version: `node --version`
3. Restart your terminal/IDE
4. Check environment variables: `echo $PATH`
5. Ask team members or check project documentation

## 📚 Useful Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [NestJS Documentation](https://docs.nestjs.com/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [Prisma Documentation](https://www.prisma.io/docs/)

---

**Next Steps**: Once everyone has completed this setup, we'll initialize the project structure and start development!
