import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { GbfsService } from './gbfs.service';
import { GbfsController } from './gbfs.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [HttpModule, PrismaModule],
  providers: [GbfsService],
  controllers: [GbfsController],
  exports: [GbfsService],
})
export class GbfsModule {}
