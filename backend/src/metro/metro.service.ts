import { Injectable, BadGatewayException, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { MetroTokenService } from './metro-token.service';

interface MetroApiResponse<T> {
  resposta: T;
  codigo: string;
}

@Injectable()
export class MetroService {
  private readonly logger = new Logger(MetroService.name);

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
    private readonly tokenService: MetroTokenService,
  ) {}

  private async callMetroApi<T>(path: string): Promise<T> {
    const legacyApiKey = this.config.get<string>('METRO_LISBOA_API_KEY');

    try {
      const bearerToken = legacyApiKey
        ? legacyApiKey
        : await this.tokenService.getAccessToken();
      const response = await firstValueFrom(
        this.http.get<MetroApiResponse<T>>(path, {
          headers: {
            Authorization: `Bearer ${bearerToken}`,
            accept: 'application/json',
          },
        }),
      );

      return response.data.resposta;
    } catch (error) {
      const message =
        error instanceof Error ? error.message : 'Unknown Metro API error';
      this.logger.error(`Metro API request failed for path ${path}: ${message}`);
      throw new BadGatewayException('Failed to reach Metro Lisboa API');
    }
  }

  getAllStationWaitingTimes() {
    return this.callMetroApi('/tempoEspera/Estacao/todos');
  }

  getStationWaitingTimes(stationId: string) {
    return this.callMetroApi(`/tempoEspera/Estacao/${stationId}`);
  }

  getLineWaitingTimes(lineId: string) {
    return this.callMetroApi(`/tempoEspera/Linha/${lineId}`);
  }

  getStationInfo(stationId: string) {
    return this.callMetroApi(`/infoEstacao/${stationId}`);
  }

  getAllStationsInfo() {
    return this.callMetroApi('/infoEstacao/todos');
  }

  getAllLineStatus() {
    return this.callMetroApi('/estadoLinha/todos');
  }

  getLineStatus(lineId: string) {
    return this.callMetroApi(`/estadoLinha/${lineId}`);
  }

  getDestinations() {
    return this.callMetroApi('/infoDestinos/todos');
  }

  getIntervalsByLine(
    lineId: string,
    directionCode: string,
    serviceCode?: string,
  ) {
    const suffix = serviceCode
      ? `/${serviceCode}`
      : '';
    return this.callMetroApi(
      `/infoIntervalos/${lineId}/${directionCode}${suffix}`,
    );
  }
}

