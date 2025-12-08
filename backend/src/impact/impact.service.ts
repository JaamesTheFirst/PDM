// src/impact/impact.service.ts
import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { ImpactDayBucketDto, ImpactSummaryDto } from './dto/impact-summary.dto';
import { EcoPeriodType, RouteStatus, TransportMode } from '@prisma/client';

/**
 * Serviço de cálculo e agregação de impacto ecológico.
 *
 * Responsabilidades principais:
 *  - calcular resumos de impacto (CO2, distâncias, ecoScore) a partir de RouteHistory
 *  - manter a tabela EcoStatsAggregate (períodos DAY/MONTH/YEAR)
 *  - fornecer timelines de agregados para gráficos.
 */
@Injectable()
export class ImpactService {
  // mesmo baseline que usas no EcoScoreService do frontend (kg CO2 / km)
  private readonly baselineCo2PerKm = 0.12;
  private readonly maxCo2PerKm = 0.2;

  constructor(private readonly prisma: PrismaService) {}

  // ========= PUBLIC API: RESUMOS =========

  /**
   * Resumo dos últimos 7 dias (inclui hoje).
   *
   * Usa `startedAt` das viagens para delimitar o intervalo.
   */
  async getWeeklySummary(userId: string): Promise<ImpactSummaryDto> {
    const now = new Date();
    const periodEnd = this.endOfDay(now);

    const periodStart = this.startOfDay(new Date(now.getTime() - 6 * 24 * 60 * 60 * 1000));

    const histories = await this.loadHistories(userId, periodStart, periodEnd);
    return this.buildSummaryFromHistories(histories, periodStart, periodEnd);
  }

  /**
   * Resumo dos últimos N dias (ex: 30).
   *
   * Protegido para [1, 365] dias.
   */
  async getSummaryForLastDays(userId: string, days: number): Promise<ImpactSummaryDto> {
    if (!Number.isFinite(days) || days <= 0 || days > 365) {
      throw new BadRequestException('Número inválido de dias.');
    }

    const now = new Date();
    const periodEnd = this.endOfDay(now);
    const periodStart = this.startOfDay(new Date(now.getTime() - (days - 1) * 24 * 60 * 60 * 1000));

    const histories = await this.loadHistories(userId, periodStart, periodEnd);
    return this.buildSummaryFromHistories(histories, periodStart, periodEnd);
  }

  /**
   * Resumo num intervalo de datas arbitrário [from, to].
   *
   * Se `from > to`, lança BadRequestException.
   */
  async getSummaryForRange(userId: string, from: Date, to: Date): Promise<ImpactSummaryDto> {
    if (from > to) {
      throw new BadRequestException('"from" não pode ser depois de "to".');
    }

    const periodStart = this.startOfDay(from);
    const periodEnd = this.endOfDay(to);

    const histories = await this.loadHistories(userId, periodStart, periodEnd);
    return this.buildSummaryFromHistories(histories, periodStart, periodEnd);
  }

  /**
   * Resumo all-time: desde a primeira viagem do utilizador até agora.
   *
   * Se o utilizador nunca fez viagens, devolve summary vazio com o dia atual.
   */
  async getAllTimeSummary(userId: string): Promise<ImpactSummaryDto> {
    const firstTrip = await this.prisma.routeHistory.findFirst({
      where: { userId },
      orderBy: { createdAt: 'asc' },
    });

    if (!firstTrip) {
      // user nunca fez viagem → devolve summary vazio
      const now = new Date();
      const start = this.startOfDay(now);
      const end = this.endOfDay(now);
      return this.buildEmptySummary(start, end);
    }

    const periodStart = this.startOfDay(firstTrip.startedAt);
    const periodEnd = this.endOfDay(new Date());

    const histories = await this.loadHistories(userId, periodStart, periodEnd);
    return this.buildSummaryFromHistories(histories, periodStart, periodEnd);
  }

