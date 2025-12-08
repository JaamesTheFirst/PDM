// backend/src/gbfs/gbfs.controller.ts
import {
  Controller,
  Get,
  Param,
  Query,
  Post,
} from '@nestjs/common';
import { GbfsService } from './gbfs.service';
import { GbfsSystemDto } from './dto/gbfs-system.dto';
import { GbfsFeedMeta } from './dto/gbfs-index.dto';
import { GetGbfsFeedQueryDto } from './dto/get-gbfs-feed.dto';

/**
 * Controller responsável por expor a API GBFS do backend.
 *
 * Este controller não implementa o protocolo GBFS público,
 * mas fornece endpoints de conveniência em cima dos feeds reais:
 *  - gestão e lookup de sistemas registados na BD
 *  - proxy para `gbfs.json` e feeds individuais
 *  - agregados como `stations` + `availability`
 *  - sync de estações para a tabela `stations` (Prisma)
 */
@Controller('gbfs')
export class GbfsController {
  constructor(private readonly gbfsService: GbfsService) {}

  // =========================
  //  SISTEMAS (BD)
  // =========================

  /**
   * Lista todos os sistemas GBFS registados na base de dados.
   *
   * GET /gbfs/systems
   */
  @Get('systems')
  async listSystems(): Promise<GbfsSystemDto[]> {
    return this.gbfsService.findAllSystems();
  }

  /**
   * Obtém um sistema GBFS específico pelo `systemId` (campo lógico).
   *
   * GET /gbfs/systems/:systemId
   */
  @Get('systems/:systemId')
  async getSystem(
    @Param('systemId') systemId: string,
  ): Promise<GbfsSystemDto> {
    return this.gbfsService.findSystemBySystemId(systemId);
  }

  // =========================
  //  INDEX + FEEDS
  // =========================

  /**
   * Devolve o índice GBFS (`gbfs.json`) de um sistema.
   *
   * GET /gbfs/:systemId/index
   */
  @Get(':systemId/index')
  async getIndex(@Param('systemId') systemId: string) {
    return this.gbfsService.getGbfsIndex(systemId);
  }

  /**
   * Lista os feeds disponíveis para um idioma específico.
   *
   * GET /gbfs/:systemId/feeds?lang=pt
   */
  @Get(':systemId/feeds')
  async listFeeds(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ): Promise<GbfsFeedMeta[]> {
    return this.gbfsService.listFeeds(systemId, lang);
  }

  /**
   * Proxy para um feed GBFS arbitrário por nome.
   *
   * GET /gbfs/:systemId/feed?name=station_information&lang=pt
   */
  @Get(':systemId/feed')
  async getFeed(
    @Param('systemId') systemId: string,
    @Query() query: GetGbfsFeedQueryDto,
  ) {
    return this.gbfsService.getFeed(systemId, query.name, query.lang);
  }

  // =========================
  //  FEEDS ESPECÍFICOS
  // =========================

  // SYSTEM INFORMATION

  /**
   * Wrapper para o feed `system_information`.
   *
   * GET /gbfs/:systemId/system?lang=pt
   */
  @Get(':systemId/system')
  async getSystemInfo(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getSystemInformation(systemId, lang);
  }

  // STATION INFORMATION

  /**
   * Wrapper para o feed `station_information`.
   *
   * GET /gbfs/:systemId/stations/info?lang=pt
   */
  @Get(':systemId/stations/info')
  async getStationInfo(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationInformation(systemId, lang);
  }

  // STATION STATUS

  /**
   * Wrapper para o feed `station_status`.
   *
   * GET /gbfs/:systemId/stations/status?lang=pt
   */
  @Get(':systemId/stations/status')
  async getStationStatus(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationStatus(systemId, lang);
  }

  // ESTAÇÕES + STATUS (apenas em memória)

  /**
   * Devolve `station_information` + `station_status` já mergeados,
   * sem gravar nada em BD (merge em memória).
   *
   * GET /gbfs/:systemId/stations?lang=pt
   */
  @Get(':systemId/stations')
  async getStations(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationsWithStatus(systemId, lang);
  }

  // AVAILABILITY (stations + free bikes)

  /**
   * Devolve um agregado com:
   *  - stations (info + status)
   *  - free bikes (bikes/vehicles soltos)
   *
   * GET /gbfs/:systemId/availability?lang=pt
   */
  @Get(':systemId/availability')
  async getAvailability(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getAvailability(systemId, lang);
  }

  // FREE BIKE STATUS

  /**
   * Wrapper para o feed `free_bike_status`.
   *
   * GET /gbfs/:systemId/free-bikes?lang=pt
   */
  @Get(':systemId/free-bikes')
  async getFreeBikes(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getFreeBikeStatus(systemId, lang);
  }

  // VEHICLE TYPES

  /**
   * Wrapper para o feed `vehicle_types`.
   *
   * GET /gbfs/:systemId/vehicle-types?lang=pt
   */
  @Get(':systemId/vehicle-types')
  async getVehicleTypes(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getVehicleTypes(systemId, lang);
  }

  // PRICING PLANS

  /**
   * Wrapper para o feed `system_pricing_plans`.
   *
   * GET /gbfs/:systemId/pricing-plans?lang=pt
   */
  @Get(':systemId/pricing-plans')
  async getPricingPlans(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getPricingPlans(systemId, lang);
  }

  // REGIONS

  /**
   * Wrapper para o feed `system_regions`.
   *
   * GET /gbfs/:systemId/regions?lang=pt
   */
  @Get(':systemId/regions')
  async getRegions(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getRegions(systemId, lang);
  }

  // GEOFENCING ZONES

  /**
   * Wrapper para o feed `geofencing_zones`.
   *
   * GET /gbfs/:systemId/geofencing-zones?lang=pt
   */
  @Get(':systemId/geofencing-zones')
  async getGeofencingZones(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getGeofencingZones(systemId, lang);
  }

  // GBFS VERSIONS

  /**
   * Wrapper para o feed `gbfs_versions`.
   *
   * GET /gbfs/:systemId/versions?lang=pt
   */
  @Get(':systemId/versions')
  async getGbfsVersions(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getGbfsVersions(systemId, lang);
  }

  // =========================
  //  SYNC ESTAÇÕES -> BD
  // =========================

  /**
   * Sincroniza as estações de um sistema GBFS para a tabela `stations`
   * via upsert, usando `gbfsSystemId + externalId` como chave.
   *
   * GET: usa `station_information` (+ `station_status` para métricas).
   *
   * POST /gbfs/:systemId/sync-stations?lang=pt
   */
  @Post(':systemId/sync-stations')
  async syncStationsFromGbfs(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.syncStationsFromGbfs(systemId, lang);
  }
}
