// src/flixbus/flixbus.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { FlixbusService } from './flixbus.service';
import { FlixbusController } from './flixbus.controller';

/**
 * Módulo FlixBus.
 *
 * Responsável por:
 *  - integrar com o grafo OTP via GraphQL
 *  - expor endpoints REST no `FlixbusController`
 *  - disponibilizar `FlixbusService` para outros módulos se necessário
 */
@Module({
  imports: [HttpModule, ConfigModule],
  providers: [FlixbusService],
  controllers: [FlixbusController],
  exports: [FlixbusService],
})
export class FlixbusModule {}
