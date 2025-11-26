import {
  Body,
  Controller,
  DefaultValuePipe,
  Get,
  ParseIntPipe,
  Post,
  Query,
} from '@nestjs/common';
import { GiraService } from './gira.service';

@Controller('gira')
export class GiraController {
  constructor(private readonly giraService: GiraService) {}

  @Get('stations')
  async getStations(
    @Query('limit', new DefaultValuePipe(100), ParseIntPipe) limit: number,
    @Query('offset', new DefaultValuePipe(0), ParseIntPipe) offset: number,
  ) {
    const { total, slice } = await this.giraService.getStationsSlice(
      limit,
      offset,
    );

    return {
      total,
      limit,
      offset,
      records: slice,
    };
  }

  @Get('stations/search')
  async searchStations(
    @Query('field') field: string,
    @Query('value') value: string,
  ) {
    const records = await this.giraService.searchStations(field, value);
    return {
      count: records.length,
      records,
    };
  }

  @Post('stations/reload')
  async reloadStations(@Body('filePath') filePath?: string) {
    await this.giraService.loadStationsFromFile(filePath);
    return { message: 'GIRA station data reloaded successfully' };
  }
}
