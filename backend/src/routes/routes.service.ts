import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import {
    Prisma,
    RouteStatus,
    TransportMode as PrismaTransportMode,
} from '@prisma/client';
import { OtpService, OtpItinerary, OtpLeg } from './otp.service';
import { PlanItineraryDto, FilterMode, TransportMode } from './dto/plan-itinerary.dto';
import { PlanGranularDto } from './dto/plan-granular.dto';
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

    // ========== Planeamento granular com tipos específicos de transporte ==========

    async planGranular(dto: PlanGranularDto): Promise<PlannedRoutesResponse> {
        // Convert to PlanItineraryDto for OTP call
        const baseModes = dto.baseModes && dto.baseModes.length > 0
            ? dto.baseModes.map(m => m as TransportMode)
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

        // Get routes from OTP
        const otpPlan = await this.otp.plan(planDto);
        const original = otpPlan.itineraries || [];
        const enriched = original.map((it) => this.enrichItinerary(it));

        // Filter by granular transit types if provided
        let filtered = enriched;
        if (dto.transitTypes && dto.transitTypes.length > 0) {
            filtered = enriched.filter((it) => {
                // Check if itinerary uses any of the selected transit types
                const nonWalkModes = new Set(
                    it.legs.filter((l) => l.mode !== 'WALK').map((l) => l.mode),
                );

                // Map OTP modes to transit types
                const transitTypesInItinerary = new Set<string>();
                for (const leg of it.legs) {
                    const mode = leg.mode.toUpperCase();
                    if (mode === 'WALK' || mode === 'WALKING') continue;
                    
                    if (mode === 'BUS' || mode.includes('BUS')) {
                        transitTypesInItinerary.add('BUS');
                    } else if (mode === 'RAIL' || mode === 'TRAIN' || mode === 'R' || mode === 'IC') {
                        transitTypesInItinerary.add('RAIL');
                    } else if (mode === 'METRO' || mode === 'SUBWAY') {
                        transitTypesInItinerary.add('METRO');
                    } else if (mode === 'TRAM') {
                        transitTypesInItinerary.add('TRAM');
                    } else if (mode === 'BICYCLE' || mode === 'BIKE' || mode.includes('BIKE')) {
                        // Check if it's bike share by looking at route name or mode
                        const isBikeShare = mode.includes('SHARE') || 
                            leg.route?.longName?.toUpperCase().includes('GIRA') ||
                            leg.route?.longName?.toUpperCase().includes('BIKE SHARE') ||
                            leg.route?.shortName?.toUpperCase().includes('GIRA');
                        
                        if (isBikeShare) {
                            transitTypesInItinerary.add('BICYCLE_SHARE');
                        } else {
                            // Regular bicycle - this is handled by baseModes (BICYCLE), not transit types
                            // So we don't add it to transitTypesInItinerary
                        }
                    } else if (mode === 'SCOOTER' || mode.includes('SCOOTER')) {
                        // Check if it's scooter share
                        const isScooterShare = mode.includes('SHARE') || 
                            leg.route?.longName?.toUpperCase().includes('SCOOTER SHARE');
                        
                        if (isScooterShare) {
                            transitTypesInItinerary.add('SCOOTER_SHARE');
                        }
                    }
                }

                // If no transit types in itinerary (e.g., walking only, or only base modes like BICYCLE/CAR)
                if (transitTypesInItinerary.size === 0) {
                    // Allow if it's a base mode (WALK, BICYCLE, CAR) that was selected
                    const hasWalk = nonWalkModes.size === 0 && baseModes.includes(TransportMode.WALK);
                    const hasBicycle = nonWalkModes.has('BICYCLE') && baseModes.includes(TransportMode.BICYCLE);
                    const hasCar = nonWalkModes.has('CAR') && baseModes.includes(TransportMode.CAR);
                    return hasWalk || hasBicycle || hasCar;
                }

                // STRICT FILTERING: Route must use ONLY the selected transit types (plus walking for ingress/egress)
                // If route uses BUS+METRO but user only selected BUS, exclude it.
                // If route uses BUS+METRO and user selected BUS+METRO, include it.
                const selectedTypes = new Set(dto.transitTypes.map(t => t.toUpperCase()));
                
                // Check if ALL transit types in the route are in the user's selection
                // If the route has any transit type NOT in the selection, exclude it
                for (const type of transitTypesInItinerary) {
                    if (!selectedTypes.has(type)) {
                        // Route uses a transit type that wasn't selected - exclude it
                        return false;
                    }
                }
                
                // All transit types in the route are in the user's selection - include it
                return true;
            });
        }

        // Apply max walk distance filter if provided
        if (typeof dto.maxWalkDistanceMeters === 'number') {
            filtered = filtered.filter((it) => {
                return it.totalWalkDistanceMeters <= dto.maxWalkDistanceMeters!;
            });
        }

        return {
            originalItineraryCount: original.length,
            filteredItineraryCount: filtered.length,
            filterApplied: {
                filterMode: FilterMode.ANY, // Not using FilterMode for granular
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
