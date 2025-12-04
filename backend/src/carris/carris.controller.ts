// src/carris/carris.controller.ts

import {
  Controller,
  Get,
  Param,
  Query,
  DefaultValuePipe,
  ParseIntPipe,
} from '@nestjs/common';
import { CarrisService } from './carris.service';
import {
  CarrisAgencyDto,
  CarrisRouteDto,
  CarrisStopDto,
  CarrisUpcomingDepartureDto,
} from './dto';

@Controller('carris')
export class CarrisController {
  constructor(private readonly carrisService: CarrisService) {}

  // ---------- Agência ----------

  @Get('agency')
  getAgencyInfo(): Promise<CarrisAgencyDto | null> {
    return this.carrisService.getAgencyInfo();
  }

  // ---------- Routes ----------

  @Get('routes')
  getRoutes(): Promise<CarrisRouteDto[]> {
    return this.carrisService.getRoutes();
  }

  @Get('routes/:routeId')
  getRoute(@Param('routeId') routeId: string): Promise<CarrisRouteDto | null> {
    return this.carrisService.getRoute(routeId);
  }

  // ---------- Stops ----------

  // ⚠️ IMPORTANTE: SEARCH vem ANTES de :stopId
  @Get('stops/search')
  searchStops(
    @Query('q') q: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ): Promise<CarrisStopDto[]> {
    return this.carrisService.searchStops(q, limit);
  }

  @Get('stops')
  getStops(): Promise<CarrisStopDto[]> {
    return this.carrisService.getStops();
  }

  @Get('stops/:stopId')
  getStop(@Param('stopId') stopId: string): Promise<CarrisStopDto | null> {
    return this.carrisService.getStop(stopId);
  }

  @Get('routes/:routeId/stops')
  getStopsByRoute(
    @Param('routeId') routeId: string,
  ): Promise<CarrisStopDto[]> {
    return this.carrisService.getStopsByRoute(routeId);
  }

  // ---------- Partidas próximas ----------

  @Get('stops/:stopId/departures')
  getUpcomingDepartures(
    @Param('stopId') stopId: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ): Promise<CarrisUpcomingDepartureDto[]> {
    return this.carrisService.getUpcomingDeparturesByStop(stopId, limit);
  }
}
