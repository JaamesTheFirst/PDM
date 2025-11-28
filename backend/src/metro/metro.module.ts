// src/metro/metro.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import * as https from 'https';
import { ConfigModule } from '@nestjs/config';

import { MetroService } from './metro.service';
import { MetroTokenService } from './metro-token.service';
import { MetroPortoService } from './metro-porto.service';
import { MetroController } from './metro.controller';

@Module({
  imports: [
    ConfigModule,
    HttpModule.register({
      baseURL: 'https://api.metrolisboa.pt:8243/estadoServicoML/1.0.1',
      timeout: 5000,
      httpsAgent: new https.Agent({
        rejectUnauthorized: false,
      }),
    }),
  ],
  controllers: [MetroController],
  providers: [MetroService, MetroTokenService, MetroPortoService],
  exports: [MetroService, MetroPortoService],
})
export class MetroModule {}
