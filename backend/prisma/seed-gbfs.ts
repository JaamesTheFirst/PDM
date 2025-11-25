// backend/prisma/seed-gbfs.ts
import { PrismaClient } from '@prisma/client';
import { parse } from 'csv-parse/sync';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

async function main() {
  // caminho para PDM/EXTERNALS/data/gbfs/systems_PT.csv
  const csvPath = path.join(
    __dirname,
    '..', // backend
    '..', // PDM
    'EXTERNALS',
    'data',
    'gbfs',
    'systems_PT.csv',
  );

  if (!fs.existsSync(csvPath)) {
    throw new Error(`CSV não encontrado em: ${csvPath}`);
  }

  const csvText = fs.readFileSync(csvPath, 'utf8');

  const records = parse(csvText, {
    columns: true,
    skip_empty_lines: true,
  }) as Record<string, string>[];

  console.log(`📄 Registos lidos do CSV: ${records.length}`);

  // opcional: limpar a tabela antes de voltar a inserir
  await prisma.gbfsSystem.deleteMany();

  await prisma.gbfsSystem.createMany({
    data: records.map((r) => ({
      countryCode: r['Country Code'],
      name: r['Name'],
      location: r['Location'] || null,
      systemId: r['System ID'],
      url: r['URL'] || null,
      autoDiscoveryUrl: r['Auto-Discovery URL'] || null,
      supportedVersions: r['Supported Versions'] || null,
      authenticationInfoUrl: r['Authentication Info URL'] || null,
    })),
    skipDuplicates: true, // se voltares a correr o seed mais tarde
  });

  console.log('✅ GBFS systems inseridos na base de dados.');
}

main()
  .catch((e) => {
    console.error('❌ Erro no seed GBFS:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });