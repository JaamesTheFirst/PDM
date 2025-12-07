// backend/src/gbfs/gbfs.service.ts
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

/**
 * Serviço de integração GBFS.
 *
 * Funções principais:
 *  - gerir/consultar sistemas GBFS registados na BD
 *  - fazer proxy a `gbfs.json` e restantes feeds
 *  - agregar feeds (stations + status + free_bike_status)
 *  - sincronizar estações GBFS para a tabela `stations` (Prisma)
 */
@Injectable()
export class GbfsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly http: HttpService,
  ) {}

  // =========================
  //  SISTEMAS (BD)
  // =========================

  /**
   * Lista todos os sistemas GBFS definidos em `gbfs_systems`,
   * ordenados alfabeticamente pelo nome.
   */
  async findAllSystems(): Promise<GbfsSystemDto[]> {
    return this.prisma.gbfsSystem.findMany({
      orderBy: { name: 'asc' },
    });
  }

  /**
   * Obtém um sistema GBFS pelo campo lógico `systemId`.
   *
   * @throws NotFoundException se o sistema não existir.
   */
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

  /**
   * Obtém o índice GBFS (`gbfs.json`) de um sistema, usando o `autoDiscoveryUrl`.
   *
   * @throws BadRequestException se o sistema não tiver `autoDiscoveryUrl` definido.
   * @throws ServiceUnavailableException se o fetch ao operador falhar.
   */
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

  /**
   * Escolhe o idioma mais adequado dentro do `data` de um índice GBFS.
   *
   * Ordem de preferência:
   *  1. idioma pedido (se existir)
   *  2. "pt"
   *  3. "en"
   *  4. primeiro idioma disponível
   */
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

  /**
   * Lista os feeds disponíveis para um determinado sistema+idioma.
   */
  async listFeeds(systemId: string, lang?: string): Promise<GbfsFeedMeta[]> {
    const index = await this.getGbfsIndex(systemId);
    const chosenLang = this.pickLanguage(index.data, lang);
    const feeds = index.data[chosenLang]?.feeds ?? [];
    return feeds;
  }

  /**
   * Obtém (proxy) um feed GBFS específico por nome.
   *
   * @param systemId ID lógico do sistema (campo `systemId`)
   * @param feedName Nome do feed (ex.: "station_information")
   * @param lang Idioma (opcional – usa `pickLanguage` se não for fornecido)
   *
   * @throws NotFoundException se o feed não existir para o idioma escolhido
   * @throws ServiceUnavailableException em caso de falha ao fazer fetch
   */
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

  /**
   * Wrapper para o feed `system_information`.
   */
  async getSystemInformation(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'system_information', lang);
  }

  /**
   * Wrapper para o feed `gbfs_versions`.
   */
  async getGbfsVersions(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'gbfs_versions', lang);
  }

  // estações / veículos

  /**
   * Wrapper para o feed `station_information`.
   */
  async getStationInformation(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'station_information', lang);
  }

  /**
   * Wrapper para o feed `station_status`.
   */
  async getStationStatus(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'station_status', lang);
  }

  /**
   * Wrapper para o feed `free_bike_status`.
   */
  async getFreeBikeStatus(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'free_bike_status', lang);
  }

  // tipos, preços, regiões, geofencing

  /**
   * Wrapper para o feed `vehicle_types`.
   */
  async getVehicleTypes(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'vehicle_types', lang);
  }

  /**
   * Wrapper para o feed `system_pricing_plans`.
   */
  async getPricingPlans(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'system_pricing_plans', lang);
  }

  /**
   * Wrapper para o feed `system_regions`.
   */
  async getRegions(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'system_regions', lang);
  }

  /**
   * Wrapper para o feed `geofencing_zones`.
   */
  async getGeofencingZones(systemId: string, lang?: string) {
    return this.getFeed(systemId, 'geofencing_zones', lang);
  }

  // =========================
  //  ESTAÇÕES + STATUS (MEMÓRIA)
  // =========================

  /**
   * Faz o merge de `station_information` + `station_status` em memória,
   * sem tocar na BD, e devolve um objeto no espírito da especificação GBFS.
   */
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
  //  AVAILABILITY (stations + free bikes)
  // =========================

  /**
   * Versão "tolerante a falhas" de `getStationsWithStatus`.
   *
   * Em caso de NotFound/ServiceUnavailable, devolve `null`
   * em vez de propagar o erro (para permitir fallback parcial
   * noutros endpoints como `getAvailability`).
   */
  private async safeGetStationsWithStatus(systemId: string, lang?: string) {
    try {
      return await this.getStationsWithStatus(systemId, lang);
    } catch (err) {
      // se o sistema não tiver stations ou o feed falhar,
      // tratamos como "sem estações" para este endpoint
      if (
        err instanceof NotFoundException ||
        err instanceof ServiceUnavailableException
      ) {
        return null;
      }
      throw err;
    }
  }

  /**
   * Versão "tolerante a falhas" de `getFreeBikeStatus`.
   */
  private async safeGetFreeBikeStatus(systemId: string, lang?: string) {
    try {
      return await this.getFreeBikeStatus(systemId, lang);
    } catch (err) {
      // idem para free_bike_status
      if (
        err instanceof NotFoundException ||
        err instanceof ServiceUnavailableException
      ) {
        return null;
      }
      throw err;
    }
  }

  /**
   * Agregado de disponibilidade: estações (info + status) + bikes livres.
   *
   * Combina `last_updated` e `ttl` dos feeds envolvidos, escolhendo:
   *  - last_updated = máximo (mais recente)
   *  - ttl = mínimo (mais conservador para cache)
   */
  async getAvailability(systemId: string, lang?: string) {
    const [stationsResp, freeBikesResp] = await Promise.all([
      this.safeGetStationsWithStatus(systemId, lang),
      this.safeGetFreeBikeStatus(systemId, lang),
    ]);

    const stations = stationsResp?.data?.stations ?? [];

    // alguns sistemas usam data.bikes, outros data.vehicles
    const fbData = freeBikesResp?.data ?? {};
    const freeBikes = Array.isArray(fbData.bikes)
      ? fbData.bikes
      : Array.isArray(fbData.vehicles)
        ? fbData.vehicles
        : [];

    // last_updated / ttl combinados
    const lastUpdatedCandidates: number[] = [];
    if (typeof stationsResp?.last_updated === 'number') {
      lastUpdatedCandidates.push(stationsResp.last_updated);
    }
    if (typeof freeBikesResp?.last_updated === 'number') {
      lastUpdatedCandidates.push(freeBikesResp.last_updated);
    }

    const ttlCandidates: number[] = [];
    if (typeof stationsResp?.ttl === 'number') {
      ttlCandidates.push(stationsResp.ttl);
    }
    if (typeof freeBikesResp?.ttl === 'number') {
      ttlCandidates.push(freeBikesResp.ttl);
    }

    const nowSeconds = Math.floor(Date.now() / 1000);

    const last_updated =
      lastUpdatedCandidates.length > 0
        ? Math.max(...lastUpdatedCandidates)
        : nowSeconds;

    const ttl =
      ttlCandidates.length > 0 ? Math.min(...ttlCandidates) : 60;

    return {
      system_id: systemId,
      last_updated,
      ttl,
      data: {
        stations,
        free_bikes: freeBikes,
      },
    };
  }

  // =========================
  //  SYNC PARA BD (Station)
  // =========================

  /**
   * Sincroniza estações de um sistema GBFS para a tabela `stations`,
   * usando upsert por `(gbfsSystemId, externalId)`.
   *
   * - Lê `station_information` e `station_status`
   * - Infere `capacity`, `availableVehicles` e `availableDocks` quando possível
   * - Marca todas as estações como ativas (`isActive = true`)
   */
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

    // 4) transacção de upserts
    await this.prisma.$transaction(upserts as any[]);

    return {
      systemId,
      systemDbId: system.id,
      synced: upserts.length,
    };
  }
}
