import { Injectable, Logger, ServiceUnavailableException } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { CpVehicleDto, CpVehiclesApiResponse } from './dto';

@Injectable()
export class CpService {
  private readonly logger = new Logger(CpService.name);
  private vehiclesCache: CpVehicleDto[] = [];
  private cacheTimestamp = 0;

  constructor(
    private readonly http: HttpService,
    private readonly configService: ConfigService,
  ) {}

  private get apiUrl(): string {
    return (
      this.configService.get<string>('CP_VEHICLES_API_URL') ||
      'https://comboios.live/api/vehicles'
    );
  }

  private get cacheTtlMs(): number {
    const configured = this.configService.get<number>(
      'CP_VEHICLES_CACHE_TTL_MS',
    );
    return configured ?? 30_000;
  }

  private async fetchVehicles(): Promise<CpVehicleDto[]> {
    const { data } = await firstValueFrom(
      this.http.get<CpVehiclesApiResponse>(this.apiUrl),
    );
    return data.vehicles ?? [];
  }

  async getVehicles(forceRefresh = false): Promise<CpVehicleDto[]> {
    const cacheIsFresh =
      Date.now() - this.cacheTimestamp < this.cacheTtlMs &&
      this.vehiclesCache.length > 0;

    if (!forceRefresh && cacheIsFresh) {
      return this.vehiclesCache;
    }

    try {
      this.vehiclesCache = await this.fetchVehicles();
      this.cacheTimestamp = Date.now();
      return this.vehiclesCache;
    } catch (error) {
      this.logger.error('Failed to fetch CP vehicles', error as any);
      if (this.vehiclesCache.length > 0) {
        this.logger.warn('Serving cached CP vehicles due to upstream failure');
        return this.vehiclesCache;
      }
      throw new ServiceUnavailableException('Failed to fetch CP vehicles');
    }
  }

  async getVehicle(trainNumber: string): Promise<CpVehicleDto | undefined> {
    const vehicles = await this.getVehicles();
    return vehicles.find(
      (vehicle) => String(vehicle.trainNumber) === String(trainNumber),
    );
  }
}

