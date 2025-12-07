// src/cp/cp.service.ts
import {
  Injectable,
  Logger,
  ServiceUnavailableException,
  NotFoundException,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import {
  CpVehicleDto,
  CpVehiclesApiResponse,
  CpGraphRouteDto,
  CpGraphRouteDetailDto,
  CpStopBasicDto,
  CpStopSearchResultDto,
  CpStopDeparturesDto,
  CpDepartureDto,
  CpStopBoardDto,
  CpStopBoardRowDto,
} from './dto';

/**
 * Erro simples do GraphQL GTFS (OTP).
 */
interface GtfsGraphQlError {
  message: string;
}

/**
 * Estrutura de resposta para query de rotas GTFS.
 */
interface GtfsRoutesResponse {
  data?: {
    routes: Array<{
      gtfsId: string;
      shortName?: string | null;
      longName?: string | null;
      mode: string;
      agency?: {
        gtfsId?: string | null;
        name?: string | null;
      } | null;
    }>;
  };
  errors?: GtfsGraphQlError[];
}

/**
 * Estrutura de resposta para detalhe de uma rota GTFS.
 */
interface GtfsRouteDetailResponse {
  data?: {
    route: {
      gtfsId: string;
      shortName?: string | null;
      longName?: string | null;
      mode: string;
      agency?: {
        gtfsId?: string | null;
        name?: string | null;
      } | null;
      patterns: Array<{
        stops: Array<{
          gtfsId: string;
          name: string;
          lat?: number;
          lon?: number;
        }>;
      }>;
    } | null;
  };
  errors?: GtfsGraphQlError[];
}

/**
 * Estrutura de resposta para pesquisa de stops GTFS.
 */
interface GtfsStopsSearchResponse {
  data?: {
    stops: Array<{
      gtfsId: string;
      name: string;
      lat?: number;
      lon?: number;
    }>;
  };
  errors?: GtfsGraphQlError[];
}

/**
 * Estrutura de resposta para partidas por paragem GTFS.
 */
interface GtfsStopDeparturesResponse {
  data?: {
    stop: {
      gtfsId: string;
      name: string;
      lat?: number;
      lon?: number;
      stoptimesForPatterns: Array<{
        pattern: {
          headsign?: string | null;
          route?: {
            gtfsId: string;
            shortName?: string | null;
            longName?: string | null;
            mode: string;
            agency?: {
              gtfsId?: string | null;
              name?: string | null;
            } | null;
          } | null;
        } | null;
        stoptimes: Array<{
          scheduledDeparture: number;
          realtimeDeparture: number;
          realtime: boolean;
          serviceDay: number;
          headsign?: string | null;
        }>;
      }>;
    } | null;
  };
  errors?: GtfsGraphQlError[];
}

// ===== GraphQL queries (OTP/GTFS) =====

/**
 * Query para listar todas as rotas do grafo GTFS.
 */
const ROUTES_QUERY = `
  query Routes {
    routes {
      gtfsId
      shortName
      longName
      mode
      agency {
        gtfsId
        name
      }
    }
  }
`;

/**
 * Query para obter detalhe de uma rota (inclui padrões e paragens).
 */
const ROUTE_DETAIL_QUERY = `
  query RouteDetail($id: String!) {
    route(id: $id) {
      gtfsId
      shortName
      longName
      mode
      agency {
        gtfsId
        name
      }
      patterns {
        stops {
          gtfsId
          name
          lat
          lon
        }
      }
    }
  }
`;

/**
 * Query para pesquisa de paragens pelo nome.
 */
const STOPS_SEARCH_QUERY = `
  query StopsSearch($name: String!) {
    stops(name: $name) {
      gtfsId
      name
      lat
      lon
    }
  }
`;

/**
 * Query para obter partidas por paragem.
 */
const STOP_DEPARTURES_QUERY = `
  query StopDepartures(
    $stopId: String!,
    $startTime: Long!,
    $timeRange: Int!,
    $numberOfDepartures: Int!
  ) {
    stop(id: $stopId) {
      gtfsId
      name
      lat
      lon
      stoptimesForPatterns(
        startTime: $startTime,
        timeRange: $timeRange,
        numberOfDepartures: $numberOfDepartures
      ) {
        pattern {
          headsign
          route {
            gtfsId
            shortName
            longName
            mode
            agency {
              gtfsId
              name
            }
          }
        }
        stoptimes {
          scheduledDeparture
          realtimeDeparture
          realtime
          serviceDay
          headsign
        }
      }
    }
  }
`;

/**
 * Serviço responsável por integrar:
 *  - API comboios.live (veículos em tempo real)
 *  - grafo GTFS da CP via OTP GraphQL
 *
 * Expõe métodos para obter:
 *  - veículos em realtime
 *  - rotas CP
 *  - pesquisa de estações
 *  - partidas por estação (raw e formatadas)
 */
@Injectable()
export class CpService {
  private readonly logger = new Logger(CpService.name);

  // cache da API comboios.live
  private vehiclesCache: CpVehicleDto[] = [];
  private cacheTimestamp = 0;

  constructor(
    private readonly http: HttpService,
    private readonly configService: ConfigService,
  ) {}

  // ===== CONFIG / URLs =====

  /**
   * URL base da API de veículos CP (comboios.live),
   * sobreponível via env `CP_VEHICLES_API_URL`.
   */
  private get vehiclesApiUrl(): string {
    return (
      this.configService.get<string>('CP_VEHICLES_API_URL') ||
      'https://comboios.live/api/vehicles'
    );
  }

  /**
   * TTL (em ms) da cache de veículos realtime.
   * Configurável com `CP_VEHICLES_CACHE_TTL_MS`, default 30s.
   */
  private get cacheTtlMs(): number {
    const configured = this.configService.get<number>(
      'CP_VEHICLES_CACHE_TTL_MS',
    );
    return configured ?? 30_000;
  }

  /**
   * URL do endpoint GraphQL do OTP (router default).
   */
  private get otpGraphQlUrl(): string {
    const base =
      this.configService.get<string>('OTP_BASE_URL') ||
      'http://localhost:8080/otp';
    return `${base.replace(/\/$/, '')}/routers/default/index/graphql`;
  }

  // ===== COMBOIOS.LIVE (REALTIME VEHICLES) =====

  /**
   * Faz o pedido direto à API comboios.live para obter veículos.
   */
  private async fetchVehicles(): Promise<CpVehicleDto[]> {
    const { data } = await firstValueFrom(
      this.http.get<CpVehiclesApiResponse>(this.vehiclesApiUrl),
    );
    return data.vehicles ?? [];
  }

  /**
   * Obtém a lista de veículos CP em tempo real, com cache simples.
   *
   * @param forceRefresh Se `true`, ignora cache e vai sempre à API upstream.
   */
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
      // fallback para cache se existir
      if (this.vehiclesCache.length > 0) {
        this.logger.warn('Serving cached CP vehicles due to upstream failure');
        return this.vehiclesCache;
      }
      throw new ServiceUnavailableException('Failed to fetch CP vehicles');
    }
  }

  /**
   * Obtém um veículo específico pelo número do comboio.
   *
   * @param trainNumber Número do comboio
   * @returns Veículo ou `undefined` se não estiver no feed atual.
   */
  async getVehicle(trainNumber: string): Promise<CpVehicleDto | undefined> {
    const vehicles = await this.getVehicles();
    return vehicles.find(
      (vehicle) => String(vehicle.trainNumber) === String(trainNumber),
    );
  }

  // ===== OTP (GRAFO GTFS) – LINHAS CP =====

  /**
   * Lista todas as rotas CP presentes no grafo OTP.
   *
   * Filtro:
   *  - modo "RAIL"/"TRAIN"
   *  - ou agência cujo nome pareça "Comboios de Portugal" / "CP ..."
   */
  async getCpRoutesFromGraph(): Promise<CpGraphRouteDto[]> {
    try {
      const response = await firstValueFrom(
        this.http.post<GtfsRoutesResponse>(
          this.otpGraphQlUrl,
          {
            query: ROUTES_QUERY,
          },
          {
            headers: { 'Content-Type': 'application/json' },
          },
        ),
      );

      if (response.data.errors && response.data.errors.length > 0) {
        this.logger.error(
          response.data.errors.map((e) => e.message).join('; '),
        );
        throw new ServiceUnavailableException('OTP returned an error');
      }

      const routes = response.data.data?.routes ?? [];

      const cpRoutes = routes.filter((r) => {
        const agencyName = (r.agency?.name || '').toLowerCase();
        const isRail = r.mode === 'RAIL' || r.mode === 'TRAIN';
        const isCp =
          agencyName.includes('comboios de portugal') ||
          agencyName.startsWith('cp ');
        return isRail || isCp;
      });

      return cpRoutes.map((r) => ({
        gtfsId: r.gtfsId,
        shortName: r.shortName ?? null,
        longName: r.longName ?? null,
        mode: r.mode,
        agencyName: r.agency?.name ?? null,
        agencyGtfsId: r.agency?.gtfsId ?? null,
      }));
    } catch (error) {
      this.logger.error('Failed to fetch CP routes from OTP', error as any);
      throw new ServiceUnavailableException(
        'Failed to fetch CP routes from OTP',
      );
    }
  }

  /**
   * Obtém detalhe de uma rota CP (incluindo paragens).
   *
   * @param routeGtfsId ID GTFS da rota
   * @throws NotFoundException se a rota não existir no grafo
   */
  async getCpRouteDetail(routeGtfsId: string): Promise<CpGraphRouteDetailDto> {
    try {
      const response = await firstValueFrom(
        this.http.post<GtfsRouteDetailResponse>(
          this.otpGraphQlUrl,
          {
            query: ROUTE_DETAIL_QUERY,
            variables: { id: routeGtfsId },
          },
          {
            headers: { 'Content-Type': 'application/json' },
          },
        ),
      );

      if (response.data.errors && response.data.errors.length > 0) {
        this.logger.error(
          response.data.errors.map((e) => e.message).join('; '),
        );
        throw new ServiceUnavailableException('OTP returned an error');
      }

      const route = response.data.data?.route;
      if (!route) {
        throw new NotFoundException(
          `Route ${routeGtfsId} not found in OTP graph`,
        );
      }

      // juntar stops de todos os patterns (deduplicados por gtfsId)
      const stopsMap = new Map<string, CpStopBasicDto>();
      for (const pattern of route.patterns || []) {
        for (const st of pattern.stops || []) {
          if (!stopsMap.has(st.gtfsId)) {
            stopsMap.set(st.gtfsId, {
              gtfsId: st.gtfsId,
              name: st.name,
              lat: st.lat,
              lon: st.lon,
            });
          }
        }
      }

      return {
        gtfsId: route.gtfsId,
        shortName: route.shortName ?? null,
        longName: route.longName ?? null,
        mode: route.mode,
        agencyName: route.agency?.name ?? null,
        agencyGtfsId: route.agency?.gtfsId ?? null,
        stops: Array.from(stopsMap.values()),
      };
    } catch (error) {
      this.logger.error(
        `Failed to fetch CP route detail ${routeGtfsId} from OTP`,
        error as any,
      );
      throw new ServiceUnavailableException(
        'Failed to fetch CP route detail from OTP',
      );
    }
  }

  // ===== OTP (GRAFO GTFS) – SEARCH DE STOPS =====

  /**
   * Pesquisa de estações CP pelo nome.
   *
   * @param q Termo de pesquisa
   * @param limit Máximo de resultados
   */
  async searchStops(q: string, limit = 10): Promise<CpStopSearchResultDto[]> {
    if (!q || q.trim().length === 0) return [];

    try {
      const response = await firstValueFrom(
        this.http.post<GtfsStopsSearchResponse>(
          this.otpGraphQlUrl,
          {
            query: STOPS_SEARCH_QUERY,
            variables: { name: q },
          },
          {
            headers: { 'Content-Type': 'application/json' },
          },
        ),
      );

      if (response.data.errors && response.data.errors.length > 0) {
        this.logger.error(
          response.data.errors.map((e) => e.message).join('; '),
        );
        throw new ServiceUnavailableException('OTP returned an error');
      }

      const stops = response.data.data?.stops ?? [];
      const trimmed = stops.slice(0, limit);

      return trimmed.map((s) => ({
        gtfsId: s.gtfsId,
        name: s.name,
        lat: s.lat,
        lon: s.lon,
      }));
    } catch (error) {
      this.logger.error('Failed to search stops in OTP', error as any);
      throw new ServiceUnavailableException('Failed to search stops in OTP');
    }
  }

  // ===== OTP (GRAFO GTFS) – PARTIDAS POR PARAGEM =====

  /**
   * Obtém partidas brutas (GTFS) a partir do grafo para uma paragem.
   *
   * @param stopGtfsId ID GTFS da paragem
   * @param opts Opções de janela temporal e nº de partidas
   */
  async getStopDeparturesFromGraph(
    stopGtfsId: string,
    opts?: {
      /** Epoch seconds de início da janela; se omitido usa `now` */
      startTime?: number;
      /** Janela temporal em segundos (default: 3600) */
      timeRange?: number;
      /** Nº máximo de partidas (default: 20) */
      numberOfDepartures?: number;
    },
  ): Promise<CpStopDeparturesDto> {
    const nowSeconds = Math.floor(Date.now() / 1000);

    const startTime = opts?.startTime ?? nowSeconds;
    const timeRange = opts?.timeRange ?? 3600;
    const numberOfDepartures = opts?.numberOfDepartures ?? 20;

    try {
      const response = await firstValueFrom(
        this.http.post<GtfsStopDeparturesResponse>(
          this.otpGraphQlUrl,
          {
            query: STOP_DEPARTURES_QUERY,
            variables: {
              stopId: stopGtfsId,
              startTime,
              timeRange,
              numberOfDepartures,
            },
          },
          {
            headers: { 'Content-Type': 'application/json' },
          },
        ),
      );

      if (response.data.errors && response.data.errors.length > 0) {
        this.logger.error(
          response.data.errors.map((e) => e.message).join('; '),
        );
        throw new ServiceUnavailableException('OTP returned an error');
      }

      const stop = response.data.data?.stop;
      if (!stop) {
        throw new NotFoundException(
          `Stop ${stopGtfsId} not found in OTP graph`,
        );
      }

      const departures: CpDepartureDto[] = [];

      for (const patternRow of stop.stoptimesForPatterns || []) {
        const route = patternRow.pattern?.route;
        const patternHeadsign = patternRow.pattern?.headsign ?? undefined;
        const agencyName = route?.agency?.name ?? undefined;

        // Filtra para rail/CP
        const isRail =
          route?.mode === 'RAIL' || route?.mode === 'TRAIN';
        const isCp =
          (agencyName || '').toLowerCase().includes('comboios de portugal') ||
          (agencyName || '').toLowerCase().startsWith('cp ');

        if (!isRail && !isCp) {
          continue;
        }

        for (const st of patternRow.stoptimes || []) {
          departures.push({
            routeGtfsId: route?.gtfsId,
            routeShortName: route?.shortName ?? null,
            routeLongName: route?.longName ?? null,
            mode: route?.mode ?? 'RAIL',
            agencyName,
            headsign: st.headsign ?? patternHeadsign ?? undefined,
            scheduledDeparture: st.scheduledDeparture,
            realtimeDeparture: st.realtimeDeparture,
            realtime: st.realtime,
            serviceDay: st.serviceDay,
          });
        }
      }

      return {
        stopId: stop.gtfsId,
        stopName: stop.name,
        lat: stop.lat,
        lon: stop.lon,
        departures,
      };
    } catch (error) {
      this.logger.error(
        `Failed to fetch departures for stop ${stopGtfsId} from OTP`,
        error as any,
      );
      throw new ServiceUnavailableException(
        'Failed to fetch departures for this stop from OTP',
      );
    }
  }

  // ===== “BOARD” PARA UI – HORÁRIOS FORMATADOS =====

  /**
   * Constrói um "quadro de partidas" formatado para UI
   * a partir dos dados brutos de `getStopDeparturesFromGraph`.
   */
  async getStopBoard(
    stopGtfsId: string,
    opts?: {
      startTime?: number;
      timeRange?: number;
      numberOfDepartures?: number;
    },
  ): Promise<CpStopBoardDto> {
    const raw = await this.getStopDeparturesFromGraph(stopGtfsId, opts);

    const rows: CpStopBoardRowDto[] = raw.departures
      .map((d) => {
        const departureEpochSeconds = d.serviceDay + d.realtimeDeparture;
        const scheduledEpochSeconds = d.serviceDay + d.scheduledDeparture;

        const date = new Date(departureEpochSeconds * 1000);
        const hh = String(date.getHours()).padStart(2, '0');
        const mm = String(date.getMinutes()).padStart(2, '0');
        const time = `${hh}:${mm}`;

        const delaySeconds =
          d.realtimeDeparture - d.scheduledDeparture;
        const delayMinutes = Math.round(delaySeconds / 60);

        return {
          time,
          destination: d.headsign ?? null,
          lineShortName: d.routeShortName ?? null,
          lineLongName: d.routeLongName ?? null,
          routeGtfsId: d.routeGtfsId,
          delayMinutes,
          isRealtime: d.realtime,
        } as CpStopBoardRowDto;
      })
      // ordenar por hora textual ("HH:MM") – suficiente para janela curta
      .sort((a, b) => (a.time < b.time ? -1 : a.time > b.time ? 1 : 0));

    return {
      stopId: raw.stopId,
      stopName: raw.stopName,
      lat: raw.lat,
      lon: raw.lon,
      departures: rows,
    };
  }
}
