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

/**
 * Controller responsável pela API FlixBus.
 *
 * Expõe endpoints REST para:
 *  - listar rotas FlixBus do grafo OTP
 *  - obter detalhe de linha + paragens
 *  - pesquisar paragens por nome
 *  - obter partidas por paragem (raw GTFS e formato de "board" para UI)
 */
@Controller('flixbus')
export class FlixbusController {
  constructor(private readonly flixbusService: FlixbusService) {}

  // ===== OTP – LINHAS FLIXBUS =====

  /**
   * Lista todas as rotas FlixBus presentes no grafo OTP.
   *
   * GET /flixbus/routes/graph
   */
  @Get('routes/graph')
  getFlixbusRoutesFromGraph(): Promise<FlixbusGraphRouteDto[]> {
    return this.flixbusService.getFlixbusRoutesFromGraph();
  }

  /**
   * Detalhe de uma rota FlixBus específica (inclui lista de paragens).
   *
   * GET /flixbus/routes/graph/:routeGtfsId
   *
   * @param routeGtfsId ID GTFS da rota
   */
  @Get('routes/graph/:routeGtfsId')
  getFlixbusRouteDetail(
    @Param('routeGtfsId') routeGtfsId: string,
  ): Promise<FlixbusGraphRouteDetailDto> {
    return this.flixbusService.getFlixbusRouteDetail(routeGtfsId);
  }

  /**
   * Wrapper para devolver `{ route: detail }`, mais conveniente para o frontend.
   *
   * GET /flixbus/routes/graph/:routeGtfsId/stops
   */
  @Get('routes/graph/:routeGtfsId/stops')
  async getFlixbusRouteStops(
    @Param('routeGtfsId') routeGtfsId: string,
  ): Promise<{ route: FlixbusGraphRouteDetailDto }> {
    const detail = await this.flixbusService.getFlixbusRouteDetail(routeGtfsId);
    return { route: detail };
  }

  // ===== OTP – SEARCH DE STOPS =====

  /**
   * Pesquisa de paragens pelo nome (autocomplete).
   *
   * GET /flixbus/stops/search?q=...&limit=10
   *
   * @param q Termo de pesquisa
   * @param limit Máximo de resultados (default: 10)
   */
  @Get('stops/search')
  searchStops(
    @Query('q') q: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe)
    limit: number,
  ): Promise<FlixbusStopSearchResultDto[]> {
    return this.flixbusService.searchStops(q, limit);
  }

  // ===== OTP – PARTIDAS BRUTAS (GTFS) =====

  /**
   * Partidas brutas (GTFS) para uma determinada paragem FlixBus.
   *
   * GET /flixbus/stops/:gtfsId/departures
   *
   * @param gtfsId ID GTFS da paragem
   * @param startTime Epoch seconds opcional para início da janela; se omitido usa "agora"
   * @param timeRange Janela temporal em segundos (default: 3600)
   * @param numberOfDepartures Máximo de partidas (default: 20)
   */
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

  /**
   * Quadro de partidas formatado para UI para uma paragem FlixBus.
   *
   * GET /flixbus/stops/:gtfsId/departures/board
   *
   * Os parâmetros de query são os mesmos de `/stops/:gtfsId/departures`.
   */
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
