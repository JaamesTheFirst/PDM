import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { RoutesController } from './routes.controller';
import { OtpService } from './otp.service';

@Module({
  imports: [HttpModule, ConfigModule],
  controllers: [RoutesController],
  providers: [OtpService],
  exports: [OtpService],
})
export class RoutesModule {}
