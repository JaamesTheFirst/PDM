## Local Data Setup

Use this checklist whenever you need to reproduce the metro / Gira / CP integrations on a new machine.

### 1. Create the external data folder
```
cd ~/PDM
mkdir -p EXTERNALS/data/gira
```
Keep everything under `EXTERNALS/` only; it is ignored by Git so large files don’t pollute the repo.

### 2. Download the Gira historical dataset
1. Browse to https://dadosabertos.cm-lisboa.pt/dataset/gira-bicicletas-de-lisboa-historico
2. Download the latest ZIP (e.g. `estacoes-gira-1-trimestre-2023.zip`).
3. Place the ZIP under `EXTERNALS/data/gira/`.
4. Extract it:
   ```
   cd ~/PDM/EXTERNALS/data/gira
   unzip estacoes-gira-1-trimestre-2023.zip
   ```
   You should now have `estacoes-gira-1-trimestre-2023.xlsx` in that folder.

### 3. Update your backend `.env`
Add (or adjust) the following keys so the backend can ingest Gira data and hit the remote APIs:
```
# Metro Lisboa
METRO_LISBOA_CLIENT_ID="your-client-id"
METRO_LISBOA_CLIENT_SECRET="your-client-secret"

# Gira
GIRA_STATIONS_FILE="/home/<user>/PDM/EXTERNALS/data/gira/estacoes-gira-1-trimestre-2023.xlsx"

# CP live vehicles feed (comboios.live)
CP_VEHICLES_API_URL="https://comboios.live/api/vehicles"
CP_VEHICLES_CACHE_TTL_MS=30000
```
Adapt the absolute path to match your username if needed.

### 4. Install backend dependencies
```
cd ~/PDM/backend
npm install
```
This pulls `xlsx` (for Gira ingestion) and the Nest HTTP client used by CP/Metro.

### 5. Run supporting services
Make sure Docker services are up (Postgres, Redis, etc.):
```
cd ~/PDM
docker compose up -d postgres redis
```

### 6. Start the backend
```
cd ~/PDM/backend
npm run start:dev
```
You should see logs indicating:
- Metro module loaded (OAuth token retrieved automatically)
- Gira service loaded ~933k records from the XLSX
- CP vehicles endpoint fetching data from comboios.live

### 7. Smoke-test the endpoints
Use curl/Postman to verify:
```
# Metro
GET http://localhost:3002/metro/lines/status

# Gira (paged)
GET http://localhost:3002/gira/stations?limit=100&offset=0

# CP live vehicles
GET http://localhost:3002/cp/vehicles
```

Once these calls succeed, the local environment matches the team setup. Share this doc with anyone onboarding so they can reproduce the data requirements without digging through old messages.***

