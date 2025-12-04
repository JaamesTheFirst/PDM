import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { RoutesController } from './routes.controller';
import { OtpService } from './otp.service';
import { RoutesService } from './routes.service';
import { PrismaModule } from '../prisma/prisma.module';
import { ImpactModule } from '../impact/impact.module';

@Module({
  imports: [HttpModule, ConfigModule, PrismaModule,ImpactModule,],
  controllers: [RoutesController],
  providers: [OtpService, RoutesService],
  exports: [OtpService, RoutesService],
})
export class RoutesModule {}
