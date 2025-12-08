// src/metro/metro.service.ts
//
// Serviço para consumir a API oficial do Metro de Lisboa.
// Faz gestão de autenticação (API key ou OAuth token) e expõe métodos
// de alto nível para tempos de espera, estados de linha, destinos, etc.

import { Injectable, BadGatewayException, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { MetroTokenService } from './metro-token.service';
import {
  MetroDestinationDto,
  MetroIntervalDto,
  MetroLineStatusSummaryDto,
  MetroStationInfoDto,
  MetroWaitingTimeDto,
} from './dto';

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

  /**
   * Chamada genérica à API do Metro.
   *
   * Usa credenciais de uma de duas formas:
   *  - legado: METRO_LISBOA_API_KEY (Bearer direto)
   *  - novo: OAuth2 via MetroTokenService
   */
  private async callMetroApi<T>(path: string): Promise<T> {
    const legacyApiKey = this.config.get<string>('METRO_LISBOA_API_KEY');

    try {
      const bearerToken = legacyApiKey ? legacyApiKey : await this.tokenService.getAccessToken();
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
      const message = error instanceof Error ? error.message : 'Unknown Metro API error';
      this.logger.error(`Metro API request failed for path ${path}: ${message}`);
      throw new BadGatewayException('Failed to reach Metro Lisboa API');
    }
  }

  // ===== Tempos de espera =====

  getAllStationWaitingTimes(): Promise<MetroWaitingTimeDto[]> {
    return this.callMetroApi<MetroWaitingTimeDto[]>('/tempoEspera/Estacao/todos');
  }

  getStationWaitingTimes(stationId: string): Promise<MetroWaitingTimeDto[]> {
    return this.callMetroApi<MetroWaitingTimeDto[]>(`/tempoEspera/Estacao/${stationId}`);
  }

  getLineWaitingTimes(lineId: string): Promise<MetroWaitingTimeDto[]> {
    return this.callMetroApi<MetroWaitingTimeDto[]>(`/tempoEspera/Linha/${lineId}`);
  }

  // ===== Informação de estações =====

  getStationInfo(stationId: string): Promise<MetroStationInfoDto[]> {
    return this.callMetroApi<MetroStationInfoDto[]>(`/infoEstacao/${stationId}`);
  }

  getAllStationsInfo(): Promise<MetroStationInfoDto[]> {
    return this.callMetroApi<MetroStationInfoDto[]>('/infoEstacao/todos');
  }

  // ===== Estados de linha =====

  getAllLineStatus(): Promise<MetroLineStatusSummaryDto> {
    return this.callMetroApi<MetroLineStatusSummaryDto>('/estadoLinha/todos');
  }

  getLineStatus(lineId: string): Promise<Partial<MetroLineStatusSummaryDto>> {
    return this.callMetroApi<Partial<MetroLineStatusSummaryDto>>(`/estadoLinha/${lineId}`);
  }

  // ===== Destinos =====

  getDestinations(): Promise<MetroDestinationDto[]> {
    return this.callMetroApi<MetroDestinationDto[]>('/infoDestinos/todos');
  }

  // ===== Intervalos de circulação =====

  getIntervalsByLine(
    lineId: string,
    directionCode: string,
    serviceCode?: string,
  ): Promise<MetroIntervalDto | MetroIntervalDto[]> {
    const suffix = serviceCode ? `/${serviceCode}` : '';
    return this.callMetroApi<MetroIntervalDto | MetroIntervalDto[]>(
      `/infoIntervalos/${lineId}/${directionCode}${suffix}`,
    );
  }
}
