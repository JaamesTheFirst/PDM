import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import * as https from 'https';
import { MetroService } from './metro.service';
import { MetroController } from './metro.controller';
import { MetroTokenService } from './metro-token.service';

@Module({
  imports: [
    HttpModule.register({
      baseURL: 'https://api.metrolisboa.pt:8243/estadoServicoML/1.0.1',
      timeout: 5000,
      httpsAgent: new https.Agent({
        rejectUnauthorized: false, // Metro API uses a cert chain that Node fails to verify. @TODO trust their CA in production.
      }),
    }),
  ],
  controllers: [MetroController],
  providers: [MetroService, MetroTokenService],
})
export class MetroModule {}

