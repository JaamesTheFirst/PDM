# Spin-Up Scripts

Modular spin-up system that automatically detects IPs and configures all service URLs for a plug-and-play development experience.

## Quick Start

### From WSL (Recommended)

```bash
chmod +x scripts/spin-up.sh
./scripts/spin-up.sh
```

### From Windows PowerShell

```powershell
.\scripts\spin-up.ps1
```

## What It Does

1. **Auto-detects Windows Host IP** - Gets your Windows machine's LAN IPv4 address
2. **Auto-detects WSL IP** - Gets WSL's IP address
3. **Generates Backend .env** - Creates `backend/.env` with all URLs configured
4. **Generates Frontend Config** - Creates `Frontend/lib/config/app_config.dart` with API URLs
5. **Starts All Services** - Runs `docker-compose up -d` to start all services
6. **Health Checks** - Waits for services to be ready

## Configuration

The script automatically configures:

- **Backend API**: `http://<WINDOWS_IP>:3000`
- **OTP Service**: `http://<WINDOWS_IP>:8080/otp`
- **PostgreSQL**: `<WINDOWS_IP>:5432`
- **Redis**: `<WINDOWS_IP>:6379`
- **MongoDB**: `<WINDOWS_IP>:27017`

## Generated Files

- `backend/.env` - Backend environment variables
- `Frontend/lib/config/app_config.dart` - Frontend configuration
- `.env.docker` - Docker Compose environment variables

**Note**: These files are auto-generated. Don't edit them manually - they'll be overwritten on each spin-up.

## Manual Override

If auto-detection fails, you can set the IP manually:

```bash
export WINDOWS_HOST_IP="192.168.1.100"
./scripts/spin-up.sh
```

## Troubleshooting

### IP Detection Fails

If the script can't detect your Windows host IP:

1. Find your IP manually:
   ```powershell
   ipconfig | findstr IPv4
   ```

2. Set it manually:
   ```bash
   export WINDOWS_HOST_IP="<your-ip>"
   ./scripts/spin-up.sh
   ```

### Services Not Starting

Check Docker is running:
```bash
docker ps
```

View logs:
```bash
docker-compose logs -f
```

### Port Conflicts

If ports are already in use, update the ports in `scripts/spin-up.sh`:
```bash
BACKEND_PORT=3001  # Change from 3000
OTP_PORT=8081      # Change from 8080
```

## Stopping Services

```bash
docker-compose down
```

## Restarting

Just run the script again - it will regenerate configs and restart services:

```bash
./scripts/spin-up.sh
```

