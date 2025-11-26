import {
  BadGatewayException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { PlanItineraryDto, TransportMode } from './dto/plan-itinerary.dto';

export interface OtpLeg {
  mode: string;
  distance: number;
  duration: number;
  startTime: number;  // OTP manda ms
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
}

export interface OtpItinerary {
  duration: number;
  walkDistance: number;
  startTime: number;
  endTime: number;
  legs: OtpLeg[];
}

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

interface OtpPlanVariables {
  from: { lat: number; lon: number };
  to: { lat: number; lon: number };
  date?: string;
  time?: string;
  numItineraries?: number;
  transportModes?: { mode: string }[];
}

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
    const base =
      this.config.get<string>('OTP_BASE_URL') || 'http://localhost:8080/otp';
    this.otpBaseUrl = base.replace(/\/$/, '');
  }

  private buildEndpoint(): string {
    return `${this.otpBaseUrl}${this.graphqlPath}`;
  }

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

    const now = new Date();
    const date = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
    const time = `${pad(now.getHours())}:${pad(now.getMinutes())}`;
    return { date, time };
  }

  private resolveTransportModes(dto: PlanItineraryDto): { mode: string }[] {
    const modes = dto.modes && dto.modes.length > 0
      ? dto.modes
      : [TransportMode.WALK, TransportMode.TRANSIT];

    return modes.map((m) => ({ mode: m }));
  }

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
        const msg = response.data.errors.map((e) => e.message).join('; ');
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
