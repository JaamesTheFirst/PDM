// backend/prisma/seed-gbfs.ts

import { PrismaClient } from '@prisma/client';
import { parse } from 'csv-parse/sync';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

/**
 * Seed de sistemas GBFS na base de dados.
 *
 * Lê o ficheiro CSV `EXTERNALS/data/gbfs/systems_PT.csv`,
 * faz parse das colunas e popula a tabela `gbfs_systems`.
 *
 * Estratégia:
 *  - valida existência do ficheiro CSV
 *  - faz parse síncrono do CSV em memória
 *  - limpa a tabela `gbfs_systems`
 *  - insere todos os registos com `createMany`
 */
async function main() {
  // Caminho absoluto para PDM/EXTERNALS/data/gbfs/systems_PT.csv
  const csvPath = path.join(
    __dirname,
    '..', // backend
    '..', // PDM (root)
    'EXTERNALS',
    'data',
    'gbfs',
    'systems_PT.csv',
  );

  console.log('📁 CSV path:', csvPath);

  // Garante que o ficheiro existe antes de continuar
  if (!fs.existsSync(csvPath)) {
    throw new Error(`CSV não encontrado em: ${csvPath}`);
  }

  // Lê o conteúdo completo do CSV em memória
  const csvText = fs.readFileSync(csvPath, 'utf8');

  // Faz parse do CSV para uma lista de registos (1 objeto por linha)
  const records = parse(csvText, {
    columns: true,          // usa a primeira linha como header
    skip_empty_lines: true, // ignora linhas vazias
    trim: true,             // remove espaços em branco nos campos
  }) as Record<string, string>[];

  console.log(`📄 Registos lidos do CSV: ${records.length}`);

  // Limpa a tabela antes de inserir novamente (idempotência de seed)
  await prisma.gbfsSystem.deleteMany();
  console.log('🧹 Tabela gbfs_systems limpa');

  // Mapeia cada linha do CSV para o modelo GbfsSystem e insere em bulk
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
    // Em teoria systemId é único, mas mantemos por segurança
    skipDuplicates: true,
  });

  console.log('✅ GBFS systems inseridos na base de dados.');
}

// Execução do script de seed com tratamento de erros
main()
  .catch((e) => {
    console.error('❌ Erro no seed GBFS:', e);
    process.exit(1);
  })
  .finally(async () => {
    // Garante que a ligação Prisma é fechada
    await prisma.$disconnect();
  });
