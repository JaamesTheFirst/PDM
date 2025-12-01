// src/flixbus/flixbus.controller.ts
import {
  Controller,
  Get,
  Query,
  Param,
  DefaultValuePipe,
  ParseIntPipe,
} from '@nestjs/common';
import { FlixbusService } from './flixbus.service';
import {
  FlixbusGraphRouteDto,
  FlixbusGraphRouteDetailDto,
  FlixbusStopSearchResultDto,
  FlixbusStopDeparturesDto,
  FlixbusStopBoardDto,
} from './dto';

@Controller('flixbus')
export class FlixbusController {
  constructor(private readonly flixbusService: FlixbusService) {}

  // ===== OTP – LINHAS FLIXBUS =====

  @Get('routes/graph')
  getFlixbusRoutesFromGraph(): Promise<FlixbusGraphRouteDto[]> {
    return this.flixbusService.getFlixbusRoutesFromGraph();
  }

  @Get('routes/graph/:routeGtfsId')
  getFlixbusRouteDetail(
    @Param('routeGtfsId') routeGtfsId: string,
  ): Promise<FlixbusGraphRouteDetailDto> {
    return this.flixbusService.getFlixbusRouteDetail(routeGtfsId);
  }

  @Get('routes/graph/:routeGtfsId/stops')
  async getFlixbusRouteStops(
    @Param('routeGtfsId') routeGtfsId: string,
  ): Promise<{ route: FlixbusGraphRouteDetailDto }> {
    const detail = await this.flixbusService.getFlixbusRouteDetail(routeGtfsId);
    return { route: detail };
  }

  // ===== OTP – SEARCH DE STOPS =====

  @Get('stops/search')
  searchStops(
    @Query('q') q: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe)
    limit: number,
  ): Promise<FlixbusStopSearchResultDto[]> {
    return this.flixbusService.searchStops(q, limit);
  }

  // ===== OTP – PARTIDAS BRUTAS (GTFS) =====

  @Get('stops/:gtfsId/departures')
  getStopDepartures(
    @Param('gtfsId') gtfsId: string,
    @Query('startTime') startTime?: string,
    @Query('timeRange', new DefaultValuePipe(3600), ParseIntPipe)
    timeRange?: number,
    @Query('numberOfDepartures', new DefaultValuePipe(20), ParseIntPipe)
    numberOfDepartures?: number,
  ): Promise<FlixbusStopDeparturesDto> {
    const startTimeSec = startTime ? Number(startTime) : undefined;

    return this.flixbusService.getStopDeparturesFromGraph(gtfsId, {
      startTime: startTimeSec,
      timeRange,
      numberOfDepartures,
    });
  }

  // ===== OTP – BOARD PARA UI (HORÁRIOS FORMATADOS) =====

  @Get('stops/:gtfsId/departures/board')
  getStopBoard(
    @Param('gtfsId') gtfsId: string,
    @Query('startTime') startTime?: string,
    @Query('timeRange', new DefaultValuePipe(3600), ParseIntPipe)
    timeRange?: number,
    @Query('numberOfDepartures', new DefaultValuePipe(20), ParseIntPipe)
    numberOfDepartures?: number,
  ): Promise<FlixbusStopBoardDto> {
    const startTimeSec = startTime ? Number(startTime) : undefined;

    return this.flixbusService.getStopBoard(gtfsId, {
      startTime: startTimeSec,
      timeRange,
      numberOfDepartures,
    });
  }
}
