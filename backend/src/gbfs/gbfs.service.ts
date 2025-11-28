import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { lastValueFrom } from 'rxjs';
import { PrismaService } from '../prisma/prisma.service';
import { StationType } from '@prisma/client';
import {
  GbfsIndexDto,
  GbfsFeedMeta,
} from './dto/gbfs-index.dto';
import { GbfsSystemDto } from './dto/gbfs-system.dto';

@Injectable()
export class GbfsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly http: HttpService,
  ) {}

  // =========================
  //  SISTEMAS (BD)
  // =========================

  async findAllSystems(): Promise<GbfsSystemDto[]> {
    return this.prisma.gbfsSystem.findMany({
      orderBy: { name: 'asc' },
    });
  }

  async findSystemBySystemId(systemId: string): Promise<GbfsSystemDto> {
    const system = await this.prisma.gbfsSystem.findUnique({
      where: { systemId },
    });

    if (!system) {
      throw new NotFoundException(
        `GBFS system with systemId "${systemId}" not found`,
      );
    }

    return system;
  }

  // =========================
  //  GBFS INDEX (gbfs.json)
  // =========================

  async getGbfsIndex(systemId: string): Promise<GbfsIndexDto> {
    const system = await this.findSystemBySystemId(systemId);

    if (!system.autoDiscoveryUrl) {
      throw new BadRequestException(
        `System "${systemId}" does not have an autoDiscoveryUrl`,
      );
    }

    try {
      const response$ = this.http.get<GbfsIndexDto>(system.autoDiscoveryUrl);
      const response = await lastValueFrom(response$);
      return response.data;
    } catch (error) {
      throw new ServiceUnavailableException(
        `Failed to fetch gbfs index for system "${systemId}"`,
      );
    }
  }

  private pickLanguage(
    data: GbfsIndexDto['data'],
    preferredLang?: string,
  ): string {
    const langs = Object.keys(data ?? {});
    if (!langs.length) {
      throw new NotFoundException('No languages available in GBFS index');
    }

    // 1. o idioma pedido, se existir
    if (preferredLang && langs.includes(preferredLang)) return preferredLang;

    // 2. pt se existir
    if (langs.includes('pt')) return 'pt';

    // 3. en se existir
    if (langs.includes('en')) return 'en';

    // 4. senão, o primeiro
    return langs[0];
  }

  async listFeeds(systemId: string, lang?: string): Promise<GbfsFeedMeta[]> {
    const index = await this.getGbfsIndex(systemId);
    const chosenLang = this.pickLanguage(index.data, lang);
    const feeds = index.data[chosenLang]?.feeds ?? [];
    return feeds;
  }

  async getFeed(
    systemId: string,
    feedName: string,
    lang?: string,
  ): Promise<any> {
    const index = await this.getGbfsIndex(systemId);
    const chosenLang = this.pickLanguage(index.data, lang);
    const feeds = index.data[chosenLang]?.feeds ?? [];

    const feed = feeds.find((f) => f.name === feedName);

    if (!feed) {
      throw new NotFoundException(
        `Feed "${feedName}" not found for system "${systemId}" (lang: "${chosenLang}")`,
      );
    }

    try {
      const resp$ = this.http.get(feed.url);
      const resp = await lastValueFrom(resp$);
      return resp.data;
    } catch (error) {
      throw new ServiceUnavailableException(
        `Failed to fetch feed "${feedName}" for system "${systemId}"`,
      );
    }
  }

  // =========================
  //  WRAPPERS DE FEEDS
  // =========================

  // metadados / versões
  async getSystemInformation(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'system_information', lang);
  }

  async getGbfsVersions(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'gbfs_versions', lang);
  }

  // estações / veículos
  async getStationInformation(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'station_information', lang);
  }

  async getStationStatus(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'station_status', lang);
  }

  async getFreeBikeStatus(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'free_bike_status', lang);
  }

  // tipos, preços, regiões, geofencing
  async getVehicleTypes(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'vehicle_types', lang);
  }

  async getPricingPlans(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'system_pricing_plans', lang);
  }

  async getRegions(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'system_regions', lang);
  }

  async getGeofencingZones(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'geofencing_zones', lang);
  }

  // =========================
  //  ESTAÇÕES + STATUS (MEMÓRIA)
  // =========================

  async getStationsWithStatus(systemId: string, lang?: string) {
    const [info, status] = await Promise.all([
      this.getStationInformation(systemId, lang),
      this.getStationStatus(systemId, lang),
    ]);

    const infoStations = info?.data?.stations ?? [];
    const statusStations = status?.data?.stations ?? [];

    const statusById = new Map<string, any>(
      statusStations.map((s: any) => [s.station_id, s]),
    );

    const merged = infoStations.map((s: any) => {
      const st = statusById.get(s.station_id) ?? {};
      return {
        ...s,
        ...(st as any),
      };
    });

    return {
      last_updated: Math.max(info.last_updated ?? 0, status.last_updated ?? 0),
      ttl: Math.min(info.ttl ?? 60, status.ttl ?? 60),
      system_id: systemId,
      data: {
        stations: merged,
      },
    };
  }

  // =========================
  //  SYNC PARA BD (Station)
  // =========================

  async syncStationsFromGbfs(systemId: string, lang?: string) {
    // 1) sistema na BD
    const system = await this.findSystemBySystemId(systemId);

    // 2) info + status do GBFS
    const [info, status] = await Promise.all([
      this.getStationInformation(systemId, lang),
      this.getStationStatus(systemId, lang),
    ]);

    const infoStations = info?.data?.stations ?? [];
    const statusStations = status?.data?.stations ?? [];

    const statusById = new Map<string, any>(
      statusStations.map((s: any) => [s.station_id, s]),
    );

    if (!infoStations.length) {
      return {
        systemId,
        systemDbId: system.id,
        synced: 0,
        message: 'No stations found in station_information feed',
      };
    }

    // 3) preparar upserts
    const upserts = infoStations
      .map((s: any) => {
        const stationId = s.station_id as string | undefined;

        if (!stationId) {
          // se não tiver station_id, ignoramos
          return null;
        }

        const st = statusById.get(stationId) ?? {};

        const latitude = s.lat;
        const longitude = s.lon;
        const name = s.name ?? `Station ${stationId}`;
        const address = s.address ?? null;

        const capacity =
          typeof s.capacity === 'number'
            ? s.capacity
            : typeof st.num_docks_available === 'number'
              ? st.num_docks_available
              : typeof st.num_bikes_available === 'number'
                ? st.num_bikes_available
                : null;

        const availableVehicles =
          typeof st.num_bikes_available === 'number'
            ? st.num_bikes_available
            : null;

        const availableDocks =
          typeof st.num_docks_available === 'number'
            ? st.num_docks_available
            : null;

        return this.prisma.station.upsert({
          where: {
            gbfsSystemId_externalId: {
              gbfsSystemId: system.id,
              externalId: stationId,
            },
          },
          create: {
            name,
            description: null,
            latitude,
            longitude,
            address,
            city: system.location ?? null,
            country: system.countryCode ?? null,
            externalId: stationId,
            stationType: StationType.BIKE_STATION, // troca para SCOOTER_STATION se o sistema for só trotinetes
            isActive: true,
            capacity,
            availableVehicles,
            availableDocks,
            gbfsSystemId: system.id,
          },
          update: {
            name,
            latitude,
            longitude,
            address,
            city: system.location ?? null,
            country: system.countryCode ?? null,
            capacity,
            availableVehicles,
            availableDocks,
            isActive: true,
          },
        });
      })
      .filter(Boolean);

    if (!upserts.length) {
      return {
        systemId,
        systemDbId: system.id,
        synced: 0,
        message: 'No valid stations with station_id to sync',
      };
    }

    // 4) transacção
    await this.prisma.$transaction(upserts as any[]);

    return {
      systemId,
      systemDbId: system.id,
      synced: upserts.length,
    };
  }
}
