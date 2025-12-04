#!/usr/bin/env ts-node
/**
 * Generates router-config.json for OTP from GBFS systems CSV
 * Includes both GBFS systems and GIRA (if GIRA GBFS feed is available)
 */

import { parse } from 'csv-parse/sync';
import * as fs from 'fs';
import * as path from 'path';

const GBFS_CSV_PATH = path.join(
  __dirname,
  '..',
  '..',
  'data',
  'gbfs',
  'systems_PT.csv',
);

const OUTPUT_PATH = path.join(__dirname, '..', 'build', 'router-config.json');

interface GbfsSystem {
  'System ID': string;
  'Name': string;
  'Auto-Discovery URL': string;
}

function readGbfsSystems(): GbfsSystem[] {
  if (!fs.existsSync(GBFS_CSV_PATH)) {
    throw new Error(`GBFS CSV not found: ${GBFS_CSV_PATH}`);
  }

  console.log(`📖 Reading GBFS systems from: ${GBFS_CSV_PATH}`);
  const csvText = fs.readFileSync(GBFS_CSV_PATH, 'utf8');
  const records = parse(csvText, {
    columns: true,
    skip_empty_lines: true,
    trim: true,
  }) as GbfsSystem[];

  // Filter only systems with auto-discovery URLs
  const validSystems = records.filter(
    (r) => r['Auto-Discovery URL'] && r['Auto-Discovery URL'].trim() !== '',
  );

  console.log(`✅ Found ${validSystems.length} GBFS systems with auto-discovery URLs`);
  return validSystems;
}

function generateRouterConfig(gbfsSystems: GbfsSystem[], giraGbfsUrl?: string) {
  const updaters: any[] = [];

  // Add GBFS systems
  for (const system of gbfsSystems) {
    const autoDiscoveryUrl = system['Auto-Discovery URL'].trim();
    
    // OTP expects the base URL without gbfs.json
    // If URL ends with /gbfs.json, remove it
    const baseUrl = autoDiscoveryUrl.endsWith('/gbfs.json')
      ? autoDiscoveryUrl.slice(0, -10) // Remove '/gbfs.json'
      : autoDiscoveryUrl.replace(/\/gbfs\.json$/, '');

    updaters.push({
      type: 'vehicle-rental',
      sourceType: 'gbfs',
      url: baseUrl,
      frequency: 'PT1M', // Update every minute
      network: system['System ID'],
      allowKeepingRentedVehicleAtDestination: false,
      geofencingZones: false,
    });

    console.log(`  ✓ Added ${system['Name']} (${system['System ID']})`);
  }

  // Add GIRA if GBFS feed URL is provided
  // Note: URL must be HTTP/HTTPS, not file://
  if (giraGbfsUrl) {
    // Remove file:// prefix if present and warn
    let httpUrl = giraGbfsUrl;
    if (giraGbfsUrl.startsWith('file://')) {
      console.warn(`⚠️  GIRA URL uses file:// - OTP requires HTTP. Please serve the files via HTTP.`);
      console.warn(`   Example: python3 -m http.server 8081 in gira-gbfs directory`);
      httpUrl = process.env.GIRA_GBFS_HTTP_URL || 'http://localhost:8081';
      console.warn(`   Using fallback URL: ${httpUrl}`);
    }

    updaters.push({
      type: 'vehicle-rental',
      sourceType: 'gbfs',
      url: httpUrl,
      frequency: 'PT5M', // Update every 5 minutes (static data, less frequent)
      network: 'gira-lisboa',
      allowKeepingRentedVehicleAtDestination: false,
      geofencingZones: false,
    });
    console.log(`  ✓ Added GIRA Lisboa (${httpUrl})`);
  }

  const config = {
    updaters,
  };

  // Ensure output directory exists
  const outputDir = path.dirname(OUTPUT_PATH);
  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(config, null, 2));
  console.log(`\n✅ Generated router-config.json at: ${OUTPUT_PATH}`);
  console.log(`   Total updaters: ${updaters.length}`);
}

function main() {
  try {
    const gbfsSystems = readGbfsSystems();
    
    // Check if GIRA GBFS feed exists and get HTTP URL
    const giraGbfsDir = path.join(__dirname, '..', 'build', 'gira-gbfs');
    const giraGbfsExists = fs.existsSync(giraGbfsDir);
    
    // Get HTTP URL from env or use default
    const giraGbfsUrl = process.env.GIRA_GBFS_HTTP_URL || 
      (giraGbfsExists ? 'http://localhost:8081' : undefined);

    if (giraGbfsExists) {
      if (giraGbfsUrl) {
        console.log(`\n📦 GIRA GBFS feed found at: ${giraGbfsDir}`);
        console.log(`   Using HTTP URL: ${giraGbfsUrl}`);
        console.log(`   Make sure the server is running (see serve-gira-gbfs.sh)`);
      } else {
        console.log(`\n⚠️  GIRA GBFS feed found but no HTTP URL provided.`);
        console.log(`   Set GIRA_GBFS_HTTP_URL or use default http://localhost:8081`);
      }
    } else {
      console.log(`\n⚠️  GIRA GBFS feed not found. Run 'npm run gira-to-gbfs' first.`);
    }

    generateRouterConfig(gbfsSystems, giraGbfsUrl);
  } catch (error) {
    console.error('❌ Error generating router-config.json:', error);
    process.exit(1);
  }
}

if (require.main === module) {
  main();
}

