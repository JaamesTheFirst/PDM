import { Controller, Get, Param, Query } from '@nestjs/common';
import { GbfsService } from './gbfs.service';
import { GbfsSystemDto } from './dto/gbfs-system.dto';
import { GetGbfsFeedQueryDto } from './dto/get-gbfs-feed.dto';
import { GbfsFeedMeta } from './dto/gbfs-index.dto';

@Controller('gbfs')
export class GbfsController {
  constructor(private readonly gbfsService: GbfsService) {}

  //
  // =============== SISTEMAS (BD) ===============
  //

  // GET /gbfs/systems
  @Get('systems')
  async listSystems(): Promise<GbfsSystemDto[]> {
    return this.gbfsService.findAllSystems();
  }

  // GET /gbfs/systems/:systemId
  @Get('systems/:systemId')
  async getSystem(@Param('systemId') systemId: string): Promise<GbfsSystemDto> {
    return this.gbfsService.findSystemBySystemId(systemId);
  }

  //
  // =============== INDEX + FEEDS GENÉRICOS ===============
  //

  // GET /gbfs/:systemId/index  -> devolve o gbfs.json (auto-discovery)
  @Get(':systemId/index')
  async getIndex(@Param('systemId') systemId: string) {
    return this.gbfsService.getGbfsIndex(systemId);
  }

  // GET /gbfs/:systemId/feeds -> lista feeds disponíveis
  @Get(':systemId/feeds')
  async listFeeds(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ): Promise<GbfsFeedMeta[]> {
    return this.gbfsService.listFeeds(systemId, lang);
  }

  // GET /gbfs/:systemId/feed?name=station_information&lang=pt (debug / genérico)
  @Get(':systemId/feed')
  async getFeed(
    @Param('systemId') systemId: string,
    @Query() query: GetGbfsFeedQueryDto,
  ) {
    return this.gbfsService.getFeed(systemId, query.name, query.lang);
  }

  //
  // =============== ENDPOINTS ESPECÍFICOS POR FEED ===============
  //

  // system_information
  // GET /gbfs/:systemId/system
  @Get(':systemId/system')
  async getSystemInfo(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getSystemInformation(systemId, lang);
  }

  // station_information
  // GET /gbfs/:systemId/stations/info
  @Get(':systemId/stations/info')
  async getStationInfo(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationInformation(systemId, lang);
  }

  // station_status
  // GET /gbfs/:systemId/stations/status
  @Get(':systemId/stations/status')
  async getStationStatus(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationStatus(systemId, lang);
  }

  // ESTAÇÕES + STATUS JUNTO (para o frontend)
  // GET /gbfs/:systemId/stations
  @Get(':systemId/stations')
  async getStations(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getStationsWithStatus(systemId, lang);
  }

  // free_bike_status
  // GET /gbfs/:systemId/free-bikes
  @Get(':systemId/free-bikes')
  async getFreeBikes(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getFreeBikeStatus(systemId, lang);
  }

  // vehicle_types
  // GET /gbfs/:systemId/vehicle-types
  @Get(':systemId/vehicle-types')
  async getVehicleTypes(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getVehicleTypes(systemId, lang);
  }

  // system_pricing_plans
  // GET /gbfs/:systemId/pricing-plans
  @Get(':systemId/pricing-plans')
  async getPricingPlans(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getPricingPlans(systemId, lang);
  }

  // system_regions
  // GET /gbfs/:systemId/regions
  @Get(':systemId/regions')
  async getRegions(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getRegions(systemId, lang);
  }

  // geofencing_zones
  // GET /gbfs/:systemId/geofencing-zones
  @Get(':systemId/geofencing-zones')
  async getGeofencingZones(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getGeofencingZones(systemId, lang);
  }

  // gbfs_versions
  // GET /gbfs/:systemId/versions
  @Get(':systemId/versions')
  async getGbfsVersions(
    @Param('systemId') systemId: string,
    @Query('lang') lang?: string,
  ) {
    return this.gbfsService.getGbfsVersions(systemId, lang);
  }
}
