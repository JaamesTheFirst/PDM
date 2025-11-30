// src/metro/metro-porto.service.ts
import {
  BadGatewayException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import {
  MetroPortoAgencyDto,
  MetroPortoRouteDto,
  MetroPortoStopDto,
  MetroPortoStopTimeDto,
  MetroPortoUpcomingDepartureDto,
} from './dto';

// ===== Tipos OTP GraphQL =====

interface OtpAgency {
  id: string;
  name: string;
  url?: string;
  timezone?: string;
  lang?: string;
  phone?: string;
}

interface OtpRoute {
  id: string;
  shortName?: string;
  longName?: string;
  mode?: string;
  color?: string;
  textColor?: string;
  agency?: OtpAgency;
}

interface OtpStop {
  id: string;
  code?: string;
  name: string;
  desc?: string;
  lat: number;
  lon: number;
  zoneId?: string;
  url?: string;
  parentStation?: { id: string } | null;
}

interface OtpStoptime {
  serviceDay: number;
  scheduledDeparture: number;
  realtimeDeparture: number;
  departureDelay: number;
  headsign?: string;
  trip: {
    id: string;
    directionId?: string;
  };
}

interface OtpStopStoptimesForPatterns {
  pattern: { route: OtpRoute };
  stoptimes: OtpStoptime[];
}

interface OtpStopWithStoptimes {
  id: string;
  name: string;
  lat: number;
  lon: number;
  stoptimesForPatterns: OtpStopStoptimesForPatterns[];
}

interface GraphQlResponse<T> {
  data?: T;
  errors?: Array<{ message: string }>;
}

// ----- QUERY para SEARCH de stops por nome -----
const STOPS_SEARCH_QUERY = `
  query MetroStopsSearch($name: String!) {
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

@Injectable()
export class MetroPortoService {
  private readonly logger = new Logger(MetroPortoService.name);
  private readonly graphqlUrl: string;

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {
    const otpBase =
      this.config.get<string>('OTP_BASE_URL') || 'http://localhost:8080/otp';
    this.graphqlUrl = `${otpBase.replace(/\/$/, '')}/routers/default/index/graphql`;
  }

  // --------- helper genérico ---------

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
        const msg = data.errors.map((e) => e.message).join('; ');
        this.logger.error(`OTP GraphQL error: ${msg}`);
        throw new BadGatewayException('OTP devolveu um erro no GraphQL');
      }

      if (!data.data) {
        throw new BadGatewayException('Resposta inválida do OTP (sem data)');
      }

      return data.data;
    } catch (error) {
      this.logger.error(
        `Falha ao comunicar com OTP GraphQL (${this.graphqlUrl})`,
        error instanceof Error ? error.stack : undefined,
      );
      throw new BadGatewayException(
        'Falha ao comunicar com o serviço OTP (GraphQL)',
      );
    }
  }

  // ---------- Agência ----------

  async getAgencyInfo(): Promise<MetroPortoAgencyDto | null> {
    const query = `
      query MetroAgencies {
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

    const agency = result.agencies.find((a) => {
      const n = a.name?.toLowerCase() ?? '';
      return n.includes('metro') && n.includes('porto');
    });

    if (!agency) return null;

    return {
      id: agency.id,
      name: agency.name,
      url: agency.url,
      timezone: agency.timezone,
      lang: agency.lang,
      phone: agency.phone,
    };
  }

  // ---------- Routes ----------

  async getRoutes(): Promise<MetroPortoRouteDto[]> {
    const query = `
      query MetroRoutes {
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

    const routes = result.routes.filter((r) => {
      const n = r.agency?.name?.toLowerCase() ?? '';
      return n.includes('metro') && n.includes('porto');
    });

    return routes.map((r) => ({
      id: r.id,
      shortName: r.shortName,
      longName: r.longName,
      mode: r.mode,
      color: r.color,
      textColor: r.textColor,
      agency: r.agency && {
        id: r.agency.id,
        name: r.agency.name,
        url: r.agency.url,
        timezone: r.agency.timezone,
        lang: r.agency.lang,
        phone: r.agency.phone,
      },
    }));
  }

  async getRoute(routeId: string): Promise<MetroPortoRouteDto | null> {
    const query = `
      query MetroRouteByNode($id: ID!) {
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

    return {
      id: node.id,
      shortName: node.shortName,
      longName: node.longName,
      mode: node.mode,
      color: node.color,
      textColor: node.textColor,
      agency: node.agency && {
        id: node.agency.id,
        name: node.agency.name,
        url: node.agency.url,
        timezone: node.agency.timezone,
        lang: node.agency.lang,
        phone: node.agency.phone,
      },
    };
  }

  // ---------- Stops ----------

  async getStops(): Promise<MetroPortoStopDto[]> {
    const query = `
      query MetroStops {
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

    return result.stops.map((s) => ({
      id: s.id,
      code: s.code,
      name: s.name,
      desc: s.desc,
      lat: s.lat,
      lon: s.lon,
      zoneId: s.zoneId,
      url: s.url,
      parentStation: s.parentStation?.id ?? undefined,
    }));
  }

  /**
   * Pesquisa por nome de estação (para o autocomplete no frontend).
   */
  async searchStops(q: string, limit = 10): Promise<MetroPortoStopDto[]> {
    const term = (q ?? '').trim();
    if (!term) return [];

    const result = await this.graphqlRequest<{ stops: OtpStop[] }>(
      STOPS_SEARCH_QUERY,
      { name: term },
    );

    const stops = result.stops ?? [];
    const trimmed = stops.slice(0, limit);

    return trimmed.map((s) => ({
      id: s.id,
      code: s.code,
      name: s.name,
      desc: s.desc,
      lat: s.lat,
      lon: s.lon,
      zoneId: s.zoneId,
      url: s.url,
      parentStation: s.parentStation?.id ?? undefined,
    }));
  }

  async getStop(stopId: string): Promise<MetroPortoStopDto | null> {
    const query = `
      query MetroStopByNode($id: ID!) {
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
      code: s.code,
      name: s.name,
      desc: s.desc,
      lat: s.lat,
      lon: s.lon,
      zoneId: s.zoneId,
      url: s.url,
      parentStation: s.parentStation?.id ?? undefined,
    };
  }

  async getStopsByRoute(routeId: string): Promise<MetroPortoStopDto[]> {
    const query = `
      query MetroRouteStopsByNode($id: ID!) {
        node(id: $id) {
          __typename
          ... on Route {
            id
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
        patterns: { stops: OtpStop[] }[];
      } | null;
    }>(query, { id: routeId });

    const routeNode = result.node;
    if (!routeNode || routeNode.__typename !== 'Route') return [];

    const allStops: OtpStop[] = [];
    for (const p of routeNode.patterns) {
      allStops.push(...p.stops);
    }

    const byId = new Map<string, OtpStop>();
    allStops.forEach((s) => byId.set(s.id, s));

    return Array.from(byId.values()).map((s) => ({
      id: s.id,
      code: s.code,
      name: s.name,
      desc: s.desc,
      lat: s.lat,
      lon: s.lon,
      zoneId: s.zoneId,
      url: s.url,
      parentStation: s.parentStation?.id ?? undefined,
    }));
  }

  // ---------- Partidas próximas ----------

  async getUpcomingDeparturesByStop(
    stopId: string,
    limit = 10,
  ): Promise<MetroPortoUpcomingDepartureDto[]> {
    const query = `
  query MetroStopDeparturesByNode($id: ID!, $limit: Int!) {
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

    const baseStop: MetroPortoStopDto = {
      id: node.id,
      name: node.name,
      lat: node.lat,
      lon: node.lon,
    };

    const departures: MetroPortoUpcomingDepartureDto[] = [];

    for (const patternEntry of node.stoptimesForPatterns) {
      const route = patternEntry.pattern.route;

      const mappedRoute: MetroPortoRouteDto = {
        id: route.id,
        shortName: route.shortName,
        longName: route.longName,
        mode: route.mode,
        color: route.color,
        textColor: route.textColor,
        agency: route.agency && {
          id: route.agency.id,
          name: route.agency.name,
          url: route.agency.url,
          timezone: route.agency.timezone,
          lang: route.agency.lang,
          phone: route.agency.phone,
        },
      };

      for (const st of patternEntry.stoptimes) {
        const stopTime: MetroPortoStopTimeDto = {
          // como o Stoptime já não traz stopId/stopName,
          // usamos sempre o da paragem base
          stopId: baseStop.id,
          stopName: baseStop.name,
          serviceDay: st.serviceDay,
          scheduledDeparture: st.scheduledDeparture,
          realtimeDeparture: st.realtimeDeparture,
          departureDelay: st.departureDelay,
          stopHeadsign: st.headsign,
          tripHeadsign: st.headsign,
          routeId: route.id,
          tripId: st.trip.id,
          directionId: st.trip.directionId,
        };

        departures.push({
          stop: baseStop,
          route: mappedRoute,
          stopTime,
        });
      }
    }

    departures.sort((a, b) => {
      const at = a.stopTime.serviceDay + a.stopTime.realtimeDeparture;
      const bt = b.stopTime.serviceDay + b.stopTime.realtimeDeparture;
      return at - bt;
    });

    return departures.slice(0, limit);
  }
}
