#!/usr/bin/env ts-node
/**
 * Converts GIRA CSV data to GBFS-compatible JSON format
 * This allows OTP to treat GIRA as a vehicle-rental network
 */

import { parse } from 'csv-parse/sync';
import * as fs from 'fs';
import * as path from 'path';

const GIRA_DATA_DIR = path.join(
  __dirname,
  '..',
  '..',
  'data',
  'gira',
);

// Try to find CSV file (prefer deduplicated, then original, then fallback)
const GIRA_CSV_PATH = (() => {
  // 1. Prefer deduplicated CSV (if it exists)
  const deduplicatedPath = path.join(GIRA_DATA_DIR, 'estacoes-gira-deduplicated.csv');
  if (fs.existsSync(deduplicatedPath)) {
    console.log(`📋 Using deduplicated CSV: ${deduplicatedPath}`);
    return deduplicatedPath;
  }

  // 2. Try the large original file
  const originalPath = path.join(GIRA_DATA_DIR, 'estacoes-gira-2--semestre-2022.csv');
  if (fs.existsSync(originalPath)) {
    console.log(`⚠️  Using original CSV (large file). Consider running 'npm run deduplicate-gira' first.`);
    return originalPath;
  }

  // 3. Fallback to old filename
  const fallbackPath = path.join(GIRA_DATA_DIR, 'estacoes-gira-1-trimestre-2023.csv');
  if (fs.existsSync(fallbackPath)) {
    return fallbackPath;
  }

  // 4. If CSV doesn't exist, try to find it in zip
  const zipPath = path.join(GIRA_DATA_DIR, 'estacoes-gira-1-trimestre-2023.zip');
  if (fs.existsSync(zipPath)) {
    console.log(`⚠️  CSV not found. Please extract estacoes-gira-1-trimestre-2023.csv from the zip file.`);
  }
  
  return fallbackPath; // Will throw error if not found
})();

const OUTPUT_DIR = path.join(__dirname, '..', 'build', 'gira-gbfs');

interface GiraStation {
  station_id: string;
  name: string;
  lat: number;
  lon: number;
  address?: string;
  capacity?: number;
}

