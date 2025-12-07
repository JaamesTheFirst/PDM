// src/routes/routes.service.ts
import {
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
  Prisma,
  RouteStatus,
  TransportMode as PrismaTransportMode,
  EcoPeriodType,
} from '@prisma/client';
import { OtpService, OtpItinerary, OtpLeg } from './otp.service';
import {
  PlanItineraryDto,
  FilterMode,
  TransportMode,
} from './dto/plan-itinerary.dto';
import { PlanGranularDto } from './dto/plan-granular.dto';
import { SaveRouteDto } from './dto/save-route.dto';
import { ListHistoryQueryDto } from './dto/list-history.dto';
import { ImpactService } from '../impact/impact.service';

export interface EnrichedItinerary extends OtpItinerary {
  modes: string[];
  primaryMode: string;
  totalDistanceMeters: number;
  totalWalkDistanceMeters: number;
  hasBus: boolean;
  hasRail: boolean;
  hasCar: boolean;
  hasBicycle: boolean;
}

export interface PlannedRoutesResponse {
  originalItineraryCount: number;
  filteredItineraryCount: number;
  filterApplied: {
    filterMode: FilterMode;
    maxWalkDistanceMeters?: number;
  };
  itineraries: EnrichedItinerary[];
}

@Injectable()
export class RoutesService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly otp: OtpService,
    private readonly impact: ImpactService, // 👈 para atualizar EcoStatsAggregate
  ) {}

  // === CO2 / ECO HELPERS (mesma lógica do frontend) ===

  // kg CO2 / km para cada modo (valores médios PT/EU)
  private readonly defaultEmissionFactors: Record<string, number> = {
    WALK: 0.0,
    WALKING: 0.0,
    BICYCLE: 0.0,
    BIKE: 0.0,
    BIKE_SHARE: 0.0,
    SCOOTER: 0.0,
    SCOOTER_SHARE: 0.0,
    BUS: 0.089,
    TRAM: 0.03,
    METRO: 0.03,
    RAIL: 0.014,
    TRAIN: 0.014,
    R: 0.014,
    IC: 0.014,
    CAR: 0.12,
    TAXI: 0.12,
    EV_CAR: 0.0,
    COACH: 0.027,
    FLIXBUS: 0.027,
  };

  // ocupação média (passageiros por veículo)
  private readonly defaultOccupancyRates: Record<string, number> = {
    BUS: 20,
    TRAM: 50,
    METRO: 100,
    RAIL: 150,
    TRAIN: 150,
    R: 150,
    IC: 150,
    COACH: 30,
    FLIXBUS: 30,
    CAR: 1.5,
    TAXI: 1,
  };

  // baseline carro (kg CO2 / km) – igual ao ImpactService e EcoScore do frontend
  private readonly baselineCo2PerKm = 0.12;

  private computeItineraryCo2Kg(it: OtpItinerary): number {
    if (!it.legs || it.legs.length === 0) return 0;

    let totalCo2Kg = 0;

    for (const leg of it.legs) {
      const mode = (leg.mode || '').toUpperCase();
      const distanceMeters = leg.distance ?? 0;
      const distanceKm = distanceMeters / 1000;
      if (distanceKm <= 0) continue;

      // emission factor base
      let emissionFactor = this.defaultEmissionFactors[mode] ?? 0;

      // tentar mapear variações do OTP
      if (emissionFactor === 0 && mode !== 'WALK' && mode !== 'WALKING') {
        if (
          mode.includes('RAIL') ||
          mode.includes('TRAIN') ||
          mode === 'R' ||
          mode === 'IC'
        ) {
          emissionFactor = this.defaultEmissionFactors['RAIL'] ?? 0.014;
        } else if (mode.includes('BUS') || mode === 'COACH') {
          emissionFactor = this.defaultEmissionFactors['BUS'] ?? 0.089;
        } else if (mode.includes('METRO') || mode.includes('SUBWAY')) {
          emissionFactor = this.defaultEmissionFactors['METRO'] ?? 0.03;
        } else if (mode.includes('TRAM')) {
          emissionFactor = this.defaultEmissionFactors['TRAM'] ?? 0.03;
        } else if (mode === 'CAR' || mode === 'TAXI') {
          emissionFactor = this.defaultEmissionFactors['CAR'] ?? 0.12;
        }
      }

      // ocupação
      let occupancy = this.defaultOccupancyRates[mode];

      if (
        occupancy == null &&
        mode !== 'WALK' &&
        mode !== 'WALKING'
      ) {
        if (
          mode.includes('RAIL') ||
          mode.includes('TRAIN') ||
          mode === 'R' ||
          mode === 'IC'
        ) {
          occupancy = mode === 'IC' ? 120 : 150;
        } else if (mode.includes('BUS') || mode === 'COACH') {
          occupancy =
            mode === 'FLIXBUS' || mode === 'COACH' ? 30 : 20;
        } else if (mode.includes('METRO') || mode.includes('SUBWAY')) {
          occupancy = 100;
        } else if (mode.includes('TRAM')) {
          occupancy = 50;
        }
      }

      let legCo2Kg: number;
      if (occupancy && occupancy > 0) {
        // transporte coletivo – dividir pela ocupação
        legCo2Kg = (emissionFactor * distanceKm) / occupancy;
      } else {
        // WALK / BIKE / CAR etc
        legCo2Kg = emissionFactor * distanceKm;
      }

      totalCo2Kg += legCo2Kg;
    }

    // nunca devolver valores negativos / NaN
    if (!Number.isFinite(totalCo2Kg) || totalCo2Kg < 0) {
      return 0;
    }
    return totalCo2Kg;
  }

  // ========== Helpers de modos / filtros ==========

  private mapOtpModeToPrisma(
    mode: string,
  ): PrismaTransportMode | null {
    switch (mode) {
      case 'WALK':
        return PrismaTransportMode.WALKING;
      case 'BICYCLE':
        return PrismaTransportMode.BIKE;
      case 'SCOOTER':
        return PrismaTransportMode.SCOOTER;
      case 'BUS':
        return PrismaTransportMode.BUS;
      case 'RAIL':
      case 'TRAIN':
        return PrismaTransportMode.TRAIN;
      case 'SUBWAY':
      case 'TRAM':
      case 'METRO':
        return PrismaTransportMode.METRO;
      case 'CAR':
        return PrismaTransportMode.CAR;
      default:
        return null;
    }
  }

  private getPrimaryMode(it: OtpItinerary): PrismaTransportMode {
    const nonWalkLegs = it.legs.filter((l) => l.mode !== 'WALK');
    if (nonWalkLegs.length === 0) {
      return PrismaTransportMode.WALKING;
    }
    const longest = nonWalkLegs.reduce((a, b) =>
      a.distance > b.distance ? a : b,
    );
    return (
      this.mapOtpModeToPrisma(longest.mode) ??
      PrismaTransportMode.WALKING
    );
  }

  private getModes(it: OtpItinerary): PrismaTransportMode[] {
    const set = new Set<PrismaTransportMode>();
    for (const leg of it.legs) {
      const mapped = this.mapOtpModeToPrisma(leg.mode);
      if (mapped) set.add(mapped);
    }
    if (set.size === 0) set.add(PrismaTransportMode.WALKING);
    return Array.from(set);
  }

  private enrichItinerary(it: OtpItinerary): EnrichedItinerary {
    const modesSet = new Set<string>(it.legs.map((l) => l.mode));
    const nonWalkLegs = it.legs.filter((l) => l.mode !== 'WALK');

    const primary =
      nonWalkLegs.length === 0
        ? 'WALK'
        : nonWalkLegs.reduce((a, b) =>
            a.distance > b.distance ? a : b,
          ).mode;

    const totalDistanceMeters = Math.round(
      it.legs.reduce(
        (sum, l) => sum + (l.distance || 0),
        0,
      ),
    );

    const totalWalkDistanceMeters = Math.round(
      it.legs
        .filter((l) => l.mode === 'WALK')
        .reduce(
          (sum, l) => sum + (l.distance || 0),
          0,
        ),
    );

    const modes = Array.from(modesSet);

    return {
      ...it,
      modes,
      primaryMode: primary,
      totalDistanceMeters,
      totalWalkDistanceMeters,
      hasBus: modes.includes('BUS'),
      hasRail: modes.includes('RAIL') || modes.includes('TRAIN'),
      hasCar: modes.includes('CAR'),
      hasBicycle: modes.includes('BICYCLE'),
    };
  }

  private passesFilterMode(
    it: EnrichedItinerary,
    filterMode: FilterMode,
  ): boolean {
    const nonWalkModes = new Set(
      it.legs
        .filter((l) => l.mode !== 'WALK')
        .map((l) => l.mode),
    );

    switch (filterMode) {
      case FilterMode.WALK_ONLY:
        return nonWalkModes.size === 0;

      case FilterMode.BUS_ONLY:
        return (
          it.modes.includes('BUS') &&
          Array.from(nonWalkModes).every((m) => m === 'BUS')
        );

      case FilterMode.RAIL_ONLY:
        return (
          (it.modes.includes('RAIL') ||
            it.modes.includes('TRAIN')) &&
          Array.from(nonWalkModes).every(
            (m) => m === 'RAIL' || m === 'TRAIN',
          )
        );

      case FilterMode.METRO_ONLY:
        return (
          (it.modes.includes('SUBWAY') ||
            it.modes.includes('TRAM') ||
            it.modes.includes('METRO')) &&
          Array.from(nonWalkModes).every(
            (m) =>
              m === 'SUBWAY' ||
              m === 'TRAM' ||
              m === 'METRO',
          )
        );

      case FilterMode.CAR_ONLY:
        return (
          it.modes.includes('CAR') &&
          Array.from(nonWalkModes).every((m) => m === 'CAR')
        );

      case FilterMode.BICYCLE_ONLY:
        return (
          it.modes.includes('BICYCLE') &&
          Array.from(nonWalkModes).every(
            (m) => m === 'BICYCLE',
          )
        );

      case FilterMode.ANY:
      default:
        return true;
    }
  }

  // ========== Planeamento + filtro no backend ==========

  async planAndFilter(
    dto: PlanItineraryDto,
  ): Promise<PlannedRoutesResponse> {
    const otpPlan = await this.otp.plan(dto);
    const original = otpPlan.itineraries || [];
    const enriched = original.map((it) =>
      this.enrichItinerary(it),
    );

    const filterMode = dto.filterMode ?? FilterMode.ANY;
    const maxWalk = dto.maxWalkDistanceMeters;

    const filtered = enriched.filter((it) => {
      if (typeof maxWalk === 'number') {
        if (it.totalWalkDistanceMeters > maxWalk) return false;
      }
      if (!this.passesFilterMode(it, filterMode)) return false;
      return true;
    });

    return {
      originalItineraryCount: original.length,
      filteredItineraryCount: filtered.length,
      filterApplied: {
        filterMode,
        maxWalkDistanceMeters: maxWalk,
      },
      itineraries: filtered,
    };
  }

  // ========== Planeamento granular ==========

  async planGranular(
    dto: PlanGranularDto,
  ): Promise<PlannedRoutesResponse> {
    const baseModes =
      dto.baseModes && dto.baseModes.length > 0
        ? dto.baseModes.map((m) => m as TransportMode)
        : [TransportMode.WALK, TransportMode.TRANSIT];

    const planDto: PlanItineraryDto = {
      fromLat: dto.fromLat,
      fromLon: dto.fromLon,
      toLat: dto.toLat,
      toLon: dto.toLon,
      dateTime: dto.dateTime,
      date: dto.date,
      time: dto.time,
      numItineraries: dto.numItineraries ?? 5,
      modes: baseModes,
      maxWalkDistanceMeters: dto.maxWalkDistanceMeters,
    };

    const otpPlan = await this.otp.plan(planDto);
    const original = otpPlan.itineraries || [];
    const enriched = original.map((it) =>
      this.enrichItinerary(it),
    );

    let filtered = enriched;
    if (dto.transitTypes && dto.transitTypes.length > 0) {
      filtered = enriched.filter((it) => {
        const nonWalkModes = new Set(
          it.legs
            .filter((l) => l.mode !== 'WALK')
            .map((l) => l.mode),
        );

        const transitTypesInItinerary = new Set<string>();

        for (const leg of it.legs) {
          const mode = leg.mode.toUpperCase();
          if (mode === 'WALK' || mode === 'WALKING') continue;

          if (mode === 'BUS' || mode.includes('BUS')) {
            transitTypesInItinerary.add('BUS');
          } else if (
            mode === 'RAIL' ||
            mode === 'TRAIN' ||
            mode === 'R' ||
            mode === 'IC'
          ) {
            transitTypesInItinerary.add('RAIL');
          } else if (
            mode === 'METRO' ||
            mode === 'SUBWAY'
          ) {
            transitTypesInItinerary.add('METRO');
          } else if (mode === 'TRAM') {
            transitTypesInItinerary.add('TRAM');
          } else if (
            mode === 'BICYCLE' ||
            mode === 'BIKE' ||
            mode.includes('BIKE')
          ) {
            // Use rentedBike field from OTP for reliable bike-share detection
            const isBikeShare = leg.rentedBike === true ||
              mode.includes('SHARE') ||
              leg.route?.longName
                ?.toUpperCase()
                .includes('GIRA') ||
              leg.route?.longName
                ?.toUpperCase()
                .includes('BIKE SHARE') ||
              leg.route?.shortName
                ?.toUpperCase()
                .includes('GIRA');

            if (isBikeShare) {
              transitTypesInItinerary.add('BICYCLE_SHARE');
            }
          } else if (
            mode === 'SCOOTER' ||
            mode.includes('SCOOTER')
          ) {
            const isScooterShare =
              mode.includes('SHARE') ||
              leg.route?.longName
                ?.toUpperCase()
                .includes('SCOOTER SHARE');

            if (isScooterShare) {
              transitTypesInItinerary.add('SCOOTER_SHARE');
            }
          }
        }

        if (transitTypesInItinerary.size === 0) {
          const hasWalk =
            nonWalkModes.size === 0 &&
            baseModes.includes(TransportMode.WALK);
          const hasBicycle =
            nonWalkModes.has('BICYCLE') &&
            baseModes.includes(TransportMode.BICYCLE);
          const hasCar =
            nonWalkModes.has('CAR') &&
            baseModes.includes(TransportMode.CAR);
          return hasWalk || hasBicycle || hasCar;
        }

        const selectedTypes = new Set(
          dto.transitTypes.map((t) => t.toUpperCase()),
        );

        for (const type of transitTypesInItinerary) {
          if (!selectedTypes.has(type)) {
            return false;
          }
        }

        return true;
      });
    }

    if (typeof dto.maxWalkDistanceMeters === 'number') {
      filtered = filtered.filter(
        (it) =>
          it.totalWalkDistanceMeters <=
          dto.maxWalkDistanceMeters!,
      );
    }

    return {
      originalItineraryCount: original.length,
      filteredItineraryCount: filtered.length,
      filterApplied: {
        filterMode: FilterMode.ANY,
        maxWalkDistanceMeters: dto.maxWalkDistanceMeters,
      },
      itineraries: filtered,
    };
  }

  // ========== Histórico (guardar + listar) ==========

  private buildSegments(it: OtpItinerary) {
    return it.legs.map((leg: OtpLeg) => ({
      type: leg.mode === 'WALK' ? 'WALK' : 'TRANSIT',
      mode: leg.mode,
      distanceMeters: Math.round(leg.distance),
      durationSeconds: Math.round(leg.duration),
      from: {
        name: leg.from.name,
        lat: leg.from.lat,
        lon: leg.from.lon,
      },
      to: {
        name: leg.to.name,
        lat: leg.to.lat,
        lon: leg.to.lon,
      },
      route: leg.route ?? null,
      polyline: leg.legGeometry?.points ?? null,
    }));
  }

  async saveItineraryForUser(
    userId: string,
    dto: SaveRouteDto,
  ) {
    const it = dto.itinerary;
    if (!it || !it.legs || it.legs.length === 0) {
      throw new Error('Itinerary inválido (sem legs)');
    }

    const firstLeg = it.legs[0];
    const lastLeg = it.legs[it.legs.length - 1];

    let originName = dto.originName?.trim();
    if (!originName || originName.length === 0) {
      originName = firstLeg.from.name || 'Origem';
    }

    const originLatitude =
      dto.originLatitude ?? firstLeg.from.lat;
    const originLongitude =
      dto.originLongitude ?? firstLeg.from.lon;

    let destinationName = dto.destinationName?.trim();
    if (!destinationName || destinationName.length === 0) {
      destinationName = lastLeg.to.name || 'Destino';
    }

    const destinationLatitude =
      dto.destinationLatitude ?? lastLeg.to.lat;
    const destinationLongitude =
      dto.destinationLongitude ?? lastLeg.to.lon;

    const distanceMeters = Math.round(
      it.legs.reduce(
        (sum, leg) => sum + (leg.distance || 0),
        0,
      ),
    );
    const durationSeconds = Math.round(it.duration);

    const startedAt = new Date(firstLeg.startTime);
    const finishedAt = new Date(lastLeg.endTime);

    const primaryMode = this.getPrimaryMode(it);
    const modes = this.getModes(it);
    const segments = this.buildSegments(it);

    // ==== CO2 & poupança vs carro ====
    const distanceKm = distanceMeters / 1000;
    const baselineCarKg = this.baselineCo2PerKm * distanceKm;

    const co2KgRaw = this.computeItineraryCo2Kg(it);
    const co2Kg = Math.max(0, co2KgRaw);

    let co2SavedVsCarKg = baselineCarKg - co2Kg;
    if (!Number.isFinite(co2SavedVsCarKg) || co2SavedVsCarKg < 0) {
      co2SavedVsCarKg = 0;
    }

    const data: Prisma.RouteHistoryCreateInput = {
      user: { connect: { id: userId } },

      originName,
      originLatitude,
      originLongitude,
      destinationName,
      destinationLatitude,
      destinationLongitude,

      primaryMode,
      modes,

      distanceMeters,
      durationSeconds,
      co2Kg,
      co2SavedVsCarKg,

      // podes deixar PLANNED se quiseres – o ImpactService ignora só CANCELLED
      status: RouteStatus.PLANNED,
      startedAt,
      finishedAt,

      polyline: null,
      segments,
      metadata: it as any,
    };

    const created = await this.prisma.routeHistory.create({
      data,
    });

    // Atualizar eco_stats_aggregate (DAY / MONTH / YEAR)
    await this.impact.updateAggregatesForTrip(created.id);

    return created;
  }

  async listHistoryForUser(
    userId: string,
    query: ListHistoryQueryDto,
  ) {
    const where: Prisma.RouteHistoryWhereInput = { userId };

    if (query.status && query.status in RouteStatus) {
      where.status = query.status as RouteStatus;
    }

    if (
      query.primaryMode &&
      query.primaryMode in PrismaTransportMode
    ) {
      where.primaryMode =
        query.primaryMode as PrismaTransportMode;
    }

    return this.prisma.routeHistory.findMany({
      where,
      orderBy: { createdAt: 'desc' },
      take: query.limit ?? 20,
    });
  }

  async getHistoryById(userId: string, id: string) {
    const item = await this.prisma.routeHistory.findFirst({
      where: { id, userId },
    });

    if (!item) {
      throw new NotFoundException('Route history not found');
    }

    return item;
  }
}
