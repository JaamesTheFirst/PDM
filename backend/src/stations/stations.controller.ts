import { Controller, Get, Post, Body, Patch, Param, Delete, Query, HttpCode } from '@nestjs/common';
import { StationsService } from './stations.service';
import { CreateStationDto } from './dto/create-station.dto';
import { UpdateStationDto } from './dto/update-station.dto';

@Controller('stations')
export class StationsController {
  constructor(private readonly stationsService: StationsService) {}

  @Post()
  create(@Body() dto: CreateStationDto) {
    return this.stationsService.create(dto);
  }

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
    return this.stationsService.findAll({ limit: limitNum, offset: offsetNum, type, city, bbox });
  }

  @Get(':id')
  findOne(@Param('id') id: string) {
    return this.stationsService.findOne(id);
  }

  @Patch(':id')
  update(@Param('id') id: string, @Body() dto: UpdateStationDto) {
    return this.stationsService.update(id, dto);
  }

  @Delete(':id')
  @HttpCode(204)
  async remove(@Param('id') id: string) {
    // Service returns `null` when the record already doesn't exist. We always return 204 (idempotent).
    await this.stationsService.remove(id);
    return;
  }
}
