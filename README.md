# 🚲 EcoMove — Sustainable Transport App

**EcoMove** is a cross-platform mobile application that helps users find and plan eco-friendly travel routes using sustainable transportation modes (walking, cycling, public transit, etc.).

Inspired by apps like **Moovit**, but focused on **green energy and sustainability**, this app promotes smart, low-emission mobility with real-time CO₂ impact calculations.

---

## 🌍 Features

- ✅ **Map-based route planning** with multiple transport modes
- ✅ **Real-time navigation** with live GPS tracking
- ✅ **Route history** - Save and repeat your favorite routes
- ✅ **Eco impact calculations** - CO₂ emissions and eco scores
- ✅ **Multiple transport modes** - Walking, cycling, bus, rail, metro
- ✅ **Mock location mode** - Test navigation without physically moving

---

## 🛠 Tech Stack

| Layer       | Technology                     |
|------------|--------------------------------|
| Frontend    | Flutter + Dart                 |
| Backend     | NestJS (Node.js + TypeScript)  |
| Database    | PostgreSQL (via Prisma ORM)    |
| DevOps      | Docker + Docker Compose        |
| API Comm    | REST API                       |
| Auth        | JWT Authentication             |
| Route Planning | OpenTripPlanner (OTP)       |

---

## 🚀 Quick Start (One-Click Run)

**For the easiest setup, use the release script:**

### Windows
```powershell
.\scripts\release-run.ps1
```

### Linux/macOS
```bash
chmod +x scripts/release-run.sh
./scripts/release-run.sh
```

**With mock location (for testing navigation):**
```powershell
# Windows
.\scripts\release-run.ps1 -Mock

# Linux/macOS
./scripts/release-run.sh --mock
```

See [docs/RELEASE.md](docs/RELEASE.md) for detailed instructions and troubleshooting.

---

## 📋 Prerequisites

Before running the app, ensure you have:

- **Docker Desktop** (or Docker + Docker Compose) - Must be running
- **WSL 2** (Windows only)
- **Flutter SDK** (3.35+)
- **Git**

---

## 📚 Documentation

- **[docs/RELEASE.md](docs/RELEASE.md)** - Complete setup and troubleshooting guide
- **[docs/GITHUB_RELEASE_GUIDE.md](docs/GITHUB_RELEASE_GUIDE.md)** - How to create releases
- **[docs/SETUP.md](docs/SETUP.md)** - Detailed development setup
- **[docs/SETUP_WINDOWS.md](docs/SETUP_WINDOWS.md)** - Windows-specific setup
- **[docs/TEAM_SETUP.md](docs/TEAM_SETUP.md)** - Team member onboarding
- **[Frontend/TESTING_NAVIGATION.md](Frontend/TESTING_NAVIGATION.md)** - Navigation testing guide

---

## 🏗️ Project Structure

```
PDM/
├── scripts/
│   ├── spin-up.sh          # Backend startup script
│   ├── release-run.ps1     # Windows one-click script
│   └── release-run.sh     # Linux/macOS one-click script
├── backend/                # NestJS backend API
├── Frontend/               # Flutter mobile app
├── docs/                   # Documentation
├── docker-compose.yml      # Docker services configuration
└── README.md              # This file
```

---

## 🔧 Development

### Start Backend Services

```bash
# Windows (WSL)
wsl bash scripts/spin-up.sh

# Linux/macOS
bash scripts/spin-up.sh
```

### Start Flutter App

```bash
cd Frontend
flutter run
```

### With Mock Location

```bash
cd Frontend
flutter run --dart-define=MOCK_LOCATION=true
```

---

## 📝 License

This project is part of a university course assignment.

---

## 👥 Team

Developed as part of the PDM (Programação de Dispositivos Móveis) course project.

---

## 🆘 Support

For issues or questions:
1. Check [docs/RELEASE.md](docs/RELEASE.md) troubleshooting section
2. Review Docker container status: `docker compose ps`
3. Check backend logs: `docker compose logs backend`
