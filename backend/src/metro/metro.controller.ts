// src/metro/metro.controller.ts
//
// Controller único para expor endpoints do Metro de Lisboa (API oficial)
// e do Metro do Porto (via OTP). Os paths são namespaced para cada cidade.

import {
  Controller,
  Get,
  Param,
  Query,
  DefaultValuePipe,
  ParseIntPipe,
} from '@nestjs/common';
import { MetroService } from './metro.service';
import { MetroPortoService } from './metro-porto.service';

@Controller('metro')
export class MetroController {
  constructor(
    private readonly metroLisboa: MetroService,
    private readonly metroPorto: MetroPortoService,
  ) {}

  // ===== METRO LISBOA =====

  @Get('waiting-times/stations')
  getAllStationWaitingTimes() {
    return this.metroLisboa.getAllStationWaitingTimes();
  }

  @Get('waiting-times/stations/:stationId')
  getStationWaitingTimes(@Param('stationId') stationId: string) {
    return this.metroLisboa.getStationWaitingTimes(stationId);
  }

  @Get('waiting-times/lines/:lineId')
  getLineWaitingTimes(@Param('lineId') lineId: string) {
    return this.metroLisboa.getLineWaitingTimes(lineId);
  }

  @Get('stations')
  getAllStationsInfo() {
    return this.metroLisboa.getAllStationsInfo();
  }

  @Get('stations/:stationId')
  getStationInfo(@Param('stationId') stationId: string) {
    return this.metroLisboa.getStationInfo(stationId);
  }

  @Get('lines/status')
  getAllLineStatus() {
    return this.metroLisboa.getAllLineStatus();
  }

  @Get('lines/:lineId/status')
  getLineStatus(@Param('lineId') lineId: string) {
    return this.metroLisboa.getLineStatus(lineId);
  }

  @Get('destinations')
  getDestinations() {
    return this.metroLisboa.getDestinations();
  }

  @Get('intervals/:lineId/:direction')
  getIntervalsByLine(
    @Param('lineId') lineId: string,
    @Param('direction') direction: string,
    @Query('serviceCode') serviceCode?: string,
  ) {
    return this.metroLisboa.getIntervalsByLine(lineId, direction, serviceCode);
  }

  // ===== METRO DO PORTO (OTP) =====

  @Get('porto/agency')
  getPortoAgency() {
    return this.metroPorto.getAgencyInfo();
  }

  @Get('porto/routes')
  getPortoRoutes() {
    return this.metroPorto.getRoutes();
  }

  @Get('porto/routes/:routeId')
  getPortoRoute(@Param('routeId') routeId: string) {
    return this.metroPorto.getRoute(routeId);
  }

  // IMPORTANTE: a rota de search tem de vir antes da rota com :stopId
  @Get('porto/stops/search')
  searchPortoStops(
    @Query('q') q: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ) {
    return this.metroPorto.searchStops(q, limit);
  }

  @Get('porto/stops')
  getPortoStops() {
    return this.metroPorto.getStops();
  }

  @Get('porto/stops/:stopId')
  getPortoStop(@Param('stopId') stopId: string) {
    return this.metroPorto.getStop(stopId);
  }

  @Get('porto/routes/:routeId/stops')
  getPortoStopsByRoute(@Param('routeId') routeId: string) {
    return this.metroPorto.getStopsByRoute(routeId);
  }

  @Get('porto/stops/:stopId/departures')
  getPortoDepartures(
    @Param('stopId') stopId: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ) {
    return this.metroPorto.getUpcomingDeparturesByStop(stopId, limit);
  }
}
