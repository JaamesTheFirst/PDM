import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
    Prisma,
    RouteStatus,
    TransportMode as PrismaTransportMode,
} from '@prisma/client';
import { OtpService, OtpItinerary, OtpLeg } from './otp.service';
import { PlanItineraryDto, FilterMode } from './dto/plan-itinerary.dto';
import { SaveRouteDto } from './dto/save-route.dto';
import { ListHistoryQueryDto } from './dto/list-history.dto';

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
    ) { }

    // ========== Helpers de modos / filtros ==========

    private mapOtpModeToPrisma(mode: string): PrismaTransportMode | null {
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
        return this.mapOtpModeToPrisma(longest.mode) ?? PrismaTransportMode.WALKING;
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
            it.legs.reduce((sum, l) => sum + (l.distance || 0), 0),
        );

        const totalWalkDistanceMeters = Math.round(
            it.legs
                .filter((l) => l.mode === 'WALK')
                .reduce((sum, l) => sum + (l.distance || 0), 0),
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
            it.legs.filter((l) => l.mode !== 'WALK').map((l) => l.mode),
        );

        switch (filterMode) {
            case FilterMode.WALK_ONLY:
                // só WALK
                return nonWalkModes.size === 0;

            case FilterMode.BUS_ONLY:
                // tem BUS e todos os modos não-WALK são BUS
                return (
                    it.modes.includes('BUS') &&
                    Array.from(nonWalkModes).every((m) => m === 'BUS')
                );

            case FilterMode.RAIL_ONLY:
                return (
                    (it.modes.includes('RAIL') || it.modes.includes('TRAIN')) &&
                    Array.from(nonWalkModes).every(
                        (m) => m === 'RAIL' || m === 'TRAIN',
                    )
                );
            case FilterMode.METRO_ONLY:
                // só metro / subway / tram
                return (
                    (it.modes.includes('SUBWAY') ||
                        it.modes.includes('TRAM') ||
                        it.modes.includes('METRO')) &&
                    Array.from(nonWalkModes).every(
                        (m) => m === 'SUBWAY' || m === 'TRAM' || m === 'METRO',
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
                    Array.from(nonWalkModes).every((m) => m === 'BICYCLE')
                );

            case FilterMode.ANY:
            default:
                return true;
        }
    }

    // ========== Planeamento + filtro no backend ==========

    async planAndFilter(dto: PlanItineraryDto): Promise<PlannedRoutesResponse> {
        const otpPlan = await this.otp.plan(dto);
        const original = otpPlan.itineraries || [];
        const enriched = original.map((it) => this.enrichItinerary(it));

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

    async saveItineraryForUser(userId: string, dto: SaveRouteDto) {
        const it = dto.itinerary;
        if (!it || !it.legs || it.legs.length === 0) {
            throw new Error('Itinerary inválido (sem legs)');
        }

        const firstLeg = it.legs[0];
        const lastLeg = it.legs[it.legs.length - 1];

        const originName = firstLeg.from.name || 'Origin';
        const originLatitude = firstLeg.from.lat;
        const originLongitude = firstLeg.from.lon;

        const destinationName = lastLeg.to.name || 'Destination';
        const destinationLatitude = lastLeg.to.lat;
        const destinationLongitude = lastLeg.to.lon;

        const distanceMeters = Math.round(
            it.legs.reduce((sum, leg) => sum + (leg.distance || 0), 0),
        );
        const durationSeconds = Math.round(it.duration);

        const startedAt = new Date(firstLeg.startTime);
        const finishedAt = new Date(lastLeg.endTime);

        const primaryMode = this.getPrimaryMode(it);
        const modes = this.getModes(it);
        const segments = this.buildSegments(it);

        // TODO: ligar aos EmissionFactor mais tarde
        const co2Kg = 0;
        const co2SavedVsCarKg = 0;

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

            status: RouteStatus.PLANNED,
            startedAt,
            finishedAt,

            polyline: null,
            segments,
            metadata: it as any,
        };

        return this.prisma.routeHistory.create({ data });
    }

    async listHistoryForUser(userId: string, query: ListHistoryQueryDto) {
        const where: Prisma.RouteHistoryWhereInput = { userId };

        if (query.status && query.status in RouteStatus) {
            where.status = query.status as RouteStatus;
        }

        if (query.primaryMode && query.primaryMode in PrismaTransportMode) {
            where.primaryMode = query.primaryMode as PrismaTransportMode;
        }

        return this.prisma.routeHistory.findMany({
            where,
            orderBy: { startedAt: 'desc' },
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
