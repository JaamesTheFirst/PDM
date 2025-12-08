// src/impact/impact.controller.ts
import { Controller, Get, Query, UseGuards } from '@nestjs/common';
import { ImpactService } from './impact.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload } from '../auth/types/jwt-payload.type';
import { EcoPeriodType } from '@prisma/client';

/**
 * Controller responsável pelos endpoints de impacto ecológico
 * do utilizador (histórico de viagens + agregados EcoStatsAggregate).
 *
 * Todos os endpoints exigem autenticação JWT.
 */
@Controller('impact')
@UseGuards(JwtAuthGuard)
export class ImpactController {
  constructor(private readonly impactService: ImpactService) {}

  /**
   * Resumo da última semana (7 dias, incluindo hoje).
   *
   * GET /impact/summary/week
   */
  @Get('summary/week')
  getWeeklySummary(@CurrentUser() user: JwtPayload) {
    return this.impactService.getWeeklySummary(user.sub);
  }

  /**
   * Resumo dos últimos N dias (inclui hoje).
   *
   * GET /impact/summary/days?days=30
   * Se `days` não for fornecido, assume 7.
   */
  @Get('summary/days')
  getSummaryForLastDays(@CurrentUser() user: JwtPayload, @Query('days') days = '7') {
    return this.impactService.getSummaryForLastDays(user.sub, Number(days));
  }

  /**
   * Resumo para um intervalo arbitrário de datas.
   *
   * GET /impact/summary/range?from=2025-01-01&to=2025-01-31
   */
  @Get('summary/range')
  getSummaryForRange(
    @CurrentUser() user: JwtPayload,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    const fromDate = new Date(from);
    const toDate = new Date(to);
    return this.impactService.getSummaryForRange(user.sub, fromDate, toDate);
  }

  /**
   * Resumo all-time (desde a primeira viagem até ao momento atual).
   *
   * GET /impact/summary/all-time
   */
  @Get('summary/all-time')
  getAllTimeSummary(@CurrentUser() user: JwtPayload) {
    return this.impactService.getAllTimeSummary(user.sub);
  }

  /**
   * Timeline de agregados EcoStatsAggregate para gráficos/estatísticas.
   *
   * GET /impact/stats/timeline?type=DAY&limit=30
   *
   * `type` pode ser: DAY, WEEK, MONTH, YEAR (default: DAY).
   * `limit` controla quantos períodos devolver (default: 30).
   */
  @Get('stats/timeline')
  getEcoStatsTimeline(
    @CurrentUser() user: JwtPayload,
    @Query('type') type: EcoPeriodType = EcoPeriodType.DAY,
    @Query('limit') limit = '30',
  ) {
    return this.impactService.getEcoStatsTimeline(user.sub, type, Number(limit));
  }
}
