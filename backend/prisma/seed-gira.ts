// backend/prisma/seed-gira.ts
import { PrismaClient } from '@prisma/client';
import { readFile, utils } from 'xlsx';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();
const BATCH_SIZE = 5000;

function toNumber(v: any): number | null {
  if (v === null || v === undefined) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

function mapRowToStation(r: Record<string, any>) {
  // ---- desigcomercial -> externalId + name ----
  const rawDesig = (r['desigcomercial'] as string | null)?.toString().trim() || null;

  let parsedExternalId: string | null = null;
  let parsedNameFromDesig: string | null = null;

  if (rawDesig) {
    // exemplo: "410 - Rua da Mesquita / Universidade Nova de Lisboa"
    const m = /^(\d+)\s*-\s*(.+)$/.exec(rawDesig);
    if (m) {
      parsedExternalId = m[1];   // "410"
      parsedNameFromDesig = m[2]; // "Rua da Mesquita / Universidade Nova de Lisboa"
    } else {
      parsedNameFromDesig = rawDesig;
    }
  }

  // ---- latitude / longitude ----
  let lat: number | null = null;
  let lon: number | null = null;

  if (r['Latitude'] != null && r['Longitude'] != null) {
    lat = toNumber(r['Latitude']);
    lon = toNumber(r['Longitude']);
  } else if (r['position']) {
    try {
      const pos = JSON.parse(String(r['position']));
      if (Array.isArray(pos.coordinates) && pos.coordinates.length >= 2) {
        lon = toNumber(pos.coordinates[0]); // [lon, lat]
        lat = toNumber(pos.coordinates[1]);
      }
    } catch {
      // ignora se não der para fazer parse
    }
  }

  return {
    externalId:
      (r['ID'] ??
        r['Station ID'] ??
        r['Id'] ??
        parsedExternalId)?.toString() || null,

    name:
      (r['Name'] ??
        r['Station Name'] ??
        parsedNameFromDesig) || null,

    address: (r['Address'] as string | null) ?? null,

    parish:
      ((r['Parish'] as string | null) ??
        (r['Freguesia'] as string | null)) ?? null,

    latitude: lat,
    longitude: lon,

    capacity:
      toNumber(r['Capacity']) ??
      toNumber(r['Docks']) ??
      toNumber(r['Capacidade']) ??
      toNumber(r['numdocas']),

    raw: r,
  };
}

async function main() {
  const filePath =
    process.env.GIRA_STATIONS_FILE ||
    path.join(
      __dirname,
      '..',
      '..',
      'EXTERNALS',
      'data',
      'gira',
      'gira_stations.xlsx', // adapta se o nome/caminho for outro
    );

  if (!fs.existsSync(filePath)) {
    throw new Error(`GIRA stations file not found at path ${filePath}`);
  }

  const workbook = readFile(filePath);
  const [firstSheetName] = workbook.SheetNames;
  if (!firstSheetName) {
    throw new Error('GIRA workbook contains no sheets');
  }

  const worksheet = workbook.Sheets[firstSheetName];
  const rows = utils.sheet_to_json<Record<string, any>>(worksheet, {
    defval: null,
  });

  console.log(`📄 GIRA rows lidos: ${rows.length}`);

  await prisma.giraStation.deleteMany();
  console.log('🧹 Tabela giraStation limpa.');

  for (let i = 0; i < rows.length; i += BATCH_SIZE) {
    const slice = rows.slice(i, i + BATCH_SIZE);
    const data = slice.map(mapRowToStation);

    await prisma.giraStation.createMany({
      data,
      skipDuplicates: true,
    });

    console.log(
      `✅ Inseridos ${Math.min(i + BATCH_SIZE, rows.length)} / ${rows.length}`,
    );
  }

  console.log('🎉 GIRA stations inseridas na BD (batch).');
}

main()
  .catch((e) => {
    console.error('❌ Erro no seed GIRA:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