  // ========= PUBLIC API: ECO STATS AGGREGATE =========

  /**
   * Atualiza agregados EcoStatsAggregate para uma viagem específica.
   *
   * Deve ser chamado quando uma RouteHistory é criada ou atualizada,
   * de forma a manter os agregados coerentes.
   */
  async updateAggregatesForTrip(tripId: string): Promise<void> {
    const trip = await this.prisma.routeHistory.findUnique({
      where: { id: tripId },
    });

    if (!trip) {
      throw new NotFoundException('RouteHistory não encontrado');
    }

    // viagem cancelada não conta para estatísticas
    if (trip.status === RouteStatus.CANCELLED) {
      return;
    }

    const distanceMeters = trip.distanceMeters ?? 0;
    const durationSeconds = trip.durationSeconds ?? 0;
    const co2Kg = typeof trip.co2Kg === 'number' ? trip.co2Kg : 0;

    const distanceKm = distanceMeters / 1000;
    const baselineCarKg = this.baselineCo2PerKm * distanceKm;

    // se co2SavedVsCarKg não existir ou for <= 0, recalculamos
    let co2Saved: number;
    if (typeof trip.co2SavedVsCarKg === 'number' && trip.co2SavedVsCarKg > 0) {
      co2Saved = trip.co2SavedVsCarKg;
    } else {
      co2Saved = baselineCarKg - co2Kg;
    }
    if (co2Saved < 0) co2Saved = 0;

    // ecoScore calculado a partir dos dados da viagem
    const ecoScore = this.computeEcoScoreForTrip(trip);

    // referência temporal para buckets DAY/MONTH/YEAR
    const refDate = trip.createdAt ?? trip.finishedAt ?? trip.startedAt;

    for (const type of [EcoPeriodType.DAY, EcoPeriodType.MONTH, EcoPeriodType.YEAR]) {
      const period = this.getPeriodKey(refDate, type);

      await this.prisma.ecoStatsAggregate.upsert({
        where: {
          userId_period_periodType: {
            userId: trip.userId,
            period,
            periodType: type,
          },
        },
        create: {
          userId: trip.userId,
          period,
          periodType: type,
          totalDistanceMeters: distanceMeters,
          totalDurationSeconds: durationSeconds,
          totalCo2Kg: co2Kg,
          co2SavedVsCarKg: co2Saved,
          totalEcoScore: ecoScore,
          tripsCount: 1,
        },
        update: {
          totalDistanceMeters: { increment: distanceMeters },
          totalDurationSeconds: { increment: durationSeconds },
          totalCo2Kg: { increment: co2Kg },
          co2SavedVsCarKg: { increment: co2Saved },
          totalEcoScore: { increment: ecoScore },
          tripsCount: { increment: 1 },
        },
      });
    }
  }

