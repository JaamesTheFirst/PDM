# GitHub Release Guide

This guide explains how to create a release on GitHub for your professor.

---

## Step 1: Prepare the Release

### 1.1 Ensure Everything Works

1. **Test the release script:**
   ```powershell
   # Windows
   .\scripts\release-run.ps1
   
   # Linux/macOS
   ./scripts/release-run.sh
   ```

2. **Test with mock location:**
   ```powershell
   # Windows
   .\scripts\release-run.ps1 -Mock
   ```

3. **Verify all features work:**
   - Route planning
   - Navigation
   - History
   - Authentication

### 1.2 Clean Up

1. **Remove unnecessary files:**
   ```bash
   # Remove node_modules (will be reinstalled)
   # Remove build artifacts
   # Keep only source code
   ```

2. **Ensure .gitignore is correct:**
   - `.env` files should be ignored
   - `node_modules` should be ignored
   - Build artifacts should be ignored

3. **Check for secrets:**
   - No API keys in code
   - No passwords in code
   - Use environment variables

---

## Step 2: Create a Release Tag

### 2.1 Commit All Changes

```bash
git add .
git commit -m "Release v1.0.0 - Ready for evaluation"
git push origin main
```

### 2.2 Create a Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0 - Initial release for evaluation"

# Push tag to GitHub
git push origin v1.0.0
```

---

## Step 3: Create GitHub Release

### 3.1 Via GitHub Web Interface

1. **Go to your repository on GitHub**
2. **Click "Releases"** (right sidebar)
3. **Click "Create a new release"**
4. **Fill in the form:**
   - **Tag version:** `v1.0.0` (select from dropdown)
   - **Release title:** `EcoMove v1.0.0 - Initial Release`
   - **Description:** Use the template below

### 3.2 Release Description Template

```markdown
# EcoMove v1.0.0 - Initial Release

## 🚀 Quick Start

### One-Click Run

**Windows:**
```powershell
.\scripts\release-run.ps1
```

**Linux/macOS:**
```bash
chmod +x scripts/release-run.sh
./scripts/release-run.sh
```

**With Mock Location (for testing navigation):**
```powershell
# Windows
.\scripts\release-run.ps1 -Mock
```

### Prerequisites

- Docker Desktop (or Docker + Docker Compose)
- WSL 2 (Windows only)
- Flutter SDK (3.35+)
- Node.js (18+)

See [RELEASE.md](RELEASE.md) for detailed setup instructions.

## 📋 Features

- ✅ Route planning with multiple transport modes
- ✅ Real-time navigation
- ✅ Route history
- ✅ Eco impact calculations (CO₂ emissions)
- ✅ Mock location for testing (use `-Mock` flag)

## 📚 Documentation

- [RELEASE.md](RELEASE.md) - Setup and troubleshooting
- [docs/API_ROUTE_PLANNING_EXAMPLES.md](docs/API_ROUTE_PLANNING_EXAMPLES.md) - API examples
- [docs/TESTING_NAVIGATION.md](Frontend/TESTING_NAVIGATION.md) - Navigation testing guide

## 🔧 Troubleshooting

If you encounter issues:
1. Check [RELEASE.md](RELEASE.md) troubleshooting section
2. Ensure Docker is running
3. Ensure all prerequisites are installed
4. Check network connectivity

## 📝 Notes

- The app requires Docker to be running for backend services
- Network connectivity is required for route planning
- A mobile device or emulator is required to run the Flutter app
- Use `-Mock` flag to test navigation without physically moving
```

### 3.3 Attach Files (Optional)

You can attach:
- Screenshots of the app
- Demo video
- Architecture diagrams

---

## Step 4: Share with Professor

### 4.1 Provide Access

1. **Repository URL:** `https://github.com/your-username/PDM`
2. **Release URL:** `https://github.com/your-username/PDM/releases/tag/v1.0.0`

### 4.2 Instructions for Professor

Send them this message:

```
Dear Professor,

I've created a release of the EcoMove project on GitHub.

Repository: https://github.com/your-username/PDM
Release: https://github.com/your-username/PDM/releases/tag/v1.0.0

To run the application:

1. Clone the repository:
   git clone https://github.com/your-username/PDM.git
   cd PDM

2. Run the one-click script:
   Windows: .\scripts\release-run.ps1
   Linux/Mac: ./scripts/release-run.sh

3. The script will:
   - Start all backend services (Docker)
   - Start the Flutter mobile app
   - Configure everything automatically

Prerequisites:
- Docker Desktop
- WSL 2 (Windows only)
- Flutter SDK (3.35+)
- Node.js (18+)

For testing navigation without moving, use:
   .\scripts\release-run.ps1 -Mock

Detailed instructions are in RELEASE.md

Best regards,
[Your Name]
```

---

## Step 5: Alternative - Create a Release ZIP

If GitHub releases don't work, create a ZIP file:

### 5.1 Create Release ZIP

```bash
# Create a clean release directory
mkdir -p release
cp -r scripts release/
cp -r backend release/
cp -r Frontend release/
cp docker-compose.yml release/
cp README.md release/
cp RELEASE.md release/
cp -r docs release/

# Create ZIP (Windows PowerShell)
Compress-Archive -Path release/* -DestinationPath EcoMove-v1.0.0.zip

# Or Linux/macOS
cd release
zip -r ../EcoMove-v1.0.0.zip .
cd ..
```

### 5.2 Include in Release

Upload the ZIP file to the GitHub release as an attachment.

---

## Checklist Before Release

- [ ] All code is committed and pushed
- [ ] Release script tested and working
- [ ] Mock location mode tested
- [ ] No secrets or API keys in code
- [ ] README.md is up to date
- [ ] RELEASE.md is complete
- [ ] All features tested
- [ ] Documentation is clear
- [ ] Tag created and pushed
- [ ] GitHub release created
- [ ] Release description is complete

---

## Tips

1. **Test on a clean machine** (or VM) to ensure setup works
2. **Document any known issues** in the release notes
3. **Include screenshots** of the app in action
4. **Provide a demo video** if possible
5. **List all dependencies** clearly
6. **Include troubleshooting section** in release notes

