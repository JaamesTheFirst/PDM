// backend/prisma/seed-gira.ts

import { PrismaClient } from '@prisma/client';
import { readFile, utils } from 'xlsx';
import * as fs from 'fs';
import * as path from 'path';

const prisma = new PrismaClient();

/**
 * Número máximo de registos inseridos de cada vez.
 * Ajuda a evitar problemas de memória e timeouts em inserções massivas.
 */
const BATCH_SIZE = 5000;

/**
 * Converte um valor genérico para número, devolvendo null se não for numericamente válido.
 *
 * @param v Valor de entrada (string, number, etc.)
 * @returns Número convertido ou null em caso de falha
 */
function toNumber(v: any): number | null {
  if (v === null || v === undefined) return null;
  const n = Number(v);
  return Number.isFinite(n) ? n : null;
}

/**
 * Mapeia uma linha do Excel GIRA para o formato esperado pelo modelo `GiraStation`.
 *
 * Responsável por:
 *  - extrair o ID externo da estação (a partir de múltiplas colunas possíveis)
 *  - extrair nome, morada e freguesia
 *  - tentar obter latitude/longitude a partir de colunas simples
 *  - como fallback, tentar parsear um campo `position` com GeoJSON
 *  - inferir capacidade a partir de colunas alternativas (Capacity, Docks, etc.)
 *
 * @param r Linha do Excel convertida para objeto (coluna -> valor)
 * @returns Objeto pronto para `prisma.giraStation.createMany`
 */
function mapRowToStation(r: Record<string, any>) {
  // ---- desigcomercial -> externalId + name ----
  const rawDesig = (r['desigcomercial'] as string | null)?.toString().trim() || null;

  let parsedExternalId: string | null = null;
  let parsedNameFromDesig: string | null = null;

  if (rawDesig) {
    // Exemplo de formato: "410 - Rua da Mesquita / Universidade Nova de Lisboa"
    const m = /^(\d+)\s*-\s*(.+)$/.exec(rawDesig);
    if (m) {
      parsedExternalId = m[1];   // "410"
      parsedNameFromDesig = m[2]; // "Rua da Mesquita / Universidade Nova de Lisboa"
    } else {
      // Caso não siga o padrão, usamos o valor completo como nome
      parsedNameFromDesig = rawDesig;
    }
  }

  // ---- latitude / longitude ----
  let lat: number | null = null;
  let lon: number | null = null;

  // Caso típico: colunas diretas Latitude / Longitude
  if (r['Latitude'] != null && r['Longitude'] != null) {
    lat = toNumber(r['Latitude']);
    lon = toNumber(r['Longitude']);
  } else if (r['position']) {
    // Fallback: tentar ler de um campo JSON `position` (ex.: GeoJSON)
    try {
      const pos = JSON.parse(String(r['position']));
      if (Array.isArray(pos.coordinates) && pos.coordinates.length >= 2) {
        // Convenção [lon, lat]
        lon = toNumber(pos.coordinates[0]);
        lat = toNumber(pos.coordinates[1]);
      }
    } catch {
      // Ignora erros de parse, coordenadas ficam null
    }
  }

  return {
    // Tenta várias colunas candidatas para o ID externo da estação
    externalId:
      (r['ID'] ??
        r['Station ID'] ??
        r['Id'] ??
        parsedExternalId)?.toString() || null,

    // Tenta várias colunas candidatas para o nome da estação
    name:
      (r['Name'] ??
        r['Station Name'] ??
        parsedNameFromDesig) || null,

    // Morada textual da estação
    address: (r['Address'] as string | null) ?? null,

    // Freguesia/zona (tenta colunas em PT e EN)
    parish:
      ((r['Parish'] as string | null) ??
        (r['Freguesia'] as string | null)) ?? null,

    // Coordenadas já normalizadas
    latitude: lat,
    longitude: lon,

    // Capacidade/docks, tentando múltiplas colunas semânticas
    capacity:
      toNumber(r['Capacity']) ??
      toNumber(r['Docks']) ??
      toNumber(r['Capacidade']) ??
      toNumber(r['numdocas']),

    // Guarda o registo bruto para referência futura/auditoria
    raw: r,
  };
}

/**
 * Seed de estações GIRA na base de dados.
 *
 * Lê um ficheiro Excel com as estações GIRA, deteta a primeira sheet,
 * faz parse para JSON e converte cada linha em `GiraStation`.
 *
 * Comportamento:
 *  - Caminho do ficheiro pode ser sobreposto via env `GIRA_STATIONS_FILE`
 *  - Caso não exista, levanta erro e aborta
 *  - Limpa a tabela `gira_stations`
 *  - Faz inserção por batches para evitar problemas de performance
 */
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

  // Verifica se o ficheiro existe antes de continuar
  if (!fs.existsSync(filePath)) {
    throw new Error(`GIRA stations file not found at path ${filePath}`);
  }

  // Lê o workbook Excel completo
  const workbook = readFile(filePath);
  const [firstSheetName] = workbook.SheetNames;

  if (!firstSheetName) {
    throw new Error('GIRA workbook contains no sheets');
  }

  // Usa a primeira sheet como fonte de dados
  const worksheet = workbook.Sheets[firstSheetName];

  // Converte a sheet inteira para uma lista de objetos (1 por linha)
  const rows = utils.sheet_to_json<Record<string, any>>(worksheet, {
    defval: null, // garante que colunas vazias ficam como null
  });

  console.log(`📄 GIRA rows lidos: ${rows.length}`);

  // Limpa a tabela antes de novo seed (idempotência)
  await prisma.giraStation.deleteMany();
  console.log('🧹 Tabela giraStation limpa.');

  // Inserção em batches para evitar sobrecarga da BD
  for (let i = 0; i < rows.length; i += BATCH_SIZE) {
    const slice = rows.slice(i, i + BATCH_SIZE);
    const data = slice.map(mapRowToStation);

    await prisma.giraStation.createMany({
      data,
      skipDuplicates: true, // no caso de externalId repetidos
    });

    console.log(
      `✅ Inseridos ${Math.min(i + BATCH_SIZE, rows.length)} / ${rows.length}`,
    );
  }

  console.log('🎉 GIRA stations inseridas na BD (batch).');
}

// Execução do script de seed com tratamento de erros
main()
  .catch((e) => {
    console.error('❌ Erro no seed GIRA:', e);
    process.exit(1);
  })
  .finally(async () => {
    // Garante que a ligação Prisma é fechada
    await prisma.$disconnect();
  });