function toNumber(v: any): number | null {
  if (v === null || v === undefined) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function parseGiraCsv(): GiraStation[] {
  if (!fs.existsSync(GIRA_CSV_PATH)) {
    throw new Error(
      `GIRA CSV file not found: ${GIRA_CSV_PATH}\n` +
      `Please ensure estacoes-gira-1-trimestre-2023.csv exists in ${GIRA_DATA_DIR}`
    );
  }

  console.log(`📖 Reading GIRA CSV: ${GIRA_CSV_PATH}`);
  const csvContent = fs.readFileSync(GIRA_CSV_PATH, 'utf-8');
  
  // Parse CSV with headers
  const rows = parse(csvContent, {
    columns: true, // Use first line as column names
    skip_empty_lines: true,
    trim: true,
    relax_column_count: true, // Allow inconsistent column counts
  }) as Record<string, any>[];

  console.log(`📄 Found ${rows.length} rows in CSV`);

  const stations: GiraStation[] = [];
  let skippedCount = 0;

  for (const row of rows) {
    // Parse station ID and name from desigcomercial
    const rawDesig = (row['desigcomercial'] as string | null)?.toString().trim() || null;
    let stationId: string | null = null;
    let name: string | null = null;

    if (rawDesig) {
      // Example: "410 - Rua da Mesquita / Universidade Nova de Lisboa"
      const m = /^(\d+)\s*-\s*(.+)$/.exec(rawDesig);
      if (m) {
        stationId = m[1];
        name = m[2];
      } else {
        name = rawDesig;
        stationId = (row['ID'] ?? row['Station ID'] ?? row['Id'])?.toString() || null;
      }
    } else {
      stationId = (row['ID'] ?? row['Station ID'] ?? row['Id'])?.toString() || null;
      name = (row['Name'] ?? row['Station Name'])?.toString() || null;
    }

    // Parse coordinates
    let lat: number | null = null;
    let lon: number | null = null;

    if (row['Latitude'] != null && row['Longitude'] != null) {
      lat = toNumber(row['Latitude']);
      lon = toNumber(row['Longitude']);
    } else if (row['position']) {
      try {
        const pos = JSON.parse(String(row['position']));
        if (Array.isArray(pos.coordinates) && pos.coordinates.length >= 2) {
          lon = toNumber(pos.coordinates[0]); // [lon, lat]
          lat = toNumber(pos.coordinates[1]);
        }
      } catch {
        // Ignore parse errors
      }
    }

    // Skip if we don't have essential data
    if (!stationId || !name || lat === null || lon === null) {
      skippedCount++;
      continue;
    }

    const capacity = toNumber(row['Capacity']) ?? 
                     toNumber(row['Docks']) ?? 
                     toNumber(row['Capacidade']) ?? 
                     toNumber(row['numdocas']);

    stations.push({
      station_id: stationId,
      name: name,
      lat: lat,
      lon: lon,
      address: (row['Address'] as string | null) || undefined,
      capacity: capacity ?? undefined,
    });
  }

  console.log(`✅ Parsed ${stations.length} valid GIRA stations`);
  if (skippedCount > 0) {
    console.log(`⚠️  Skipped ${skippedCount} rows with missing essential data`);
  }
  return stations;
}

function generateGbfsFiles(stations: GiraStation[]) {
  // Ensure output directory exists
  if (!fs.existsSync(OUTPUT_DIR)) {
    fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  }

  const now = Math.floor(Date.now() / 1000);
  const ttl = 3600; // 1 hour TTL for static data

  // 1. gbfs.json - Auto-discovery file
  // Use absolute URLs so OTP can fetch the feeds correctly
  const baseUrl = process.env.GIRA_GBFS_BASE_URL || 'http://host.docker.internal:8081';
  // Ensure baseUrl doesn't end with a slash
  const cleanBaseUrl = baseUrl.replace(/\/$/, '');
  const gbfsIndex = {
    last_updated: now,
    ttl: ttl,
    version: '2.3',
    data: {
      pt: {
        feeds: [
          {
            name: 'system_information',
            url: `${cleanBaseUrl}/system_information.json`,
          },
          {
            name: 'station_information',
            url: `${cleanBaseUrl}/station_information.json`,
          },
          {
            name: 'station_status',
            url: `${cleanBaseUrl}/station_status.json`,
          },
        ],
      },
    },
  };

  // 2. system_information.json
  const systemInformation = {
    last_updated: now,
    ttl: ttl,
    version: '2.3',
    data: {
      system_id: 'gira-lisboa',
      language: 'pt',
      name: 'GIRA - Bicicletas de Lisboa',
      short_name: 'GIRA',
      operator: 'EMEL - Empresa Municipal de Mobilidade e Estacionamento de Lisboa',
      url: 'https://www.gira-bicicletasdelisboa.pt/',
      purchase_url: 'https://www.gira-bicicletasdelisboa.pt/',
      start_date: '2017-08-01',
      phone_number: '+351 21 321 21 21',
      email: 'gira@emel.pt',
      timezone: 'Europe/Lisbon',
      license_url: 'https://www.gira-bicicletasdelisboa.pt/',
      rental_apps: {
        android: {
          store_uri: 'https://play.google.com/store/apps/details?id=pt.emel.gira',
          discovery_uri: 'https://play.google.com/store/apps/details?id=pt.emel.gira',
        },
        ios: {
          store_uri: 'https://apps.apple.com/pt/app/gira/id1234567890',
          discovery_uri: 'https://apps.apple.com/pt/app/gira/id1234567890',
        },
      },
    },
  };

  // 3. station_information.json
  const stationInformation = {
    last_updated: now,
    ttl: ttl,
    version: '2.3',
    data: {
      stations: stations.map((s) => ({
        station_id: s.station_id,
        name: s.name,
        short_name: s.station_id,
        lat: s.lat,
        lon: s.lon,
        address: s.address,
        capacity: s.capacity,
        rental_methods: ['KEY', 'CREDITCARD', 'PHONE'],
        is_virtual_station: false,
        station_area: undefined,
        parking_type: 'STATION',
        parking_hoop: false,
        contact_phone: undefined,
      })),
    },
  };

  // 4. station_status.json - Static availability (we don't have real-time data)
  // Set all stations as available with unknown bike/dock counts
  const stationStatus = {
    last_updated: now,
    ttl: ttl,
    version: '2.3',
    data: {
      stations: stations.map((s) => ({
        station_id: s.station_id,
        num_bikes_available: undefined, // Unknown - no real-time data
        num_bikes_disabled: 0,
        num_docks_available: undefined, // Unknown - no real-time data
        num_docks_disabled: 0,
        is_installed: true,
        is_renting: true,
        is_returning: true,
        last_reported: now,
      })),
    },
  };

  // Write all files
  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'gbfs.json'),
    JSON.stringify(gbfsIndex, null, 2),
  );
  console.log(`✅ Created gbfs.json`);

  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'system_information.json'),
    JSON.stringify(systemInformation, null, 2),
  );
  console.log(`✅ Created system_information.json`);

  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'station_information.json'),
    JSON.stringify(stationInformation, null, 2),
  );
  console.log(`✅ Created station_information.json (${stations.length} stations)`);

  fs.writeFileSync(
    path.join(OUTPUT_DIR, 'station_status.json'),
    JSON.stringify(stationStatus, null, 2),
  );
  console.log(`✅ Created station_status.json`);

  console.log(`\n🎉 GBFS files generated in: ${OUTPUT_DIR}`);
  console.log(`\n📝 Next steps:`);
  console.log(`   1. Serve these files via HTTP (see README)`);
  console.log(`   2. Add GIRA to router-config.json with the feed URL`);
}

function main() {
  try {
    const stations = parseGiraCsv();
    generateGbfsFiles(stations);
  } catch (error) {
    console.error('❌ Error converting GIRA to GBFS:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

