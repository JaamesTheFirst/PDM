// src/impact/impact.controller.ts
import {
  Controller,
  Get,
  Query,
  UseGuards,
} from '@nestjs/common';
import { ImpactService } from './impact.service';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload } from '../auth/types/jwt-payload.type';
import { EcoPeriodType } from '@prisma/client';

@Controller('impact')
@UseGuards(JwtAuthGuard)
export class ImpactController {
  constructor(private readonly impactService: ImpactService) {}

  /** Resumo da última semana (inclui hoje) */
  @Get('summary/week')
  getWeeklySummary(@CurrentUser() user: JwtPayload) {
    return this.impactService.getWeeklySummary(user.sub);
  }

  /** Resumo dos últimos N dias (ex: ?days=30) */
  @Get('summary/days')
  getSummaryForLastDays(
    @CurrentUser() user: JwtPayload,
    @Query('days') days = '7',
  ) {
    return this.impactService.getSummaryForLastDays(
      user.sub,
      Number(days),
    );
  }

  /** Resumo por intervalo arbitrário ?from=2025-01-01&to=2025-01-31 */
  @Get('summary/range')
  getSummaryForRange(
    @CurrentUser() user: JwtPayload,
    @Query('from') from: string,
    @Query('to') to: string,
  ) {
    const fromDate = new Date(from);
    const toDate = new Date(to);
    return this.impactService.getSummaryForRange(
      user.sub,
      fromDate,
      toDate,
    );
  }

  /** Resumo all-time (desde a primeira viagem) */
  @Get('summary/all-time')
  getAllTimeSummary(@CurrentUser() user: JwtPayload) {
    return this.impactService.getAllTimeSummary(user.sub);
  }

  /**
   * Timeline de agregados (EcoStatsAggregate) – ex:
   * /impact/stats/timeline?type=DAY&limit=30
   */
  @Get('stats/timeline')
  getEcoStatsTimeline(
    @CurrentUser() user: JwtPayload,
    @Query('type') type: EcoPeriodType = EcoPeriodType.DAY,
    @Query('limit') limit = '30',
  ) {
    return this.impactService.getEcoStatsTimeline(
      user.sub,
      type,
      Number(limit),
    );
  }
}
