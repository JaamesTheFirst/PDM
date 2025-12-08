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

/**
 * Controller da CP.
 *
 * Expõe endpoints para:
 *  - veículos em tempo real (comboios.live)
 *  - rotas/linhas CP a partir do grafo OTP
 *  - pesquisa de estações
 *  - partidas por estação (raw GTFS e formato para UI)
 */
@Controller('cp')
export class CpController {
  constructor(private readonly cpService: CpService) {}

  // ===== COMBOIOS.LIVE – REALTIME =====

  /**
   * Lista de veículos CP em tempo real.
   *
   * GET /cp/vehicles?refresh=false
   *
   * @param refresh Se `true`, ignora cache e força pedido à API upstream.
   */
  @Get('vehicles')
  getVehicles(
    @Query('refresh', new DefaultValuePipe(false), ParseBoolPipe)
    refresh: boolean,
  ): Promise<CpVehicleDto[]> {
    return this.cpService.getVehicles(refresh);
  }

  /**
   * Detalhes de um comboio específico, via feed realtime.
   *
   * GET /cp/vehicles/:trainNumber
   *
   * @throws NotFoundException se o comboio não estiver no feed mais recente.
   */
  @Get('vehicles/:trainNumber')
  async getVehicle(@Param('trainNumber') trainNumber: string): Promise<CpVehicleDto> {
    const vehicle = await this.cpService.getVehicle(trainNumber);
    if (!vehicle) {
      throw new NotFoundException(`Train ${trainNumber} not found in latest CP feed`);
    }
    return vehicle;
  }

  // ===== OTP – LINHAS CP =====

  /**
   * Lista todas as rotas/linhas CP presentes no grafo OTP.
   *
   * GET /cp/routes/graph
   */
  @Get('routes/graph')
  getCpRoutesFromGraph(): Promise<CpGraphRouteDto[]> {
    return this.cpService.getCpRoutesFromGraph();
  }

  /**
   * Detalhe de uma rota específica CP (incluindo lista de paragens).
   *
   * GET /cp/routes/graph/:routeGtfsId
   */
  @Get('routes/graph/:routeGtfsId')
  getCpRouteDetail(@Param('routeGtfsId') routeGtfsId: string): Promise<CpGraphRouteDetailDto> {
    return this.cpService.getCpRouteDetail(routeGtfsId);
  }

  /**
   * Wrapper de conveniência para devolver um objeto `{ route }`
   * (mais confortável para o frontend).
   *
   * GET /cp/routes/graph/:routeGtfsId/stops
   */
  @Get('routes/graph/:routeGtfsId/stops')
  async getCpRouteStops(
    @Param('routeGtfsId') routeGtfsId: string,
  ): Promise<{ route: CpGraphRouteDetailDto }> {
    const detail = await this.cpService.getCpRouteDetail(routeGtfsId);
    return { route: detail };
  }

  // ===== OTP – SEARCH DE STOPS =====

  /**
   * Pesquisa de estações CP pelo nome.
   *
   * GET /cp/stops/search?q=...&limit=10
   *
   * @param q Termo de pesquisa (obrigatório; se vazio devolve array vazio)
   * @param limit Número máximo de resultados
   */
  @Get('stops/search')
  searchStops(
    @Query('q') q: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe)
    limit: number,
  ): Promise<CpStopSearchResultDto[]> {
    return this.cpService.searchStops(q, limit);
  }

  // ===== OTP – PARTIDAS BRUTAS (GTFS) =====

  /**
   * Partidas brutas (GTFS) para uma determinada paragem CP.
   *
   * GET /cp/stops/:gtfsId/departures?startTime=...&timeRange=3600&numberOfDepartures=20
   *
   * @param gtfsId ID GTFS da paragem
   * @param startTime Epoch seconds de início da janela; se omitido usa "agora"
   * @param timeRange Janela temporal em segundos (default: 3600 = 1h)
   * @param numberOfDepartures Máximo de partidas devolvidas (default: 20)
   */
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

  /**
   * Quadro de partidas formatado para UI (horas "HH:MM", atraso em minutos, etc.).
   *
   * GET /cp/stops/:gtfsId/departures/board
   *
   * Aceita os mesmos query params que `/stops/:gtfsId/departures`.
   */
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
