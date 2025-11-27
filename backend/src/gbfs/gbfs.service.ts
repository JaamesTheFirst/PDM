import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { lastValueFrom } from 'rxjs';
import { PrismaService } from '../prisma/prisma.service';
import { GbfsIndexDto, GbfsFeedMeta } from './dto/gbfs-index.dto';
import { GbfsSystemDto } from './dto/gbfs-system.dto';

@Injectable()
export class GbfsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly http: HttpService,
  ) {}

  //
  // =============== SISTEMAS (BD) ===============
  //

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

  //
  // =============== GBFS INDEX (auto-discovery) ===============
  //

  /** Vai à BD buscar o sistema e depois faz request ao autoDiscoveryUrl (gbfs.json) */
  async getGbfsIndex(systemId: string): Promise<GbfsIndexDto> {
    const system = await this.findSystemBySystemId(systemId);

    if (!system.autoDiscoveryUrl) {
      throw new BadRequestException(
        `System "${systemId}" does not have an autoDiscoveryUrl`,
      );
    }

    const response$ = this.http.get<GbfsIndexDto>(system.autoDiscoveryUrl);
    const response = await lastValueFrom(response$);

    return response.data;
  }

  /** Decide qual linguagem usar (pt, en, etc.) */
  private pickLanguage(
    data: GbfsIndexDto['data'],
    preferredLang?: string,
  ): string {
    const langs = Object.keys(data ?? {});
    if (!langs.length) {
      throw new NotFoundException('No languages available in GBFS index');
    }

    if (preferredLang && langs.includes(preferredLang)) return preferredLang;
    if (langs.includes('pt')) return 'pt';
    if (langs.includes('en')) return 'en';
    return langs[0];
  }

  /** Devolve a lista de feeds disponíveis para um sistema */
  async listFeeds(systemId: string, lang?: string): Promise<GbfsFeedMeta[]> {
    const index = await this.getGbfsIndex(systemId);
    const chosenLang = this.pickLanguage(index.data, lang);

    const feeds = index.data[chosenLang]?.feeds ?? [];
    return feeds;
  }

  //
  // =============== CORE: FEED GENÉRICO ===============
  //

  /** Vai buscar um feed específico (station_information, station_status, etc.) */
  async getFeed(systemId: string, feedName: string, lang?: string): Promise<any> {
    const index = await this.getGbfsIndex(systemId);
    const chosenLang = this.pickLanguage(index.data, lang);
    const feeds = index.data[chosenLang]?.feeds ?? [];

    const feed = feeds.find((f) => f.name === feedName);

    if (!feed) {
      throw new NotFoundException(
        `Feed "${feedName}" not found for system "${systemId}" (lang: "${chosenLang}")`,
      );
    }

    const resp$ = this.http.get(feed.url);
    const resp = await lastValueFrom(resp$);

    return resp.data;
  }

  //
  // =============== WRAPPERS ESPECÍFICOS POR FEED ===============
  //

  async getSystemInformation(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'system_information', lang);
  }

  async getStationInformation(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'station_information', lang);
  }

  async getStationStatus(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'station_status', lang);
  }

  async getFreeBikeStatus(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'free_bike_status', lang);
  }

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

  async getGbfsVersions(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'gbfs_versions', lang);
  }

  //
  // =============== “BONUS”: ESTAÇÕES + STATUS JUNTO ===============
  //

  /**
   * Junta station_information + station_status e devolve uma lista de estações
   * com disponibilidade, pronto para o frontend usar.
   */
  async getStationsWithStatus(systemId: string, lang?: string) {
    const [info, status] = await Promise.all([
      this.getStationInformation(systemId, lang),
      this.getStationStatus(systemId, lang),
    ]);

    const infoStations = info?.data?.stations ?? [];
    const statusStations = status?.data?.stations ?? [];

    const statusById = new Map(
      statusStations.map((s: any) => [s.station_id, s]),
    );

    const merged = infoStations.map((s: any) => {
      const st = statusById.get(s.station_id);
      return {
        ...s,
        ...(st as any), // num_bikes_available, num_docks_available, etc.
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
}
