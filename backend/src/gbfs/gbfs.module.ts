import { Module } from '@nestjs/common';
import { GbfsService } from './gbfs.service';
import { GbfsController } from './gbfs.controller';

@Module({
  providers: [GbfsService],
  controllers: [GbfsController]
})
export class GbfsModule {}
