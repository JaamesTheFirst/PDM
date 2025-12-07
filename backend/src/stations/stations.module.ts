import { Module } from '@nestjs/common';
import { StationsService } from './stations.service';
import { StationsController } from './stations.controller';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Módulo que expõe o CRUD de Station:
 * - StationsService → lógica de negócio / acesso a Prisma
 * - StationsController → endpoints HTTP
 */
@Module({
  providers: [StationsService, PrismaService],
  controllers: [StationsController],
  exports: [StationsService],
})
export class StationsModule {}
