# 🪟 Windows Development Setup Guide

Complete setup guide for Windows team members working on the Sustainable Transport Grid App.

## 🎯 What You'll Get

After following this guide, you'll be able to:
- ✅ Develop Flutter apps (Web + Android)
- ✅ Work on NestJS backend
- ✅ Use FlutterFlow for UI design
- ✅ Collaborate with the team via Git
- ✅ Run the full development stack

## 🚀 Quick Setup (Automated)

### Option 1: PowerShell Script (Recommended)

**1. Open PowerShell as Administrator**
- Right-click Start button → "Windows PowerShell (Admin)"

**2. Allow script execution:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**3. Run the setup script:**
```powershell
.\install_win.ps1
```

### Option 2: Git Bash Script

**1. Install Git Bash first:**
- Download from: https://git-scm.com/download/win

**2. Open Git Bash as Administrator**

**3. Run the setup script:**
```bash
./install_win.sh
```

## 🛠️ Manual Setup (If Automated Fails)

### Step 1: Install Chocolatey (Package Manager)

**1. Open PowerShell as Administrator**

**2. Install Chocolatey:**
```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
```

### Step 2: Install Development Tools

**Run these commands in PowerShell (as Administrator):**

```powershell
# Core development tools
choco install nodejs -y
choco install git -y
choco install postgresql --params '/Password:postgres' -y
choco install vscode -y

# Flutter development
choco install flutter -y
choco install androidstudio -y

# Additional tools
choco install docker-desktop -y
choco install googlechrome -y
```

### Step 3: Install Global npm Packages

```powershell
npm install -g @nestjs/cli prisma yarn
```

### Step 4: Configure Git

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## 📱 Android Development Setup

### Step 1: Configure Android Studio

**1. Open Android Studio**
**2. Follow the setup wizard**
**3. Install Android SDK**
**4. Install Android SDK Build-Tools**
**5. Install Android Emulator**

### Step 2: Create Virtual Device

**1. In Android Studio: Tools → AVD Manager**
**2. Click "Create Virtual Device"**
**3. Choose "Phone" → "Pixel 7"**
**4. Choose system image (latest API level)**
**5. Click "Finish"**

### Step 3: Set Environment Variables

**Add these to your system PATH:**
- `C:\Users\[USERNAME]\AppData\Local\Android\Sdk\platform-tools`
- `C:\Users\[USERNAME]\AppData\Local\Android\Sdk\tools`

## 🐳 Docker Setup

### Step 1: Start Docker Desktop

**1. Open Docker Desktop**
**2. Wait for Docker to start completely**
**3. Verify with:** `docker --version`

### Step 2: Enable WSL 2 (if prompted)

**1. Follow Docker's WSL 2 setup instructions**
**2. Restart computer if required**

## 💻 VS Code Extensions

**Install these extensions in VS Code:**

**Essential:**
- Flutter (by Dart Code)
- Dart (by Dart Code)
- TypeScript and JavaScript Language Features

**Recommended:**
- Prisma
- GitLens
- Docker
- Thunder Client (for API testing)
- Bracket Pair Colorizer

## 🧪 Verify Your Setup

**Run these commands to verify installation:**

```bash
# Check versions
node --version          # Should show v18+ 
npm --version           # Should show 9+
flutter --version       # Should show 3.35+
git --version           # Should show 2.40+
docker --version        # Should show 20+

# Check Flutter setup
flutter doctor

# Check Android setup
flutter devices
```

## 🚀 Project Setup

### Step 1: Clone Repository

```bash
git clone https://github.com/your-username/sustainable-transport-app.git
cd sustainable-transport-app
```

### Step 2: Backend Setup

```bash
cd backend
npm install
cp env.example .env
# Edit .env file with your database settings
```

### Step 3: Start Database

```bash
cd ..
docker-compose up -d
```

### Step 4: Run Migrations

```bash
cd backend
npx prisma migrate dev
npx prisma generate
```

### Step 5: Start Backend

```bash
npm run start:dev
```

### Step 6: Flutter Setup

```bash
cd ../app
flutter pub get
flutter run -d chrome
```

## 🌐 Development Workflow

### For Web Development
```bash
flutter run -d chrome
```

### For Android Development
```bash
flutter run -d android
```

### For Backend Development
```bash
cd backend
npm run start:dev
```

### For Database Management
```bash
npx prisma studio
```

## 🎨 FlutterFlow Integration

**1. Visit:** https://flutterflow.io
**2. Create account**
**3. Design your UI**
**4. Export Flutter code**
**5. Copy to your `app/` folder**

## 🔧 Common Issues & Solutions

### Flutter Doctor Issues

**Android SDK not found:**
```bash
flutter config --android-sdk C:\Users\[USERNAME]\AppData\Local\Android\Sdk
```

**Android licenses not accepted:**
```bash
flutter doctor --android-licenses
```

### Node.js Issues

**Permission errors:**
```bash
npm config set prefix "C:\Users\[USERNAME]\AppData\Roaming\npm"
```

**Clear cache:**
```bash
npm cache clean --force
```

### Docker Issues

**Docker not starting:**
1. Enable Hyper-V in Windows Features
2. Enable WSL 2
3. Restart computer

### PostgreSQL Issues

**Connection refused:**
1. Check if PostgreSQL service is running
2. Default connection: `postgresql://postgres:postgres@localhost:5432/sustainable_transport`

## 📋 Team Collaboration

### Git Workflow

**1. Always work on feature branches:**
```bash
git checkout preview
git pull origin preview
git checkout -b feat/your-feature-name
```

**2. Push your changes:**
```bash
git add .
git commit -m "Your commit message"
git push origin feat/your-feature-name
```

**3. Create Pull Request to `preview` branch**

### Code Style

**Backend (NestJS):**
- Use Prettier for formatting
- Follow TypeScript best practices
- Use ESLint rules

**Frontend (Flutter):**
- Use `dart format` for formatting
- Follow Flutter/Dart conventions
- Use meaningful widget names

## 🆘 Getting Help

**If you encounter issues:**

1. **Check Flutter doctor:** `flutter doctor -v`
2. **Check Node.js setup:** `node --version && npm --version`
3. **Check Docker:** `docker ps`
4. **Check database:** `psql -U postgres -h localhost`
5. **Ask team members** in project chat
6. **Check project documentation**

## 🎯 What You Can't Do (vs macOS)

**❌ iOS Development:**
- Cannot build iOS apps
- Cannot test on iPhone simulators
- Cannot deploy to App Store

**✅ What You CAN Do:**
- Full Android development
- Web development (Chrome)
- Backend development (NestJS)
- FlutterFlow UI design
- Database management
- Git collaboration

## 📚 Useful Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [NestJS Documentation](https://docs.nestjs.com/)
- [FlutterFlow Documentation](https://docs.flutterflow.io/)
- [Prisma Documentation](https://www.prisma.io/docs/)
- [Android Development](https://developer.android.com/studio)

---

**🎉 You're Ready to Code!**

Once setup is complete, you can focus entirely on development. The iOS builds will be handled by the macOS team member (Scrum Master).

**Next Steps:**
1. Complete this setup
2. Test that everything works
3. Start working on your assigned features
4. Use FlutterFlow for UI design
5. Collaborate via Git branches
