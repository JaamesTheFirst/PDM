import {
  Injectable,
  Logger,
  OnModuleInit,
  BadRequestException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { existsSync } from 'fs';
import { readFile, utils } from 'xlsx';
import {
  GiraStationRecordDto,
  GiraStationsSliceDto,
} from './dto';
import { PrismaService } from '../prisma/prisma.service';
import { GiraStation } from '@prisma/client';

@Injectable()
export class GiraService implements OnModuleInit {
  private readonly logger = new Logger(GiraService.name);

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  /**
   * Ao arrancar:
   *  - se a tabela estiver vazia → carrega do ficheiro
   *  - senão → não faz nada (one‑time seed)
   *  - podes forçar com env GIRA_FORCE_RELOAD=true
   */
  async onModuleInit() {
    const forceReload = this.config.get<string>('GIRA_FORCE_RELOAD') === 'true';
    const count = await this.prisma.giraStation.count();

    if (forceReload || count === 0) {
      this.logger.log(
        `Initializing GIRA stations (force=${forceReload}, existing=${count})`,
      );
      try {
        await this.loadStationsFromFile();
      } catch (err) {
        this.logger.error(
          'Error loading GIRA stations on module init',
          (err as Error).stack,
        );
      }
    } else {
      this.logger.log(
        `GIRA stations already present in DB (${count}); skipping file load`,
      );
    }
  }

  /**
   * Lê o ficheiro XLSX/CSV de estações GIRA e sincroniza com a BD.
   * NÃO é chamado sempre – só quando onModuleInit decide ou via POST /gira/stations/reload.
   */
  async loadStationsFromFile(filePathOverride?: string) {
    const filePath =
      filePathOverride ?? this.config.get<string>('GIRA_STATIONS_FILE');

    if (!filePath) {
      this.logger.warn('GIRA_STATIONS_FILE not configured; skipping ingestion');
      return;
    }
    if (!existsSync(filePath)) {
      throw new BadRequestException(
        `GIRA stations file not found at path ${filePath}`,
      );
    }

    this.logger.log(`Loading GIRA stations from ${filePath}`);

    const workbook = readFile(filePath);
    const [firstSheetName] = workbook.SheetNames;
    if (!firstSheetName) {
      throw new BadRequestException('GIRA workbook contains no sheets');
    }

    const worksheet = workbook.Sheets[firstSheetName];
    const rows = utils.sheet_to_json<GiraStationRecordDto>(worksheet, {
      defval: null,
    });

    this.logger.log(`Loaded ${rows.length} GIRA station records from file`);
    await this.syncStationsToDatabase(rows);
  }

  /**
   * Sincroniza as estações lidas do ficheiro com a tabela Prisma GiraStation.
   * Faz delete total + insert em CHUNKS para não rebentar a heap.
   */
  private async syncStationsToDatabase(rows: GiraStationRecordDto[]) {
    this.logger.log('Syncing GIRA stations into database...');

    await this.prisma.giraStation.deleteMany();

    if (!rows.length) {
      this.logger.warn('No GIRA rows to persist; table left empty.');
      return;
    }

    const chunkSize = 5000; // ajusta se quiseres
    const getString = (row: GiraStationRecordDto, key: string): string | null => {
      const v = row[key];
      if (v === null || v === undefined || v === '') return null;
      return String(v);
    };

    const getNumber = (row: GiraStationRecordDto, key: string): number | null => {
      const v = row[key];
      if (v === null || v === undefined || v === '') return null;
      const n = Number(v);
      return Number.isNaN(n) ? null : n;
    };

    for (let i = 0; i < rows.length; i += chunkSize) {
      const chunk = rows.slice(i, i + chunkSize);

      await this.prisma.giraStation.createMany({
        data: chunk.map((r) => ({
          // adapta estes nomes às colunas reais do teu ficheiro GIRA
          externalId:
            getString(r, 'ID') ??
            getString(r, 'Station ID') ??
            getString(r, 'Id'),

          name:
            getString(r, 'Name') ??
            getString(r, 'Station Name'),

          address: getString(r, 'Address'),
          parish:
            getString(r, 'Parish') ??
            getString(r, 'Freguesia'),

          latitude:
            getNumber(r, 'Latitude') ??
            getNumber(r, 'lat') ??
            getNumber(r, 'LAT'),

          longitude:
            getNumber(r, 'Longitude') ??
            getNumber(r, 'lon') ??
            getNumber(r, 'LON'),

          capacity:
            getNumber(r, 'Capacity') ??
            getNumber(r, 'Docks') ??
            getNumber(r, 'Capacidade'),

          raw: r as any,
        })),
        skipDuplicates: true,
      });

      this.logger.log(
        `Inserted GIRA stations ${i}–${Math.min(
          i + chunkSize,
          rows.length,
        )} / ${rows.length}`,
      );
    }

    this.logger.log('✅ GIRA stations synced into database');
  }

  /**
   * Converte um registo Prisma num "GiraStationRecordDto" para manter
   * compatibilidade com o resto do código.
   */
  private toRecordDto(dbRow: GiraStation): GiraStationRecordDto {
    if (dbRow.raw) {
      return dbRow.raw as GiraStationRecordDto;
    }

    const record: GiraStationRecordDto = {};
    if (dbRow.externalId) record['ID'] = dbRow.externalId;
    if (dbRow.name) record['Name'] = dbRow.name;
    if (dbRow.address) record['Address'] = dbRow.address;
    if (dbRow.parish) record['Parish'] = dbRow.parish;
    if (dbRow.latitude != null) record['Latitude'] = dbRow.latitude;
    if (dbRow.longitude != null) record['Longitude'] = dbRow.longitude;
    if (dbRow.capacity != null) record['Capacity'] = dbRow.capacity;
    return record;
  }

  /**
   * Paginação – tudo a vir da BD.
   */
  async getStationsSlice(
    limit = 100,
    offset = 0,
  ): Promise<GiraStationsSliceDto> {
    const safeLimit = Math.min(Math.max(limit, 1), 1000);
    const safeOffset = Math.max(offset, 0);

    const [total, rows] = await this.prisma.$transaction([
      this.prisma.giraStation.count(),
      this.prisma.giraStation.findMany({
        skip: safeOffset,
        take: safeLimit,
        orderBy: { id: 'asc' },
      }),
    ]);

    return {
      total,
      slice: rows.map((r) => this.toRecordDto(r)),
    };
  }

  /**
   * Search: em vez de carregar 900k linhas e filtrar à mão,
   * usamos campos específicos no Prisma.
   */
  async searchStations(field: string, value: string): Promise<GiraStationRecordDto[]> {
    if (!field || !value) {
      throw new BadRequestException(
        'Both "field" and "value" query parameters are required',
      );
    }

    const normalizedField = field.toLowerCase().trim();

    const fieldMap: Record<string, keyof GiraStation> = {
      name: 'name',
      externalid: 'externalId',
      address: 'address',
      parish: 'parish',
    };

    const prismaField = fieldMap[normalizedField];
    if (!prismaField) {
      throw new BadRequestException(
        `Unsupported search field "${field}". Use one of: ${Object.keys(
          fieldMap,
        ).join(', ')}`,
      );
    }

    const rows = await this.prisma.giraStation.findMany({
      where: {
        [prismaField]: {
          contains: value,
          mode: 'insensitive',
        } as any,
      },
      orderBy: { id: 'asc' },
      take: 500, // safety limit
    });

    return rows.map((r) => this.toRecordDto(r));
  }
}