  /**
   * Reconstrói todos os agregados EcoStatsAggregate de um utilizador.
   *
   * Útil se mudares a lógica de ecoScore ou se quiseres fazer um reset
   * completo de estatísticas a partir do histórico de viagens.
   */
  async rebuildAggregatesForUser(userId: string): Promise<void> {
    // apaga agregados atuais
    await this.prisma.ecoStatsAggregate.deleteMany({ where: { userId } });

    // carrega todas as viagens (exceto CANCELLED)
    const trips = await this.prisma.routeHistory.findMany({
      where: {
        userId,
        status: { not: RouteStatus.CANCELLED },
      },
    });

    for (const trip of trips) {
      const distanceMeters = trip.distanceMeters ?? 0;
      const durationSeconds = trip.durationSeconds ?? 0;
      const co2Kg = typeof trip.co2Kg === 'number' ? trip.co2Kg : 0;

      const distanceKm = distanceMeters / 1000;
      const baselineCarKg = this.baselineCo2PerKm * distanceKm;

      let co2Saved: number;
      if (typeof trip.co2SavedVsCarKg === 'number' && trip.co2SavedVsCarKg > 0) {
        co2Saved = trip.co2SavedVsCarKg;
      } else {
        co2Saved = baselineCarKg - co2Kg;
      }
      if (co2Saved < 0) co2Saved = 0;

      const ecoScore = this.computeEcoScoreForTrip(trip);
      const refDate = trip.createdAt ?? trip.finishedAt ?? trip.startedAt;

      for (const type of [EcoPeriodType.DAY, EcoPeriodType.MONTH, EcoPeriodType.YEAR]) {
        const period = this.getPeriodKey(refDate, type);

        await this.prisma.ecoStatsAggregate.upsert({
          where: {
            userId_period_periodType: {
              userId,
              period,
              periodType: type,
            },
          },
          create: {
            userId,
            period,
            periodType: type,
            totalDistanceMeters: distanceMeters,
            totalDurationSeconds: durationSeconds,
            totalCo2Kg: co2Kg,
            co2SavedVsCarKg: co2Saved,
            totalEcoScore: ecoScore,
            tripsCount: 1,
          },
          update: {
            totalDistanceMeters: { increment: distanceMeters },
            totalDurationSeconds: { increment: durationSeconds },
            totalCo2Kg: { increment: co2Kg },
            co2SavedVsCarKg: { increment: co2Saved },
            totalEcoScore: { increment: ecoScore },
            tripsCount: { increment: 1 },
          },
        });
      }
    }
  }

  /**
   * Devolve a timeline de EcoStatsAggregate para um determinado tipo
   * (DAY / MONTH / YEAR), limitada a `limit` registos.
   */
  async getEcoStatsTimeline(userId: string, type: EcoPeriodType, limit = 30) {
    if (limit <= 0 || limit > 365) {
      throw new BadRequestException('Limit inválido.');
    }

    const rows = await this.prisma.ecoStatsAggregate.findMany({
      where: {
        userId,
        periodType: type,
      },
      orderBy: {
        period: 'desc',
      },
      take: limit,
    });

    // devolve em ordem cronológica ascendente
    return rows.reverse();
  }

  // ========= HELPERS PRIVADOS =========

  private startOfDay(d: Date): Date {
    const copy = new Date(d);
    copy.setHours(0, 0, 0, 0);
    return copy;
  }

  private endOfDay(d: Date): Date {
    const copy = new Date(d);
    copy.setHours(23, 59, 59, 999);
    return copy;
  }

  /**
   * Calcula a chave de período (string) para EcoStatsAggregate,
   * em função do tipo (DAY, MONTH, YEAR).
   *
   * Exemplos:
   *  - DAY   → "2025-12-03"
   *  - MONTH → "2025-12"
   *  - YEAR  → "2025"
   */
  private getPeriodKey(date: Date, type: EcoPeriodType): string {
    const y = date.getUTCFullYear();
    const m = date.getUTCMonth() + 1;
    const d = date.getUTCDate();

    switch (type) {
      case EcoPeriodType.DAY:
        // YYYY-MM-DD
        return (
          `${y.toString().padStart(4, '0')}-` +
          `${m.toString().padStart(2, '0')}-` +
          `${d.toString().padStart(2, '0')}`
        );
      case EcoPeriodType.MONTH:
        // YYYY-MM
        return `${y.toString().padStart(4, '0')}-` + `${m.toString().padStart(2, '0')}`;
      case EcoPeriodType.YEAR:
      default:
        // YYYY
        return y.toString();
    }
  }

