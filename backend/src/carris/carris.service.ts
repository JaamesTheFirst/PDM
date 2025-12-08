// src/carris/carris.service.ts

import { BadGatewayException, Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';

import {
  CarrisAgencyDto,
  CarrisRouteDto,
  CarrisStopDto,
  CarrisStopTimeDto,
  CarrisUpcomingDepartureDto,
} from './dto';

// ===== Tipos internos OTP GraphQL =====

/**
 * Agência tal como devolvida pelo OTP GraphQL.
 */
interface OtpAgency {
  id: string;
  name: string;
  url?: string | null;
  timezone?: string | null;
  lang?: string | null;
  phone?: string | null;
}

/**
 * Rota/linha tal como devolvida pelo OTP GraphQL.
 */
interface OtpRoute {
  id: string;
  shortName?: string | null;
  longName?: string | null;
  mode?: string | null;
  color?: string | null;
  textColor?: string | null;
  agency?: OtpAgency | null;
}

/**
 * Paragem tal como devolvida pelo OTP GraphQL.
 */
interface OtpStop {
  id: string;
  code?: string | null;
  name: string;
  desc?: string | null;
  lat: number;
  lon: number;
  zoneId?: string | null;
  url?: string | null;
  parentStation?: { id: string } | null;
}

/**
 * Informação de horário (stoptime) tal como devolvida pelo OTP GraphQL.
 */
interface OtpStoptime {
  serviceDay: number;
  scheduledDeparture: number;
  realtimeDeparture: number;
  departureDelay: number;
  headsign?: string | null;
  trip: {
    id: string;
    directionId?: string | null;
  };
}

/**
 * Estrutura de stoptimes agrupados por padrão de linha (pattern).
 */
interface OtpStopStoptimesForPatterns {
  pattern: {
    route: OtpRoute;
  };
  stoptimes: OtpStoptime[];
}

/**
 * Stop enriquecida com stoptimes, devolvida por queries específicas.
 */
interface OtpStopWithStoptimes {
  id: string;
  name: string;
  lat: number;
  lon: number;
  stoptimesForPatterns: OtpStopStoptimesForPatterns[];
}

/**
 * Estrutura base para respostas GraphQL do OTP.
 */
interface GraphQlResponse<T> {
  data?: T;
  errors?: Array<{ message: string }>;
}

// ----- QUERY para SEARCH de stops por nome -----

/**
 * Query GraphQL para pesquisa de stops por nome (autocomplete).
 */
const STOPS_SEARCH_QUERY = `
  query CarrisStopsSearch($name: String!) {
    stops(name: $name) {
      id
      code
      name
      desc
      lat
      lon
      zoneId
      url
      parentStation { id }
    }
  }
`;

// ----- Service -----

/**
 * Serviço responsável por integrar com o OTP GraphQL e
 * expor dados normalizados da Carris para o resto da aplicação.
 *
 * Principais responsabilidades:
 *  - chamar o endpoint GraphQL do OTP
 *  - filtrar apenas rotas/paragens relevantes para Carris
 *  - mapear respostas para DTOs (CarrisAgencyDto, CarrisRouteDto, etc.)
 */
@Injectable()
export class CarrisService {
  /** Logger scoped ao serviço Carris */
  private readonly logger = new Logger(CarrisService.name);
  /** URL do endpoint GraphQL do OTP (router default) */
  private readonly graphqlUrl: string;

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {
    const otpBase = this.config.get<string>('OTP_BASE_URL') || 'http://localhost:8080/otp';

    // Garante que não há double slash no final
    this.graphqlUrl = `${otpBase.replace(/\/$/, '')}/routers/default/index/graphql`;
  }

  // ---------- Helpers internos ----------

  /**
   * Helper genérico para efetuar pedidos GraphQL ao OTP.
   *
   * - faz POST para `this.graphqlUrl`
   * - trata erros de rede e erros GraphQL (campo `errors`)
   * - devolve apenas a propriedade `data` tipada como `TData`
   *
   * @param query String da query GraphQL
   * @param variables Variáveis da query (opcional)
   * @throws BadGatewayException em caso de falha de comunicação ou erro do OTP
   */
  private async graphqlRequest<TData>(
    query: string,
    variables?: Record<string, any>,
  ): Promise<TData> {
    try {
      const { data } = await firstValueFrom(
        this.http.post<GraphQlResponse<TData>>(
          this.graphqlUrl,
          { query, variables },
          {
            headers: {
              'Content-Type': 'application/json',
              Accept: 'application/json',
            },
          },
        ),
      );

      if (data.errors?.length) {
        const msg = data.errors.map(e => e.message).join('; ');
        this.logger.error(`OTP GraphQL error (Carris): ${msg}`);
        throw new BadGatewayException('OTP devolveu um erro no GraphQL');
      }

      if (!data.data) {
        throw new BadGatewayException('Resposta inválida do OTP (sem data)');
      }

      return data.data;
    } catch (error) {
      this.logger.error(
        `Falha ao comunicar com OTP GraphQL (Carris) em ${this.graphqlUrl}`,
        error instanceof Error ? error.stack : undefined,
      );
      throw new BadGatewayException('Falha ao comunicar com o serviço OTP (GraphQL) para Carris');
    }
  }

  /**
   * Verifica se uma agência do OTP corresponde à Carris.
   *
   * @param agency Agência devolvida pelo OTP
   * @returns `true` se o nome da agência contiver "carris" (case-insensitive)
   */
  private isCarrisAgency(agency?: OtpAgency | null): boolean {
    const n = agency?.name?.toLowerCase() ?? '';
    // Ajusta aqui se o agency.name no teu GTFS for diferente
    return n.includes('carris');
  }

  // ---------- Agência ----------

  /**
   * Obtém informação da agência Carris a partir do OTP.
   *
   * @returns `CarrisAgencyDto` ou `null` se não for encontrada
   */
  async getAgencyInfo(): Promise<CarrisAgencyDto | null> {
    const query = `
      query CarrisAgencies {
        agencies {
          id
          name
          url
          timezone
          lang
          phone
        }
      }
    `;

    const result = await this.graphqlRequest<{ agencies: OtpAgency[] }>(query);

    const agency = result.agencies.find(a => this.isCarrisAgency(a));

    if (!agency) return null;

    return {
      id: agency.id,
      name: agency.name,
      url: agency.url ?? undefined,
      timezone: agency.timezone ?? undefined,
      lang: agency.lang ?? undefined,
      phone: agency.phone ?? undefined,
    };
  }

  // ---------- Routes ----------

  /**
   * Lista todas as rotas pertencentes à Carris (modo BUS) presentes no grafo.
   *
   * @returns Array de `CarrisRouteDto`
   */
  async getRoutes(): Promise<CarrisRouteDto[]> {
    const query = `
      query CarrisRoutes {
        routes {
          id
          shortName
          longName
          mode
          color
          textColor
          agency {
            id
            name
            url
            timezone
            lang
            phone
          }
        }
      }
    `;

    const result = await this.graphqlRequest<{ routes: OtpRoute[] }>(query);

    // Filtra para BUS + Carris
    const routes = result.routes.filter(r => {
      const isBus = (r.mode ?? '').toUpperCase() === 'BUS';
      return isBus && this.isCarrisAgency(r.agency || undefined);
    });

    // Mapeia para DTO simplificado
    return routes.map(r => ({
      id: r.id,
      shortName: r.shortName ?? null,
      longName: r.longName ?? null,
      mode: r.mode ?? null,
      color: r.color ?? null,
      textColor: r.textColor ?? null,
      agency:
        r.agency && this.isCarrisAgency(r.agency)
          ? {
              id: r.agency.id,
              name: r.agency.name,
              url: r.agency.url ?? undefined,
              timezone: r.agency.timezone ?? undefined,
              lang: r.agency.lang ?? undefined,
              phone: r.agency.phone ?? undefined,
            }
          : null,
    }));
  }

  /**
   * Obtém detalhes de uma rota específica da Carris.
   *
   * @param routeId ID da rota no grafo OTP
   * @returns `CarrisRouteDto` ou `null` se a rota não for da Carris ou não existir
   */
  async getRoute(routeId: string): Promise<CarrisRouteDto | null> {
    const query = `
      query CarrisRouteByNode($id: ID!) {
        node(id: $id) {
          __typename
          ... on Route {
            id
            shortName
            longName
            mode
            color
            textColor
            agency {
              id
              name
              url
              timezone
              lang
              phone
            }
          }
        }
      }
    `;

    const result = await this.graphqlRequest<{
      node: (OtpRoute & { __typename: string }) | null;
    }>(query, { id: routeId });

    const node = result.node;
    if (!node || node.__typename !== 'Route') return null;

    // Valida se é BUS + Carris
    if (
      (node.mode ?? '').toUpperCase() !== 'BUS' ||
      !this.isCarrisAgency(node.agency || undefined)
    ) {
      return null;
    }

    return {
      id: node.id,
      shortName: node.shortName ?? null,
      longName: node.longName ?? null,
      mode: node.mode ?? null,
      color: node.color ?? null,
      textColor: node.textColor ?? null,
      agency:
        node.agency && this.isCarrisAgency(node.agency)
          ? {
              id: node.agency.id,
              name: node.agency.name,
              url: node.agency.url ?? undefined,
              timezone: node.agency.timezone ?? undefined,
              lang: node.agency.lang ?? undefined,
              phone: node.agency.phone ?? undefined,
            }
          : null,
    };
  }

  // ---------- Stops ----------

  /**
   * Lista todas as paragens presentes no grafo OTP.
   *
   * Nota: aqui não há filtro explícito para Carris, porque o OTP
   * nem sempre liga stops diretamente à agência. Se necessário,
   * o filtro pode ser refinado com base em `zoneId`, `code`, etc.
   */
  async getStops(): Promise<CarrisStopDto[]> {
    const query = `
      query CarrisStops {
        stops {
          id
          code
          name
          desc
          lat
          lon
          zoneId
          url
          parentStation { id }
        }
      }
    `;

    const result = await this.graphqlRequest<{ stops: OtpStop[] }>(query);

    return result.stops.map(s => ({
      id: s.id,
      code: s.code ?? null,
      name: s.name,
      desc: s.desc ?? null,
      lat: s.lat,
      lon: s.lon,
      zoneId: s.zoneId ?? null,
      url: s.url ?? null,
      parentStation: s.parentStation?.id ?? null,
    }));
  }

  /**
   * Pesquisa de paragens por nome, para uso em autocomplete.
   *
   * @param q Termo de pesquisa (nome parcial da paragem)
   * @param limit Máximo de resultados a devolver
   */
  async searchStops(q: string, limit = 10): Promise<CarrisStopDto[]> {
    const term = (q ?? '').trim();
    if (!term) return [];

    const result = await this.graphqlRequest<{ stops: OtpStop[] }>(STOPS_SEARCH_QUERY, {
      name: term,
    });

    const stops = result.stops ?? [];
    const trimmed = stops.slice(0, limit);

    return trimmed.map(s => ({
      id: s.id,
      code: s.code ?? null,
      name: s.name,
      desc: s.desc ?? null,
      lat: s.lat,
      lon: s.lon,
      zoneId: s.zoneId ?? null,
      url: s.url ?? null,
      parentStation: s.parentStation?.id ?? null,
    }));
  }

  /**
   * Obtém detalhes de uma paragem específica pelo ID.
   *
   * @param stopId ID da paragem no grafo OTP
   * @returns `CarrisStopDto` ou `null` se não existir
   */
  async getStop(stopId: string): Promise<CarrisStopDto | null> {
    const query = `
      query CarrisStopByNode($id: ID!) {
        node(id: $id) {
          __typename
          ... on Stop {
            id
            code
            name
            desc
            lat
            lon
            zoneId
            url
            parentStation { id }
          }
        }
      }
    `;

    const result = await this.graphqlRequest<{
      node: (OtpStop & { __typename: string }) | null;
    }>(query, { id: stopId });

    const s = result.node;
    if (!s || s.__typename !== 'Stop') return null;

    return {
      id: s.id,
      code: s.code ?? null,
      name: s.name,
      desc: s.desc ?? null,
      lat: s.lat,
      lon: s.lon,
      zoneId: s.zoneId ?? null,
      url: s.url ?? null,
      parentStation: s.parentStation?.id ?? null,
    };
  }

  /**
   * Lista paragens associadas a uma rota Carris específica.
   *
   * A query usa `patterns.stops` para obter as paragens da linha
   * e depois faz deduplicação por ID.
   *
   * @param routeId ID da rota
   */
  async getStopsByRoute(routeId: string): Promise<CarrisStopDto[]> {
    const query = `
      query CarrisRouteStopsByNode($id: ID!) {
        node(id: $id) {
          __typename
          ... on Route {
            id
            mode
            agency { id name }
            patterns {
              stops {
                id
                code
                name
                desc
                lat
                lon
                zoneId
                url
                parentStation { id }
              }
            }
          }
        }
      }
    `;

    const result = await this.graphqlRequest<{
      node: {
        __typename: string;
        mode?: string | null;
        agency?: OtpAgency | null;
        patterns: { stops: OtpStop[] }[];
      } | null;
    }>(query, { id: routeId });

    const routeNode = result.node;
    if (!routeNode || routeNode.__typename !== 'Route') return [];

    // Garante que é uma rota BUS da Carris
    if (
      (routeNode.mode ?? '').toUpperCase() !== 'BUS' ||
      !this.isCarrisAgency(routeNode.agency || undefined)
    ) {
      return [];
    }

    // Junta todas as paragens de todos os patterns
    const allStops: OtpStop[] = [];
    for (const p of routeNode.patterns || []) {
      allStops.push(...p.stops);
    }

    // Dedup por ID
    const byId = new Map<string, OtpStop>();
    allStops.forEach(s => byId.set(s.id, s));

    return Array.from(byId.values()).map(s => ({
      id: s.id,
      code: s.code ?? null,
      name: s.name,
      desc: s.desc ?? null,
      lat: s.lat,
      lon: s.lon,
      zoneId: s.zoneId ?? null,
      url: s.url ?? null,
      parentStation: s.parentStation?.id ?? null,
    }));
  }

  // ---------- Próximas partidas numa paragem ----------

  /**
   * Obtém as próximas partidas (stoptimes) para uma paragem específica,
   * já filtradas para rotas da Carris (modo BUS) e ordenadas por hora.
   *
   * @param stopId ID da paragem
   * @param limit Máximo de partidas a devolver
   */
  async getUpcomingDeparturesByStop(
    stopId: string,
    limit = 10,
  ): Promise<CarrisUpcomingDepartureDto[]> {
    const query = `
      query CarrisStopDeparturesByNode($id: ID!, $limit: Int!) {
        node(id: $id) {
          __typename
          ... on Stop {
            id
            name
            lat
            lon
            stoptimesForPatterns(numberOfDepartures: $limit) {
              pattern {
                route {
                  id
                  shortName
                  longName
                  mode
                  color
                  textColor
                  agency {
                    id
                    name
                    url
                    timezone
                    lang
                    phone
                  }
                }
              }
              stoptimes {
                serviceDay
                scheduledDeparture
                realtimeDeparture
                departureDelay
                headsign
                trip {
                  id
                  directionId
                }
              }
            }
          }
        }
      }
    `;

    const result = await this.graphqlRequest<{
      node: (OtpStopWithStoptimes & { __typename: string }) | null;
    }>(query, { id: stopId, limit });

    const node = result.node;
    if (!node || node.__typename !== 'Stop') return [];

    const baseStop: CarrisStopDto = {
      id: node.id,
      name: node.name,
      lat: node.lat,
      lon: node.lon,
    };

    const departures: CarrisUpcomingDepartureDto[] = [];

    for (const patternEntry of node.stoptimesForPatterns || []) {
      const route = patternEntry.pattern.route;

      // Só queremos partidas de rotas BUS da Carris
      if (
        (route.mode ?? '').toUpperCase() !== 'BUS' ||
        !this.isCarrisAgency(route.agency || undefined)
      ) {
        continue;
      }

      const mappedRoute: CarrisRouteDto = {
        id: route.id,
        shortName: route.shortName ?? null,
        longName: route.longName ?? null,
        mode: route.mode ?? null,
        color: route.color ?? null,
        textColor: route.textColor ?? null,
        agency:
          route.agency && this.isCarrisAgency(route.agency)
            ? {
                id: route.agency.id,
                name: route.agency.name,
                url: route.agency.url ?? undefined,
                timezone: route.agency.timezone ?? undefined,
                lang: route.agency.lang ?? undefined,
                phone: route.agency.phone ?? undefined,
              }
            : null,
      };

      for (const st of patternEntry.stoptimes) {
        const stopTime: CarrisStopTimeDto = {
          stopId: baseStop.id,
          stopName: baseStop.name,
          serviceDay: st.serviceDay,
          scheduledDeparture: st.scheduledDeparture,
          realtimeDeparture: st.realtimeDeparture,
          departureDelay: st.departureDelay,
          stopHeadsign: st.headsign ?? null,
          tripHeadsign: st.headsign ?? null,
          routeId: route.id,
          tripId: st.trip.id,
          directionId: st.trip.directionId ?? null,
        };

        departures.push({
          stop: baseStop,
          route: mappedRoute,
          stopTime,
        });
      }
    }

    // Ordena por tempo real de partida: serviceDay + realtimeDeparture
    departures.sort((a, b) => {
      const at = a.stopTime.serviceDay + a.stopTime.realtimeDeparture;
      const bt = b.stopTime.serviceDay + b.stopTime.realtimeDeparture;
      return at - bt;
    });

    // Respeita o limite pedido
    return departures.slice(0, limit);
  }
}
