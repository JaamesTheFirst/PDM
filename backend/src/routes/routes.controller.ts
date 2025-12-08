import {
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UseGuards,
} from '@nestjs/common';
import { RoutesService, PlannedRoutesResponse } from './routes.service';
import { PlanItineraryDto } from './dto/plan-itinerary.dto';
import { PlanGranularDto } from './dto/plan-granular.dto';
import { SaveRouteDto } from './dto/save-route.dto';
import { ListHistoryQueryDto } from './dto/list-history.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload } from '../auth/types/jwt-payload.type';

@Controller('routes')
export class RoutesController {
  constructor(private readonly routesService: RoutesService) {}

  /**
   * 1) Planeamento de itinerário "simples":
   *    chama OTP e aplica filtros (filterMode, maxWalkDistanceMeters) no backend.
   */
  @Post('plan')
  planTrip(@Body() dto: PlanItineraryDto): Promise<PlannedRoutesResponse> {
    return this.routesService.planAndFilter(dto);
  }

  /**
   * 2) Planeamento granular:
   *    permite selecionar tipos de transporte específicos (BUS, RAIL, etc.).
   */
  @Post('plan-granular')
  planGranular(@Body() dto: PlanGranularDto): Promise<PlannedRoutesResponse> {
    return this.routesService.planGranular(dto);
  }

  /**
   * 3) Guardar o itinerary escolhido no histórico do utilizador autenticado.
   */
  @UseGuards(JwtAuthGuard)
  @Post('history')
  saveRoute(
    @CurrentUser() user: JwtPayload,
    @Body() dto: SaveRouteDto,
  ) {
    return this.routesService.saveItineraryForUser(user.sub, dto);
  }

  /**
   * 4) Listar histórico de rotas do utilizador autenticado.
   */
  @UseGuards(JwtAuthGuard)
  @Get('history')
  listHistory(
    @CurrentUser() user: JwtPayload,
    @Query() query: ListHistoryQueryDto,
  ) {
    return this.routesService.listHistoryForUser(user.sub, query);
  }

  /**
   * 5) Obter detalhe de uma rota específica do histórico do utilizador.
   */
  @UseGuards(JwtAuthGuard)
  @Get('history/:id')
  getHistoryItem(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.routesService.getHistoryById(user.sub, id);
  }
}
