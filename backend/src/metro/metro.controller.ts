import { Controller, Get, Param, Query } from '@nestjs/common';
import { MetroService } from './metro.service';

@Controller('metro')
export class MetroController {
  constructor(private readonly metroService: MetroService) {}

  @Get('waiting-times/stations')
  getAllStationWaitingTimes() {
    return this.metroService.getAllStationWaitingTimes();
  }

  @Get('waiting-times/stations/:stationId')
  getStationWaitingTimes(@Param('stationId') stationId: string) {
    return this.metroService.getStationWaitingTimes(stationId);
  }

  @Get('waiting-times/lines/:lineId')
  getLineWaitingTimes(@Param('lineId') lineId: string) {
    return this.metroService.getLineWaitingTimes(lineId);
  }

  @Get('stations')
  getAllStationsInfo() {
    return this.metroService.getAllStationsInfo();
  }

  @Get('stations/:stationId')
  getStationInfo(@Param('stationId') stationId: string) {
    return this.metroService.getStationInfo(stationId);
  }

  @Get('lines/status')
  getAllLineStatus() {
    return this.metroService.getAllLineStatus();
  }

  @Get('lines/:lineId/status')
  getLineStatus(@Param('lineId') lineId: string) {
    return this.metroService.getLineStatus(lineId);
  }

  @Get('destinations')
  getDestinations() {
    return this.metroService.getDestinations();
  }

  @Get('intervals/:lineId/:direction')
  getIntervalsByLine(
    @Param('lineId') lineId: string,
    @Param('direction') direction: string,
    @Query('serviceCode') serviceCode?: string,
  ) {
    return this.metroService.getIntervalsByLine(lineId, direction, serviceCode);
  }
}

