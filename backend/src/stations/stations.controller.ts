import { Controller, Get, Post, Body, Patch, Param, Delete, Query, HttpCode } from '@nestjs/common';
import { StationsService } from './stations.service';
import { CreateStationDto } from './dto/create-station.dto';
import { UpdateStationDto } from './dto/update-station.dto';

/**
 * REST controller para gestão de estações (station).
 *
 * Endpoints base:
 * - POST   /stations            → criar
 * - GET    /stations            → listar com filtros
 * - GET    /stations/:id        → detalhe
 * - PATCH  /stations/:id        → atualizar
 * - DELETE /stations/:id        → remover (idempotente)
 */
@Controller('stations')
export class StationsController {
  constructor(private readonly stationsService: StationsService) {}

  /**
   * Cria uma nova Station.
   * body: CreateStationDto
   */
  @Post()
  create(@Body() dto: CreateStationDto) {
    return this.stationsService.create(dto);
  }

  /**
   * Lista estações com filtros opcionais:
   *
   * - limit: nº máximo de resultados (default definido no service)
   * - offset: offset para paginação
   * - type: tipo de estação (alias ou enum; normalizado no service)
   * - city: filtro textual por cidade
   * - bbox: bounding box "minLng,minLat,maxLng,maxLat"
   */
  @Get()
  findAll(
    @Query('limit') limit: string,
    @Query('offset') offset: string,
    @Query('type') type: string,
    @Query('city') city: string,
    @Query('bbox') bbox: string,
  ) {
    const limitNum = limit ? Number(limit) : undefined;
    const offsetNum = offset ? Number(offset) : undefined;
    return this.stationsService.findAll({
      limit: limitNum,
      offset: offsetNum,
      type,
      city,
      bbox,
    });
  }

  /**
   * Devolve uma Station específica por ID.
   */
  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.stationsService.findOne(id);
  }

  /**
   * Atualiza parcialmente uma Station (PATCH).
   */
  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateStationDto) {
    return this.stationsService.update(id, dto);
  }

  /**
   * Remove uma Station.
   *
   * - Se existir → apaga e devolve 204
   * - Se já não existir → devolve 204 na mesma (idempotente)
   */
  @Delete(':id')
  @HttpCode(204)
  async remove(@Param('id') id: string) {
    // Service devolve `null` se o registo já não existir; aqui devolvemos sempre 204.
    await this.stationsService.remove(id);
    return;
  }
}
