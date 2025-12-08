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

/**
 * Controller responsável pela API de dados da Carris.
 *
 * Todos os endpoints expõem um subset do grafo OTP/GTFS,
 * mas já filtrado para a agência Carris e normalizado para o frontend.
 */
@Controller('carris')
export class CarrisController {
  constructor(private readonly carrisService: CarrisService) {}

  // ---------- Agência ----------

  /**
   * Obtém informação da agência Carris.
   *
   * GET /carris/agency
   *
   * @returns Dados da agência ou `null` se não encontrada no grafo.
   */
  @Get('agency')
  getAgencyInfo(): Promise<CarrisAgencyDto | null> {
    return this.carrisService.getAgencyInfo();
  }

  // ---------- Routes ----------

  /**
   * Lista todas as rotas/linhas Carris (modo BUS) disponíveis no grafo OTP.
   *
   * GET /carris/routes
   */
  @Get('routes')
  getRoutes(): Promise<CarrisRouteDto[]> {
    return this.carrisService.getRoutes();
  }

  /**
   * Obtém detalhes de uma rota específica da Carris.
   *
   * GET /carris/routes/:routeId
   *
   * @param routeId ID da rota no grafo OTP
   */
  @Get('routes/:routeId')
  getRoute(@Param('routeId') routeId: string): Promise<CarrisRouteDto | null> {
    return this.carrisService.getRoute(routeId);
  }

  // ---------- Stops ----------

  /**
   * Pesquisa de paragens por nome, útil para autocomplete.
   *
   * ⚠️ IMPORTANTE: a rota `/stops/search` é definida ANTES de `/stops/:stopId`
   * para evitar conflitos de routing.
   *
   * GET /carris/stops/search?q=...&limit=10
   *
   * @param q Termo de pesquisa (nome parcial da paragem)
   * @param limit Número máximo de resultados (default: 10)
   */
  @Get('stops/search')
  searchStops(
    @Query('q') q: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ): Promise<CarrisStopDto[]> {
    return this.carrisService.searchStops(q, limit);
  }

  /**
   * Lista todas as paragens disponíveis no grafo OTP.
   * 
   * Nota: nem todas podem ser necessariamente da Carris,
   * depende de como o grafo foi construído.
   *
   * GET /carris/stops
   */
  @Get('stops')
  getStops(): Promise<CarrisStopDto[]> {
    return this.carrisService.getStops();
  }

  /**
   * Obtém detalhes de uma paragem específica.
   *
   * GET /carris/stops/:stopId
   *
   * @param stopId ID da paragem no grafo OTP
   */
  @Get('stops/:stopId')
  getStop(@Param('stopId') stopId: string): Promise<CarrisStopDto | null> {
    return this.carrisService.getStop(stopId);
  }

  /**
   * Lista paragens associadas a uma rota Carris específica.
   *
   * GET /carris/routes/:routeId/stops
   *
   * @param routeId ID da rota
   */
  @Get('routes/:routeId/stops')
  getStopsByRoute(
    @Param('routeId') routeId: string,
  ): Promise<CarrisStopDto[]> {
    return this.carrisService.getStopsByRoute(routeId);
  }

  // ---------- Partidas próximas ----------

  /**
   * Obtém partidas próximas (próximos autocarros) para uma paragem.
   *
   * GET /carris/stops/:stopId/departures?limit=10
   *
   * @param stopId ID da paragem
   * @param limit Máximo de partidas a devolver (default: 10)
   */
  @Get('stops/:stopId/departures')
  getUpcomingDepartures(
    @Param('stopId') stopId: string,
    @Query('limit', new DefaultValuePipe(10), ParseIntPipe) limit: number,
  ): Promise<CarrisUpcomingDepartureDto[]> {
    return this.carrisService.getUpcomingDeparturesByStop(stopId, limit);
  }
}
