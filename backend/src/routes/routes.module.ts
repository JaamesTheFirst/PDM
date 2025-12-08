import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { RoutesController } from './routes.controller';
import { OtpService } from './otp.service';
import { RoutesService } from './routes.service';
import { PrismaModule } from '../prisma/prisma.module';
import { ImpactModule } from '../impact/impact.module';

/**
 * Módulo responsável por:
 * - integração com OTP (OtpService)
 * - lógica de planeamento + filtros (RoutesService)
 * - endpoints de rotas / histórico (RoutesController)
 */
@Module({
  imports: [HttpModule, ConfigModule, PrismaModule, ImpactModule],
  controllers: [RoutesController],
  providers: [OtpService, RoutesService],
  exports: [OtpService, RoutesService],
})
export class RoutesModule {}
