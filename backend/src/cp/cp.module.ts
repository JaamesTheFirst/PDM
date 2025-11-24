import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { ConfigModule } from '@nestjs/config';
import { CpService } from './cp.service';
import { CpController } from './cp.controller';

@Module({
  imports: [HttpModule, ConfigModule],
  providers: [CpService],
  controllers: [CpController],
  exports: [CpService],
})
export class CpModule {}

