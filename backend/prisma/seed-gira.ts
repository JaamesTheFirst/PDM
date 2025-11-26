// backend/prisma/seed-gira.ts
import { PrismaClient } from '@prisma/client';
import { readFile, utils } from 'xlsx';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

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
      'gira_stations.xlsx', // adapta ao caminho correto
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

  await prisma.giraStation.createMany({
    data: rows.map((r) => ({
      externalId: String(r['ID'] ?? r['Station ID'] ?? r['Id'] ?? '') || null,
      name: r['Name'] ?? r['Station Name'] ?? null,
      address: r['Address'] ?? null,
      parish: r['Parish'] ?? r['Freguesia'] ?? null,
      latitude: r['Latitude'] ? Number(r['Latitude']) : null,
      longitude: r['Longitude'] ? Number(r['Longitude']) : null,
      capacity: r['Capacity'] ? Number(r['Capacity']) : null,
      raw: r,
    })),
    skipDuplicates: true,
  });

  console.log('✅ GIRA stations inseridas na BD.');
}

main()
  .catch((e) => {
    console.error('❌ Erro no seed GIRA:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
