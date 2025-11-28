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

@Controller('gbfs')
export class GbfsController {
  constructor(private readonly gbfsService: GbfsService) {}

  // =========================
  //  SISTEMAS (BD)
  // =========================

  // GET /gbfs/systems
  @Get('systems')
  async listSystems(): Promise<GbfsSystemDto[]> {
    return this.gbfsService.findAllSystems();
  }

  // GET /gbfs/systems/:systemId
  @Get('systems/:systemId')
  async getSystem(
    @Param('systemId') systemId: string,
  ): Promise<GbfsSystemDto> {
    return this.gbfsService.findSystemBySystemId(systemId);
  }

  // =========================
  //  INDEX + FEEDS
  // =========================

  // GET /gbfs/:systemId/index
  @Get(':systemId/index')
  async getIndex(@Param('systemId') systemId: string) {
    return this.gbfsService.getGbfsIndex(systemId);
  }

  // GET /gbfs/:systemId/feeds?lang=pt
  @Get(':systemId/feeds')
  async listFeeds(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ): Promise<GbfsFeedMeta[]> {
    return this.gbfsService.listFeeds(systemId, lang);
  }

  // GET /gbfs/:systemId/feed?name=station_information&lang=pt
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
  // GET /gbfs/:systemId/system?lang=pt
  @Get(':systemId/system')
  async getSystemInfo(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getSystemInformation(systemId, lang);
  }

  // STATION INFORMATION
  // GET /gbfs/:systemId/stations/info?lang=pt
  @Get(':systemId/stations/info')
  async getStationInfo(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationInformation(systemId, lang);
  }

  // STATION STATUS
  // GET /gbfs/:systemId/stations/status?lang=pt
  @Get(':systemId/stations/status')
  async getStationStatus(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationStatus(systemId, lang);
  }

  // ESTAÇÕES + STATUS (apenas em memória)
  // GET /gbfs/:systemId/stations?lang=pt
  @Get(':systemId/stations')
  async getStations(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationsWithStatus(systemId, lang);
  }

  // FREE BIKE STATUS
  // GET /gbfs/:systemId/free-bikes?lang=pt
  @Get(':systemId/free-bikes')
  async getFreeBikes(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getFreeBikeStatus(systemId, lang);
  }

  // VEHICLE TYPES
  // GET /gbfs/:systemId/vehicle-types?lang=pt
  @Get(':systemId/vehicle-types')
  async getVehicleTypes(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getVehicleTypes(systemId, lang);
  }

  // PRICING PLANS
  // GET /gbfs/:systemId/pricing-plans?lang=pt
  @Get(':systemId/pricing-plans')
  async getPricingPlans(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getPricingPlans(systemId, lang);
  }

  // REGIONS
  // GET /gbfs/:systemId/regions?lang=pt
  @Get(':systemId/regions')
  async getRegions(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getRegions(systemId, lang);
  }

  // GEOFENCING ZONES
  // GET /gbfs/:systemId/geofencing-zones?lang=pt
  @Get(':systemId/geofencing-zones')
  async getGeofencingZones(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getGeofencingZones(systemId, lang);
  }

  // GBFS VERSIONS
  // GET /gbfs/:systemId/versions?lang=pt
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

  // POST /gbfs/:systemId/sync-stations?lang=pt
  @Post(':systemId/sync-stations')
  async syncStationsFromGbfs(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.syncStationsFromGbfs(systemId, lang);
  }
}
