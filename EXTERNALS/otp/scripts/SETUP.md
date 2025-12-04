# GBFS & GIRA Integration Setup Guide

This guide walks you through integrating GBFS systems and GIRA into OpenTripPlanner (OTP) for route planning.

## Overview

- **GBFS Systems**: Already have live feeds (Bird, Nextbike, etc.) - just need to configure OTP
- **GIRA**: Static Excel data - needs conversion to GBFS format first

## Quick Start

```bash
cd EXTERNALS/otp/scripts

# 1. Install dependencies
npm install

# 2. Convert GIRA Excel to GBFS format
npm run gira-to-gbfs

# 3. Start HTTP server for GIRA GBFS files (in a separate terminal)
chmod +x serve-gira-gbfs.sh
./serve-gira-gbfs.sh

# 4. Generate router-config.json
npm run generate-config

# 5. Restart OTP
docker-compose restart otp
```

## Detailed Steps

### Step 1: Install Dependencies

```bash
cd EXTERNALS/otp/scripts
npm install
```

### Step 2: Convert GIRA to GBFS

Converts the GIRA Excel file to GBFS-compatible JSON:

```bash
npm run gira-to-gbfs
```

**Output:** `EXTERNALS/otp/build/gira-gbfs/` directory with:
- `gbfs.json` (auto-discovery)
- `system_information.json`
- `station_information.json`
- `station_status.json`

### Step 3: Serve GIRA GBFS Files

OTP requires GBFS feeds to be accessible via HTTP. Start a simple server:

```bash
# Make executable
chmod +x serve-gira-gbfs.sh

# Start server (default port 8081)
./serve-gira-gbfs.sh
```

**Keep this running** while OTP is running. The server serves files from `EXTERNALS/otp/build/gira-gbfs/`.

### Step 4: Generate router-config.json

Creates the OTP configuration file with all GBFS systems and GIRA:

```bash
# With default GIRA URL (http://localhost:8081)
npm run generate-config

# Or specify custom URL
GIRA_GBFS_HTTP_URL=http://your-server:8081 npm run generate-config
```

**Output:** `EXTERNALS/otp/build/router-config.json`

### Step 5: Restart OTP

```bash
docker-compose restart otp
```

OTP will now:
- Fetch GBFS data from all systems (Bird, Nextbike, etc.)
- Fetch GIRA data from your local HTTP server
- Include bikeshare/scooter legs in route planning

## Verification

1. **Check OTP logs:**
   ```bash
   docker logs otp | grep -i "vehicle-rental\|gbfs\|gira"
   ```

2. **Test a route** that should include bikeshare:
   - Use OTP GraphQL playground: http://localhost:8080
   - Plan a route with `BICYCLE` mode
   - Check if routes include `BICYCLE_RENT` legs

3. **Check router-config.json:**
   ```bash
   cat EXTERNALS/otp/build/router-config.json
   ```

## Troubleshooting

### GIRA GBFS server not accessible

If OTP can't reach `http://localhost:8081`:
- Make sure the server is running
- If OTP is in Docker, use `host.docker.internal:8081` instead
- Or serve via your backend API

### No bikeshare routes appearing

- Check OTP logs for errors
- Verify `router-config.json` is in `EXTERNALS/otp/build/`
- Ensure OTP was restarted after creating the config
- Check that GBFS feeds are accessible (test URLs in browser)

### GIRA stations not showing

- Verify `gira-to-gbfs.ts` ran successfully
- Check that `gira-gbfs/` directory exists with JSON files
- Ensure HTTP server is running and accessible
- Check OTP logs for GBFS fetch errors

## Production Considerations

For production, consider:
1. **Serve GIRA GBFS via your backend** instead of a simple HTTP server
2. **Add authentication** if needed
3. **Set up periodic updates** if GIRA data changes
4. **Monitor GBFS feed availability** and handle failures gracefully

