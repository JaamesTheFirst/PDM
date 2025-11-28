// src/cp/cp.controller.ts
import {
  Controller,
  Get,
  Query,
  Param,
  DefaultValuePipe,
  ParseBoolPipe,
  ParseIntPipe,
  NotFoundException,
} from '@nestjs/common';
import { CpService } from './cp.service';
import {
  CpVehicleDto,
  CpGraphRouteDto,
  CpGraphRouteDetailDto,
  CpStopSearchResultDto,
  CpStopDeparturesDto,
  CpStopBoardDto,
} from './dto';

@Controller('cp')
export class CpController {
  constructor(private readonly cpService: CpService) {}

  // ===== COMBOIOS.LIVE – REALTIME =====

  @Get('vehicles')
  getVehicles(
    @Query('refresh', new DefaultValuePipe(false), ParseBoolPipe)
    refresh: boolean,
  ): Promise<CpVehicleDto[]> {
    return this.cpService.getVehicles(refresh);
  }

  @Get('vehicles/:trainNumber')
  async getVehicle(
    @Param('trainNumber') trainNumber: string,
  ): Promise<CpVehicleDto> {
    const vehicle = await this.cpService.getVehicle(trainNumber);
    if (!vehicle) {
      throw new NotFoundException(
        `Train ${trainNumber} not found in latest CP feed`,
      );
    }
    return vehicle;
  }

  // ===== OTP – LINHAS CP =====

  @Get('routes/graph')
  getCpRoutesFromGraph(): Promise<CpGraphRouteDto[]> {
    return this.cpService.getCpRoutesFromGraph();
  }

  @Get('routes/graph/:routeGtfsId')
  getCpRouteDetail(
    @Param('routeGtfsId') routeGtfsId: string,
  ): Promise<CpGraphRouteDetailDto> {
    return this.cpService.getCpRouteDetail(routeGtfsId);
  }

  @Get('routes/graph/:routeGtfsId/stops')
  async getCpRouteStops(
    @Param('routeGtfsId') routeGtfsId: string,
  ): Promise<{ route: CpGraphRouteDetailDto }> {
    const detail = await this.cpService.getCpRouteDetail(routeGtfsId);
    return { route: detail };
  }

  // ===== OTP – SEARCH DE STOPS =====

  @Get('stops/search')
  searchStops(
    @Query('q') q: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe)
    limit: number,
  ): Promise<CpStopSearchResultDto[]> {
    return this.cpService.searchStops(q, limit);
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
  ): Promise<CpStopDeparturesDto> {
    const startTimeSec = startTime ? Number(startTime) : undefined;

    return this.cpService.getStopDeparturesFromGraph(gtfsId, {
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
  ): Promise<CpStopBoardDto> {
    const startTimeSec = startTime ? Number(startTime) : undefined;

    return this.cpService.getStopBoard(gtfsId, {
      startTime: startTimeSec,
      timeRange,
      numberOfDepartures,
    });
  }
}
