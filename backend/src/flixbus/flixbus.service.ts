// src/flixbus/flixbus.service.ts
import { Injectable, Logger, ServiceUnavailableException, NotFoundException } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import {
  FlixbusGraphRouteDto,
  FlixbusGraphRouteDetailDto,
  FlixbusStopBasicDto,
  FlixbusStopSearchResultDto,
  FlixbusStopDeparturesDto,
  FlixbusDepartureDto,
  FlixbusStopBoardDto,
  FlixbusStopBoardRowDto,
} from './dto';

/**
 * Estrutura de erro GraphQL simples, tal como devolvida pelo OTP.
 */
interface GtfsGraphQlError {
  message: string;
}

/**
 * Resposta GraphQL para listagem de rotas.
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
 * Resposta GraphQL para detalhe de rota (inclui padrões e paragens).
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
 * Resposta GraphQL para pesquisa de paragens.
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
 * Resposta GraphQL para partidas por paragem.
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
 * Query para listar todas as rotas presentes no grafo GTFS.
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
 * Query para obter detalhe de uma rota específica, incluindo padrões/paragens.
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
 * Query para pesquisar paragens pelo nome.
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
 * Query para obter partidas numa paragem, com parâmetros de janela temporal.
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
 * Serviço responsável por integrar com o grafo OTP/GTFS
 * e expor dados específicos de FlixBus (rotas, paragens, partidas).
 */
@Injectable()
export class FlixbusService {
  private readonly logger = new Logger(FlixbusService.name);

  constructor(
    private readonly http: HttpService,
    private readonly configService: ConfigService,
  ) {}

  // ===== CONFIG / URLs =====

  /**
   * URL do endpoint GraphQL do OTP (router "default").
   */
  private get otpGraphQlUrl(): string {
    const base = this.configService.get<string>('OTP_BASE_URL') || 'http://localhost:8080/otp';
    return `${base.replace(/\/$/, '')}/routers/default/index/graphql`;
  }

  // ===== HELPERS PARA FILTRAR FLIXBUS =====

  /**
   * Verifica se uma rota GTFS pertence à FlixBus.
   *
   * Critérios:
   *  - modo BUS/COACH
   *  - e nome/ID da agência contém algo tipo "flixbus" / "flix"
   */
  private isFlixbusRoute(
    mode?: string,
    agencyName?: string | null,
    agencyGtfsId?: string | null,
  ): boolean {
    const m = (mode || '').toUpperCase();
    const name = (agencyName || '').toLowerCase();
    const agId = (agencyGtfsId || '').toLowerCase();

    const isCoachOrBus = m === 'BUS' || m === 'COACH';
    const isFlixName =
      name.includes('flixbus') || name.includes('flix bus') || name.includes('flix');
    const isFlixId = agId.includes('flixbus') || agId.includes('flix');

    return isCoachOrBus && (isFlixName || isFlixId);
  }

  // ===== OTP (GRAFO GTFS) – LINHAS FLIXBUS =====

  /**
   * Lista todas as rotas FlixBus presentes no grafo OTP.
   */
  async getFlixbusRoutesFromGraph(): Promise<FlixbusGraphRouteDto[]> {
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
        this.logger.error(response.data.errors.map(e => e.message).join('; '));
        throw new ServiceUnavailableException('OTP returned an error');
      }

      const routes = response.data.data?.routes ?? [];

      const flixRoutes = routes.filter(r =>
        this.isFlixbusRoute(r.mode, r.agency?.name ?? null, r.agency?.gtfsId ?? null),
      );

