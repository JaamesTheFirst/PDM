import { BadGatewayException, Injectable, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { PlanItineraryDto, TransportMode } from './dto/plan-itinerary.dto';

/**
 * Representa uma perna (leg) de um itinerary devolvido pelo OTP.
 */
export interface OtpLeg {
  mode: string;
  distance: number;
  duration: number;
  startTime: number; // OTP envia em ms desde epoch
  endTime: number;
  from: {
    name: string;
    lat: number;
    lon: number;
  };
  to: {
    name: string;
    lat: number;
    lon: number;
  };
  route?: {
    shortName?: string;
    longName?: string;
  } | null;
  legGeometry?: {
    points: string;
  } | null;
  rentedBike?: boolean; // true se for leg de bike-share
}

/**
 * Itinerary completo devolvido pelo OTP.
 */
export interface OtpItinerary {
  duration: number;
  walkDistance: number;
  startTime: number;
  endTime: number;
  legs: OtpLeg[];
}

/**
 * Estrutura principal da resposta de plan do OTP.
 */
export interface OtpPlanResult {
  itineraries: OtpItinerary[];
}

interface OtpPlanData {
  plan?: OtpPlanResult | null;
}

interface OtpGraphQlError {
  message: string;
}

interface OtpPlanResponse {
  data?: OtpPlanData;
  errors?: OtpGraphQlError[];
}

/**
 * Variáveis usadas na query GraphQL de plan.
 */
interface OtpPlanVariables {
  from: { lat: number; lon: number };
  to: { lat: number; lon: number };
  date?: string;
  time?: string;
  numItineraries?: number;
  transportModes?: { mode: string }[];
}

/**
 * Query GraphQL para o endpoint /plan do OTP 2.x.
 */
const PLAN_QUERY = `
  query Plan(
    $from: InputCoordinates!,
    $to: InputCoordinates!,
    $date: String,
    $time: String,
    $numItineraries: Int,
    $transportModes: [TransportMode]
  ) {
    plan(
      from: $from,
      to: $to,
      date: $date,
      time: $time,
      numItineraries: $numItineraries,
      transportModes: $transportModes
    ) {
      itineraries {
        duration
        walkDistance
        startTime
        endTime
        legs {
          mode
          distance
          duration
          startTime
          endTime
          from { name lat lon }
          to   { name lat lon }
          route { shortName longName }
          legGeometry { points }
          rentedBike
        }
      }
    }
  }
`;

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly otpBaseUrl: string;
  private readonly graphqlPath = '/routers/default/index/graphql';

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {
    const base = this.config.get<string>('OTP_BASE_URL') || 'http://localhost:8080/otp';
    this.otpBaseUrl = base.replace(/\/$/, '');
  }

  /** Constrói o endpoint final do GraphQL do OTP. */
  private buildEndpoint(): string {
    return `${this.otpBaseUrl}${this.graphqlPath}`;
  }

  /**
   * Resolve date/time a enviar para o OTP com base no DTO:
   * - se date+time vierem preenchidos → usa esses
   * - senão se vier dateTime → extrai date+time
   * - senão → usa "amanhã às 08:00" como default
   */
  private resolveDateAndTime(dto: PlanItineraryDto): { date: string; time: string } {
    const pad = (n: number) => n.toString().padStart(2, '0');

    if (dto.date && dto.time) {
      return { date: dto.date, time: dto.time };
    }

    if (dto.dateTime) {
      const d = new Date(dto.dateTime);
      if (!isNaN(d.getTime())) {
        const date = `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
        const time = `${pad(d.getHours())}:${pad(d.getMinutes())}`;
        return { date, time };
      }
    }

    // Default: amanhã às 8h, para garantir oferta de transit
    const tomorrow = new Date();
    tomorrow.setDate(tomorrow.getDate() + 1);
    tomorrow.setHours(8, 0, 0, 0);
    const date = `${tomorrow.getFullYear()}-${pad(tomorrow.getMonth() + 1)}-${pad(tomorrow.getDate())}`;
    const time = '08:00';
    return { date, time };
  }

  /**
   * Converte os modos do DTO (TransportMode) no formato
   * esperado pelo field transportModes do OTP.
   * Default: [WALK, TRANSIT].
   */
  private resolveTransportModes(dto: PlanItineraryDto): { mode: string }[] {
    const modes =
      dto.modes && dto.modes.length > 0 ? dto.modes : [TransportMode.WALK, TransportMode.TRANSIT];

    return modes.map(m => ({ mode: m }));
  }

  /**
   * Chama o GraphQL do OTP /plan e devolve os itinerários crus.
   */
  async plan(dto: PlanItineraryDto): Promise<OtpPlanResult> {
    const endpoint = this.buildEndpoint();
    const { date, time } = this.resolveDateAndTime(dto);

    const variables: OtpPlanVariables = {
      from: { lat: dto.fromLat, lon: dto.fromLon },
      to: { lat: dto.toLat, lon: dto.toLon },
      date,
      time,
      numItineraries: dto.numItineraries ?? 5,
      transportModes: this.resolveTransportModes(dto),
    };

    try {
      const response = await firstValueFrom(
        this.http.post<OtpPlanResponse>(
          endpoint,
          {
            query: PLAN_QUERY,
            variables,
          },
          { headers: { 'Content-Type': 'application/json' } },
        ),
      );

      if (response.data.errors?.length) {
        const msg = response.data.errors.map(e => e.message).join('; ');
        this.logger.error(`OTP GraphQL errors: ${msg}`);
        throw new BadGatewayException('OTP returned an error');
      }

      const plan = response.data.data?.plan;
      if (!plan) {
        this.logger.warn('OTP returned no plan');
        return { itineraries: [] };
      }

      return plan;
    } catch (error) {
      this.logger.error('Failed to fetch trip from OTP', error as any);
      throw new BadGatewayException('Failed to fetch trip from OTP');
    }
  }
}
