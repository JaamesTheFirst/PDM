// src/cp/cp.module.ts

import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { CpService } from './cp.service';
import { CpController } from './cp.controller';

/**
 * Módulo CP.
 *
 * Responsável por:
 *  - integrar com a API comboios.live (realtime)
 *  - integrar com o grafo OTP/GTFS via GraphQL
 *  - expor endpoints REST para veículos, rotas e horários da CP
 */
@Module({
  imports: [HttpModule, ConfigModule],
  providers: [CpService],
  controllers: [CpController],
  exports: [CpService],
})
export class CpModule {}
