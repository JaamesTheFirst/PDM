// src/health/health.controller.ts
import { Controller, Get } from '@nestjs/common';

/**
 * Endpoints de health check da API.
 *
 * Útil para:
 *  - verificar se a app NestJS está a correr
 *  - probes de Kubernetes / Docker (liveness/readiness)
 *  - monitorização simples pelos devs / CI
 */
@Controller('health')
export class HealthController {
  /**
   * Health check básico.
   *
   * GET /health
   *
   * @returns objeto simples com:
   *  - status: string fixa "ok"
   *  - message: texto legível
   *  - timestamp: ISO-8601 da hora do servidor
   */
  @Get()
  check() {
    return {
      status: 'ok',
      message: 'Sustainable Transport API is running!',
      timestamp: new Date().toISOString(),
    };
  }
}
