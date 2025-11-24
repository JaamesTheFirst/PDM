import {
  Controller,
  Get,
  Query,
  Param,
  DefaultValuePipe,
  ParseBoolPipe,
  NotFoundException,
} from '@nestjs/common';
import { CpService } from './cp.service';

@Controller('cp')
export class CpController {
  constructor(private readonly cpService: CpService) {}

  @Get('vehicles')
  getVehicles(
    @Query('refresh', new DefaultValuePipe(false), ParseBoolPipe)
    refresh: boolean,
  ): Promise<any> {
    return this.cpService.getVehicles(refresh);
  }

  @Get('vehicles/:trainNumber')
  async getVehicle(@Param('trainNumber') trainNumber: string) {
    const vehicle = await this.cpService.getVehicle(trainNumber);
    if (!vehicle) {
      throw new NotFoundException(
        `Train ${trainNumber} not found in latest CP feed`,
      );
    }
    return vehicle;
  }
}

