import {
  BadGatewayException,
  Injectable,
  Logger,
} from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { PlanItineraryDto } from './dto/plan-itinerary.dto';

interface OtpGraphQlError {
  message: string;
}

interface OtpPlanResponse {
  data?: {
    plan?: {
      itineraries: OtpItinerary[];
    } | null;
  };
  errors?: OtpGraphQlError[];
}

export interface OtpItinerary {
  duration: number;
  walkDistance: number;
  legs: Array<{
    mode: string;
    distance: number;
    duration: number;
    startTime: string;
    endTime: string;
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
    };
  }>;
}

const PLAN_QUERY = `
query Plan($from: String!, $to: String!) {
  plan(
    fromPlace: $from,
    toPlace: $to
  ) {
    itineraries {
      duration
      walkDistance
      legs {
        mode
        distance
        duration
        startTime
        endTime
        from { name lat lon }
        to { name lat lon }
        route { shortName longName }
      }
    }
  }
}
`;

@Injectable()
export class OtpService {
  private readonly logger = new Logger(OtpService.name);
  private readonly otpBaseUrl: string;

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {
    this.otpBaseUrl =
      this.config.get<string>('OTP_BASE_URL') || 'http://localhost:8080/otp';
  }

  async plan(dto: PlanItineraryDto): Promise<OtpItinerary[]> {
    const endpoint = `${this.otpBaseUrl.replace(/\/$/, '')}/routers/default/index/graphql`;

    const variables = {
      from: `${dto.fromLat},${dto.fromLon}`,
      to: `${dto.toLat},${dto.toLon}`,
    };

    try {
      const response = await firstValueFrom(
        this.http.post<OtpPlanResponse>(
          endpoint,
          {
            query: PLAN_QUERY,
            variables,
          },
          {
            headers: { 'Content-Type': 'application/json' },
          },
        ),
      );

      if (response.data.errors && response.data.errors.length > 0) {
        this.logger.error(response.data.errors.map((e) => e.message).join('; '));
        throw new BadGatewayException('OTP returned an error');
      }

      return response.data.data?.plan?.itineraries ?? [];
    } catch (error) {
      this.logger.error('Failed to fetch itinerary from OTP', error as any);
      throw new BadGatewayException('Failed to fetch itinerary from OTP');
    }
  }

}