  /**
   * Lê RouteHistory no intervalo [start, end], usando `startedAt` como filtro.
   * Ignora viagens com status CANCELLED e ordena por `createdAt` ascendente.
   */
  private async loadHistories(userId: string, start: Date, end: Date) {
    return this.prisma.routeHistory.findMany({
      where: {
        userId,
        startedAt: {
          gte: start,
          lte: end,
        },
        status: {
          not: RouteStatus.CANCELLED,
        },
      },
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * Constrói um resumo vazio (sem viagens) para o período indicado.
   */
  private buildEmptySummary(periodStart: Date, periodEnd: Date): ImpactSummaryDto {
    return {
      periodStart: periodStart.toISOString(),
      periodEnd: periodEnd.toISOString(),

      totalCo2Kg: 0,
      totalCo2SavedKg: 0,
      totalDistanceKm: 0,
      totalTrips: 0,

      ecoTrips: 0,
      ecoTripsRatio: 0,

      activeTrips: 0,
      activeTripsRatio: 0,

      avgEcoScore: 0,

      days: [],
    };
  }

  /**
   * Agrega uma lista de RouteHistory num ImpactSummaryDto,
   * calculando totais, rácios e buckets diários.
   */
  private buildSummaryFromHistories(
    histories: any[],
    periodStart: Date,
    periodEnd: Date,
  ): ImpactSummaryDto {
    if (!histories || histories.length === 0) {
      return this.buildEmptySummary(periodStart, periodEnd);
    }

    const bucketsMap = new Map<string, ImpactDayBucketDto>();

    let totalCo2Kg = 0;
    let totalCo2SavedKg = 0;
    let totalDistanceKm = 0;
    let totalTrips = 0;
    let ecoTrips = 0;
    let activeTrips = 0;

    // acumulador para média de ecoScore
    let totalEcoScore = 0;

    for (const trip of histories) {
      totalTrips += 1;

      const distanceKm = (trip.distanceMeters ?? 0) / 1000;
      const co2Kg = typeof trip.co2Kg === 'number' ? trip.co2Kg : 0;

      const baselineCarKg = this.baselineCo2PerKm * distanceKm;

      let co2Saved: number;
      if (typeof trip.co2SavedVsCarKg === 'number' && trip.co2SavedVsCarKg > 0) {
        co2Saved = trip.co2SavedVsCarKg;
      } else {
        co2Saved = baselineCarKg - co2Kg;
      }
      if (co2Saved < 0) co2Saved = 0;

      totalDistanceKm += distanceKm;
      totalCo2Kg += co2Kg;
      totalCo2SavedKg += co2Saved;

      // viagem “eco” se emitir menos que o baseline de carro
      if (co2Kg < baselineCarKg) {
        ecoTrips += 1;
      }

      // viagem “ativa” se tiver pelo menos um modo físico
      const modes = (trip.modes ?? []) as TransportMode[];
      const hasActive = modes.some(m =>
        ['WALKING', 'BIKE', 'BIKE_SHARE', 'SCOOTER', 'SCOOTER_SHARE'].includes(m),
      );
      if (hasActive) {
        activeTrips += 1;
      }

      // ecoScore individual da viagem
      const ecoScore = this.computeEcoScoreForTrip(trip);
      totalEcoScore += ecoScore;

      // bucket diário: usamos uma data de referência (createdAt/finishedAt/startedAt)
      const refDate: Date = trip.createdAt ?? trip.finishedAt ?? trip.startedAt;
      const dateKey = refDate.toISOString().slice(0, 10); // YYYY-MM-DD

      let bucket = bucketsMap.get(dateKey);
      if (!bucket) {
        bucket = {
          date: dateKey,
          totalCo2Kg: 0,
          totalCo2SavedKg: 0,
          totalDistanceKm: 0,
          trips: 0,
        };
        bucketsMap.set(dateKey, bucket);
      }

      bucket.totalCo2Kg += co2Kg;
      bucket.totalCo2SavedKg += co2Saved;
      bucket.totalDistanceKm += distanceKm;
      bucket.trips += 1;
    }

    const days = Array.from(bucketsMap.values()).sort((a, b) => a.date.localeCompare(b.date));

    const avgEcoScore = totalTrips > 0 ? totalEcoScore / totalTrips : 0;

    const summary: ImpactSummaryDto = {
      periodStart: periodStart.toISOString(),
      periodEnd: periodEnd.toISOString(),

      totalCo2Kg,
      totalCo2SavedKg,
      totalDistanceKm,
      totalTrips,

      ecoTrips,
      ecoTripsRatio: totalTrips > 0 ? ecoTrips / totalTrips : 0,

      activeTrips,
      activeTripsRatio: totalTrips > 0 ? activeTrips / totalTrips : 0,

      avgEcoScore,

      days,
    };

    return summary;
  }

  /**
   * Lógica simplificada de EcoScore para uma RouteHistory.
   *
   * Usa apenas os campos disponíveis no histórico:
   *  - distanceMeters
   *  - co2Kg
   *  - modes
   *
   * O objetivo é aproximar o score do frontend sem precisar de todas
   * as pernas/legs da viagem.
   */
  private computeEcoScoreForTrip(trip: any): number {
    const distanceMeters: number = trip.distanceMeters ?? 0;
    const co2Kg: number = trip.co2Kg ?? 0;
    const modes: string[] = (trip.modes ?? []) as string[];

    const distanceKm = distanceMeters > 0 ? distanceMeters / 1000 : 0;
    const co2PerKm = distanceKm > 0 ? co2Kg / distanceKm : 0;

    // modos “zero emissão”
    const zeroEmission = new Set([
      'WALK',
      'WALKING',
      'BICYCLE',
      'BIKE',
      'BIKE_SHARE',
      'SCOOTER',
      'SCOOTER_SHARE',
    ]);

    const carModes = ['CAR', 'TAXI', 'EV_CAR'];
    const hasCarMode = modes.some(m => carModes.includes(m));
    const hasNonCarMode = modes.some(m => !carModes.includes(m));
    const isCarOnly = hasCarMode && !hasNonCarMode;

    const hasPhysicalActivity = modes.some(m => zeroEmission.has(m));

    const isOnlyZeroEmission = modes.length > 0 && modes.every(m => zeroEmission.has(m));

    const hasFossilBus = modes.some(
      m => m.includes('BUS') && !m.includes('ELECTRIC') && !m.includes('HYBRID'),
    );

    let baseScore = 0;

    if (isOnlyZeroEmission && co2PerKm <= 0.0001) {
      baseScore = 100;
    } else if (isCarOnly) {
      const co2PerKmGram = co2PerKm * 1000;
      if (co2PerKmGram >= 120) {
        baseScore = 0;
      } else if (co2PerKmGram >= 80) {
        baseScore = 20 - ((co2PerKmGram - 80) / 40) * 20;
      } else {
        baseScore = 20;
      }
    } else if (co2PerKm >= this.maxCo2PerKm) {
      baseScore = 0;
    } else {
      const co2PerKmGram = co2PerKm * 1000;

      if (co2PerKmGram <= 0.1) {
        baseScore = 95 - (co2PerKmGram / 0.1) * 5;
      } else if (co2PerKmGram <= 1) {
        baseScore = 90 - ((co2PerKmGram - 0.1) / 0.9) * 10;
      } else if (co2PerKmGram <= 5) {
        baseScore = 80 - ((co2PerKmGram - 1) / 4) * 20;
      } else if (co2PerKmGram <= 20) {
        baseScore = 60 - ((co2PerKmGram - 5) / 15) * 20;
      } else if (co2PerKmGram <= 50) {
        baseScore = 40 - ((co2PerKmGram - 20) / 30) * 20;
      } else {
        baseScore = 20 - ((co2PerKmGram - 50) / 150) * 20;
      }

      if (hasFossilBus) {
        baseScore = Math.max(0, baseScore - 18);
      }
    }

    if (hasPhysicalActivity && baseScore < 100) {
      baseScore = Math.min(100, baseScore + 10);
    }

    if (!Number.isFinite(baseScore)) {
      return 0;
    }
    if (baseScore < 0) baseScore = 0;
    if (baseScore > 100) baseScore = 100;

    return Math.round(baseScore);
  }
}