      return flixRoutes.map(r => ({
        gtfsId: r.gtfsId,
        shortName: r.shortName ?? null,
        longName: r.longName ?? null,
        mode: r.mode,
        agencyName: r.agency?.name ?? null,
        agencyGtfsId: r.agency?.gtfsId ?? null,
      }));
    } catch (error) {
      this.logger.error('Failed to fetch FlixBus routes from OTP', error as any);
      throw new ServiceUnavailableException('Failed to fetch FlixBus routes from OTP');
    }
  }

  /**
   * Obtém o detalhe de uma rota FlixBus específica, incluindo paragens.
   *
   * @param routeGtfsId ID GTFS da rota
   * @throws NotFoundException se a rota não existir ou não for FlixBus
   */
  async getFlixbusRouteDetail(routeGtfsId: string): Promise<FlixbusGraphRouteDetailDto> {
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
        this.logger.error(response.data.errors.map(e => e.message).join('; '));
        throw new ServiceUnavailableException('OTP returned an error');
      }

      const route = response.data.data?.route;
      if (!route) {
        throw new NotFoundException(`Route ${routeGtfsId} not found in OTP graph`);
      }

      // opcional: garantir que esta route é mesmo FlixBus
      if (
        !this.isFlixbusRoute(route.mode, route.agency?.name ?? null, route.agency?.gtfsId ?? null)
      ) {
        throw new NotFoundException(`Route ${routeGtfsId} is not a FlixBus route`);
      }

      // juntar stops de todos os patterns (deduplicado por gtfsId)
      const stopsMap = new Map<string, FlixbusStopBasicDto>();
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
        `Failed to fetch FlixBus route detail ${routeGtfsId} from OTP`,
        error as any,
      );
      throw new ServiceUnavailableException('Failed to fetch FlixBus route detail from OTP');
    }
  }

  // ===== OTP (GRAFO GTFS) – SEARCH DE STOPS =====
  // aqui não filtramos por FlixBus, tal como em CP: a filtragem é feita nas partidas

  /**
   * Pesquisa paragens pelo nome, para autocomplete.
   *
   * @param q Termo de pesquisa
   * @param limit Máximo de resultados
   */
  async searchStops(q: string, limit = 10): Promise<FlixbusStopSearchResultDto[]> {
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
        this.logger.error(response.data.errors.map(e => e.message).join('; '));
        throw new ServiceUnavailableException('OTP returned an error');
      }

      const stops = response.data.data?.stops ?? [];
      const trimmed = stops.slice(0, limit);

      return trimmed.map(s => ({
        gtfsId: s.gtfsId,
        name: s.name,
        lat: s.lat,
        lon: s.lon,
      }));
    } catch (error) {
      this.logger.error('Failed to search stops in OTP (FlixBus)', error as any);
      throw new ServiceUnavailableException('Failed to search stops in OTP');
    }
  }

  // ===== OTP (GRAFO GTFS) – PARTIDAS POR PARAGEM (apenas FlixBus) =====

  /**
   * Obtém partidas GTFS para uma determinada paragem,
   * filtrando apenas as rotas que são FlixBus.
   */
  async getStopDeparturesFromGraph(
    stopGtfsId: string,
    opts?: {
      startTime?: number; // epoch seconds
      timeRange?: number; // segundos
      numberOfDepartures?: number;
    },
  ): Promise<FlixbusStopDeparturesDto> {
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
        this.logger.error(response.data.errors.map(e => e.message).join('; '));
        throw new ServiceUnavailableException('OTP returned an error');
      }

      const stop = response.data.data?.stop;
      if (!stop) {
        throw new NotFoundException(`Stop ${stopGtfsId} not found in OTP graph`);
      }

      const departures: FlixbusDepartureDto[] = [];

      for (const patternRow of stop.stoptimesForPatterns || []) {
        const route = patternRow.pattern?.route;
        const patternHeadsign = patternRow.pattern?.headsign ?? undefined;
        const agencyName = route?.agency?.name ?? undefined;
        const agencyId = route?.agency?.gtfsId ?? undefined;

        const isFlix = this.isFlixbusRoute(route?.mode, agencyName ?? null, agencyId ?? null);
        if (!isFlix) {
          continue;
        }

        for (const st of patternRow.stoptimes || []) {
          departures.push({
            routeGtfsId: route?.gtfsId,
            routeShortName: route?.shortName ?? null,
            routeLongName: route?.longName ?? null,
            mode: route?.mode ?? 'BUS',
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
        `Failed to fetch FlixBus departures for stop ${stopGtfsId} from OTP`,
        error as any,
      );
      throw new ServiceUnavailableException('Failed to fetch departures for this stop from OTP');
    }
  }

  // ===== “BOARD” PARA UI – HORÁRIOS FORMATADOS =====

  /**
   * Constrói um "board" de partidas formatado para UI
   * a partir dos dados brutos de `getStopDeparturesFromGraph`.
   */
  async getStopBoard(
    stopGtfsId: string,
    opts?: {
      startTime?: number;
      timeRange?: number;
      numberOfDepartures?: number;
    },
  ): Promise<FlixbusStopBoardDto> {
    const raw = await this.getStopDeparturesFromGraph(stopGtfsId, opts);

    const rows: FlixbusStopBoardRowDto[] = raw.departures
      .map(d => {
        const departureEpochSeconds = d.serviceDay + d.realtimeDeparture;
        const scheduledEpochSeconds = d.serviceDay + d.scheduledDeparture;

        const date = new Date(departureEpochSeconds * 1000);
        const hh = String(date.getHours()).padStart(2, '0');
        const mm = String(date.getMinutes()).padStart(2, '0');
        const time = `${hh}:${mm}`;

        const delaySeconds = d.realtimeDeparture - d.scheduledDeparture;
        const delayMinutes = Math.round(delaySeconds / 60);

        return {
          time,
          destination: d.headsign ?? null,
          lineShortName: d.routeShortName ?? null,
          lineLongName: d.routeLongName ?? null,
          routeGtfsId: d.routeGtfsId,
          delayMinutes,
          isRealtime: d.realtime,
        } as FlixbusStopBoardRowDto;
      })
      // ordenar por hora "HH:MM" – suficiente para janelas de tempo curtas
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
