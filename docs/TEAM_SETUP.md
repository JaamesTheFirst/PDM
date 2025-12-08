# 👥 Team Setup Guide

Quick setup instructions for all team members working on the Sustainable Transport Grid App.

## 🎯 Choose Your Platform

### 🍎 macOS Users
**Run this command:**
```bash
chmod +x install.sh && ./install.sh
```

**What you get:**
- ✅ Full iOS + Android development
- ✅ Flutter + Xcode + CocoaPods
- ✅ NestJS + PostgreSQL + Docker
- ✅ Can deploy to App Store (if needed)

### 🪟 Windows Users
**Option 1 - PowerShell (Recommended):**
```powershell
# Run as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\install_win.ps1
```

**Option 2 - Git Bash:**
```bash
chmod +x install_win.sh && ./install_win.sh
```

**What you get:**
- ✅ Android + Web development
- ✅ Flutter + Android Studio
- ✅ NestJS + PostgreSQL + Docker
- ✅ FlutterFlow integration
- ❌ No iOS development (macOS only)

## 📋 After Installation

### 1. Verify Setup
```bash
node --version      # Should be 18+
flutter --version   # Should be 3.35+
git --version       # Should be 2.40+
flutter doctor      # Should show green checkmarks
```

### 2. Clone Project
```bash
git clone https://github.com/your-username/sustainable-transport-app.git
cd sustainable-transport-app
```

### 3. Install Dependencies
```bash
# Backend
cd backend && npm install

# Frontend
cd ../app && flutter pub get
```

### 4. Start Development
```bash
# Start database
docker-compose up -d

# Start backend
cd backend && npm run start:dev

# Start frontend
cd ../app && flutter run -d chrome
```

## 🌟 Team Workflow

### Git Branches
- **`main`** - Production ready code
- **`preview`** - Integration testing
- **`feat/*`** - Your feature branches

### Development Process
1. **Create feature branch:** `git checkout -b feat/your-feature`
2. **Code your feature**
3. **Push to GitHub:** `git push origin feat/your-feature`
4. **Create PR to `preview`**
5. **After review, merge to `preview`**
6. **Test on `preview`**
7. **When stable, merge `preview` to `main`**

### FlutterFlow Integration
1. **Visit:** https://flutterflow.io
2. **Design UI components**
3. **Export Flutter code**
4. **Copy to `app/` folder**
5. **Customize and integrate**

## 🎯 Role Distribution

### Windows Team Members
**Focus on:**
- ✅ NestJS backend development
- ✅ Flutter logic and state management
- ✅ FlutterFlow UI design
- ✅ Android testing and builds
- ✅ Web development and testing
- ✅ Database schema and APIs

### macOS Team Member (Scrum Master)
**Focus on:**
- ✅ iOS development and testing
- ✅ Final app compilation
- ✅ Infrastructure and DevOps
- ✅ Code reviews and integration
- ✅ Project management

## 🚀 Quick Start Commands

### Backend Development
```bash
cd backend
npm run start:dev     # Start development server
npx prisma studio     # Open database GUI
npx prisma generate   # Generate database client
```

### Frontend Development
```bash
cd app
flutter run -d chrome    # Run in web browser
flutter run -d android   # Run on Android (Windows)
flutter run -d ios       # Run on iOS (macOS only)
```

### Database Management
```bash
docker-compose up -d      # Start database
docker-compose down       # Stop database
npx prisma migrate dev    # Run migrations
```

## 📚 Documentation

- **Detailed Windows Setup:** [docs/SETUP_WINDOWS.md](docs/SETUP_WINDOWS.md)
- **Detailed macOS Setup:** [docs/SETUP.md](docs/SETUP.md)
- **Contributing Guidelines:** [CONTRIBUTING.md](./CONTRIBUTING.md)
- **Git Workflow:** [CONTRIBUTING.md](./CONTRIBUTING.md)

## 🆘 Need Help?

1. **Check setup documentation** for your platform
2. **Run diagnostic commands** (`flutter doctor`, `node --version`)
3. **Ask in team chat** - we're here to help!
4. **Check GitHub issues** for known problems

## 🎉 Ready to Code!

Once your setup is complete:
- ✅ All tools installed and working
- ✅ Project cloned and dependencies installed
- ✅ Database running
- ✅ Development servers started

**Focus on coding - the infrastructure is handled! 🚀**
