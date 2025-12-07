// src/impact/impact.module.ts
import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { ImpactService } from './impact.service';
import { ImpactController } from './impact.controller';

/**
 * Módulo de impacto ecológico.
 *
 * Liga o Prisma (RouteHistory + EcoStatsAggregate) ao ImpactService
 * e expõe o ImpactController com os endpoints de resumo/timeline.
 */
@Module({
  imports: [PrismaModule],
  providers: [ImpactService],
  controllers: [ImpactController],
  exports: [ImpactService],
})
export class ImpactModule {}
