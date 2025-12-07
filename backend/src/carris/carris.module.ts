// src/carris/carris.module.ts

import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';

import { CarrisService } from './carris.service';
import { CarrisController } from './carris.controller';

/**
 * Módulo Carris.
 *
 * Encapsula:
 *  - integração com o OTP GraphQL (via HttpModule)
 *  - leitura de config (`OTP_BASE_URL`) via ConfigModule
 *  - exposição da API HTTP no `CarrisController`
 */
@Module({
  imports: [HttpModule, ConfigModule],
  providers: [CarrisService],
  controllers: [CarrisController],
  exports: [CarrisService],
})
export class CarrisModule {}
