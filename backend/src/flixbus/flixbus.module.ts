// src/flixbus/flixbus.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { FlixbusService } from './flixbus.service';
import { FlixbusController } from './flixbus.controller';

@Module({
  imports: [HttpModule, ConfigModule],
  providers: [FlixbusService],
  controllers: [FlixbusController],
  exports: [FlixbusService],
})
export class FlixbusModule {}
