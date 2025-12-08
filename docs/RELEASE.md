# 🚀 EcoMove - Release Instructions

This document explains how to run the EcoMove application with a single click.

---

## Quick Start (One-Click Run)

### Windows (PowerShell)

1. **Open PowerShell** in the project root directory
2. **Run the release script:**
   ```powershell
   .\scripts\release-run.ps1
   ```

   **Or with mock location (for testing navigation without moving):**
   ```powershell
   .\scripts\release-run.ps1 -Mock
   ```

### Linux/macOS

1. **Make the script executable:**
   ```bash
   chmod +x scripts/release-run.sh
   ```

2. **Run the release script:**
   ```bash
   ./scripts/release-run.sh
   ```

   **Or with mock location:**
   ```bash
   ./scripts/release-run.sh --mock
   ```

---

## What the Script Does

The release script automates the following steps:

1. **Starts Backend Services** (via `spin-up.sh`):
   - Detects your network IP addresses
   - Generates configuration files
   - Starts Docker containers (PostgreSQL, Redis, MongoDB, OTP, Backend API)

2. **Waits for Services** to be ready (5 seconds)

3. **Starts Flutter App**:
   - Normal mode: Regular app with real GPS
   - Mock mode: Simulated location for testing navigation

---

## Prerequisites

### Required Software

- **Docker Desktop** (or Docker + Docker Compose)
- **WSL 2** (Windows only)
- **Flutter SDK** (3.35+)
- **Node.js** (18+) - for backend development
- **Git**

### First-Time Setup

1. **Clone the repository:**
   ```bash
   git clone <repository-url>
   cd PDM
   ```

2. **Install Flutter dependencies:**
   ```bash
   cd Frontend
   flutter pub get
   cd ..
   ```

3. **Install backend dependencies:**
   ```bash
   cd backend
   npm install
   cd ..
   ```

4. **Set up environment variables:**
   - The `spin-up.sh` script will auto-generate most configs
   - You may need to add your **Mapbox API key** to `backend/.env`:
     ```
     MAPBOX_API_KEY=your-mapbox-token-here
     ```

---

## Troubleshooting

### Backend Services Won't Start

- **Check Docker is running:** Open Docker Desktop and ensure it's running
- **Check ports are free:** Ports 3000, 5432, 6379, 27017, 8080 should be available
- **Check WSL (Windows):** Ensure WSL 2 is installed and running

### Flutter App Won't Start

- **Check Flutter installation:**
  ```bash
  flutter doctor
  ```
- **Check device/emulator:** Ensure a device or emulator is connected
- **Check dependencies:**
  ```bash
  cd Frontend
  flutter pub get
  ```

### "No route to host" Errors

- The script auto-detects IP addresses, but if your network changed, restart the script
- Ensure your mobile device/emulator is on the same network as your computer

### Authentication Errors

- You need to **register/login** in the app to access history features
- Use the login screen that appears when you first open the app

---

## Manual Steps (If Script Fails)

If the automated script doesn't work, you can run steps manually:

### 1. Start Backend Services

**Windows (WSL):**
```powershell
wsl bash scripts/spin-up.sh
```

**Linux/macOS:**
```bash
bash scripts/spin-up.sh
```

### 2. Start Flutter App

**Normal mode:**
```bash
cd Frontend
flutter run
```

**Mock location mode:**
```bash
cd Frontend
flutter run --dart-define=MOCK_LOCATION=true
```

---

## Features

### Normal Mode
- Real GPS location tracking
- Live navigation with your actual position
- Full app functionality

### Mock Location Mode
- Simulated GPS movement along planned routes
- Test navigation without physically moving
- Useful for development and demos

**To use mock location:**
1. Plan a route in the app
2. Start navigation
3. The app will automatically simulate movement along the route

---

## Project Structure

```
PDM/
├── scripts/
│   ├── spin-up.sh          # Backend startup script
│   ├── release-run.ps1     # Windows one-click script
│   └── release-run.sh      # Linux/macOS one-click script
├── backend/                # NestJS backend API
├── Frontend/               # Flutter mobile app
├── docker-compose.yml      # Docker services configuration
└── README.md              # Main project documentation
```

---

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review the logs in the terminal
3. Check Docker container status: `docker compose ps`
4. Check backend logs: `docker compose logs backend`

---

## Notes for Professors/Evaluators

This application requires:
- **Docker** to be running (for backend services)
- **Network connectivity** (for API calls and OTP route planning)
- **A mobile device or emulator** (for running the Flutter app)

The one-click script (`release-run.ps1` or `release-run.sh`) handles all setup automatically. Simply run it and the app will start.

**For testing navigation without moving:** Use the `-Mock` flag to enable simulated location tracking.

