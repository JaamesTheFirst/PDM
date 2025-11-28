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
import { SaveRouteDto } from './dto/save-route.dto';
import { ListHistoryQueryDto } from './dto/list-history.dto';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { CurrentUser } from '../auth/decorators/current-user.decorator';
import { JwtPayload } from '../auth/types/jwt-payload.type';

@Controller('routes')
export class RoutesController {
  constructor(private readonly routesService: RoutesService) {}

  // 1) Planeamento + filtro tudo no backend
  @Post('plan')
  planTrip(@Body() dto: PlanItineraryDto): Promise<PlannedRoutesResponse> {
    return this.routesService.planAndFilter(dto);
  }

  // 2) Guardar itinerary escolhido no histórico
  @UseGuards(JwtAuthGuard)
  @Post('history')
  saveRoute(
    @CurrentUser() user: JwtPayload,
    @Body() dto: SaveRouteDto,
  ) {
    return this.routesService.saveItineraryForUser(user.sub, dto);
  }

  // 3) Listar histórico
  @UseGuards(JwtAuthGuard)
  @Get('history')
  listHistory(
    @CurrentUser() user: JwtPayload,
    @Query() query: ListHistoryQueryDto,
  ) {
    return this.routesService.listHistoryForUser(user.sub, query);
  }

  // 4) Detalhe de uma rota
  @UseGuards(JwtAuthGuard)
  @Get('history/:id')
  getHistoryItem(
    @CurrentUser() user: JwtPayload,
    @Param('id') id: string,
  ) {
    return this.routesService.getHistoryById(user.sub, id);
  }
}
