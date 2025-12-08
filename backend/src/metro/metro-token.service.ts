// src/metro/metro-token.service.ts
//
// Serviço responsável por obter e cachear o access token OAuth2
// da API do Metro de Lisboa (quando não é usado o legacy API key).

import { Injectable, BadGatewayException, Logger } from '@nestjs/common';
import { HttpService } from '@nestjs/axios';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';
import { AxiosRequestConfig } from 'axios';
import * as https from 'https';

interface MetroTokenResponse {
  access_token: string;
  token_type: string;
  expires_in: number;
  scope?: string;
}

@Injectable()
export class MetroTokenService {
  private readonly logger = new Logger(MetroTokenService.name);

  /** Token atual em cache (se existir). */
  private accessToken?: string;

  /** Epoch millis em que o token expira. */
  private expiresAt = 0;

  /** Configuração base para o pedido de token. */
  private readonly tokenHttpConfig: AxiosRequestConfig = {
    baseURL: 'https://api.metrolisboa.pt:8243',
    httpsAgent: new https.Agent({
      // a API usa certificado algo peculiar; por isso esta flag está desligada
      rejectUnauthorized: false,
    }),
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  };

  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {}

  /**
   * Devolve um access token válido.
   * Se o token em cache ainda for válido, reutiliza-o.
   */
  async getAccessToken(): Promise<string> {
    const now = Date.now();
    if (this.accessToken && now < this.expiresAt - 60_000) {
      // ainda válido (com margem de 60s)
      return this.accessToken;
    }

    const clientId = this.config.get<string>('METRO_LISBOA_CLIENT_ID');
    const clientSecret = this.config.get<string>('METRO_LISBOA_CLIENT_SECRET');
    if (!clientId || !clientSecret) {
      throw new BadGatewayException('Metro Lisboa client credentials are not configured');
    }

    const basicAuth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');

    try {
      const response = await firstValueFrom(
        this.http.post<MetroTokenResponse>('/token', 'grant_type=client_credentials', {
          ...this.tokenHttpConfig,
          headers: {
            ...this.tokenHttpConfig.headers,
            Authorization: `Basic ${basicAuth}`,
          },
        }),
      );

      this.accessToken = response.data.access_token;
      this.expiresAt = now + response.data.expires_in * 1000;
      return this.accessToken;
    } catch (error) {
      this.logger.error(
        'Failed to fetch Metro Lisboa access token',
        error instanceof Error ? error.stack : undefined,
      );
      throw new BadGatewayException('Unable to authenticate with Metro API');
    }
  }
}
