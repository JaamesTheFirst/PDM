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

@Injectable()
export class GiraService implements OnModuleInit {
  private readonly logger = new Logger(GiraService.name);
  private stations: GiraStationRecordDto[] = [];

  constructor(private readonly config: ConfigService) {}

  async onModuleInit() {
    await this.loadStationsFromFile();
  }

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

    this.stations = rows;
    this.logger.log(`Loaded ${this.stations.length} GIRA station records`);
  }

  getStations(): GiraStationRecordDto[] {
    return this.stations;
  }

  getStationsSlice(limit = 100, offset = 0): GiraStationsSliceDto {
    const safeLimit = Math.min(Math.max(limit, 1), 1000);
    const safeOffset = Math.max(offset, 0);
    const slice = this.stations.slice(safeOffset, safeOffset + safeLimit);
    return { total: this.stations.length, slice };
  }

  searchStations(field: string, value: string): GiraStationRecordDto[] {
    if (!field || !value) {
      throw new BadRequestException(
        'Both "field" and "value" query parameters are required',
      );
    }
    const normalizedField = field.toLowerCase();
    return this.stations.filter((record) => {
      const recordKeys = Object.keys(record);
      const key = recordKeys.find(
        (k) => k.toLowerCase().trim() === normalizedField,
      );
      if (!key) {
        return false;
      }
      const recordValue = record[key];
      if (recordValue === null || recordValue === undefined) {
        return false;
      }
      return String(recordValue).toLowerCase() === value.toLowerCase();
    });
  }
}

