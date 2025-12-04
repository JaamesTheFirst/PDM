# OTP Configuration Scripts

Scripts to generate GBFS feeds and OTP router configuration.

## Prerequisites

```bash
# Install dependencies
cd EXTERNALS/otp/scripts
npm install xlsx csv-parse
```

## 1. Convert GIRA to GBFS Format

Converts GIRA Excel data to GBFS-compatible JSON files:

```bash
npx ts-node gira-to-gbfs.ts
```

This generates:
- `EXTERNALS/otp/build/gira-gbfs/gbfs.json`
- `EXTERNALS/otp/build/gira-gbfs/system_information.json`
- `EXTERNALS/otp/build/gira-gbfs/station_information.json`
- `EXTERNALS/otp/build/gira-gbfs/station_status.json`

## 2. Serve GIRA GBFS Feed

Since OTP needs to fetch GBFS feeds via HTTP (not file://), you need to serve the files:

### Option A: Simple HTTP Server (Recommended for Development)

```bash
# Make script executable
chmod +x serve-gira-gbfs.sh

# Run the server (defaults to port 8081)
./serve-gira-gbfs.sh

# Or specify a custom port
GIRA_GBFS_PORT=8081 ./serve-gira-gbfs.sh
```

Keep this server running while OTP is running.

### Option B: Serve via Backend

Add a route in your NestJS backend to serve the GBFS files from `EXTERNALS/otp/build/gira-gbfs/`.

## 3. Generate router-config.json

Generates `router-config.json` with all GBFS systems and GIRA:

```bash
# Make sure GIRA GBFS server is running first (step 2)
# Then generate config with GIRA URL
GIRA_GBFS_HTTP_URL=http://localhost:8081 npm run generate-config

# Or use default (http://localhost:8081)
npm run generate-config
```

**Note:** The GIRA URL must be HTTP/HTTPS. OTP cannot use `file://` URLs.

This creates:
- `EXTERNALS/otp/build/router-config.json`

## 4. Restart OTP

After generating `router-config.json`, restart OTP:

```bash
docker-compose restart otp
# Or if running manually:
docker run -it --rm -p 8080:8080 \
  -e JAVA_TOOL_OPTIONS='-Xmx8g' \
  -v "$PWD/EXTERNALS/otp/build:/var/opentripplanner" \
  docker.io/opentripplanner/opentripplanner:latest \
  --load --serve
```

## Notes

- GIRA station availability is set to `undefined` since we don't have real-time data
- OTP will still use GIRA stations for routing, but won't know exact bike/dock availability
- GBFS feeds update every 1 minute, GIRA updates every 5 minutes (static data)

