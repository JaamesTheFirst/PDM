import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GiraService } from './gira.service';
import { GiraController } from './gira.controller';

@Module({
  imports: [ConfigModule],
  providers: [GiraService],
  controllers: [GiraController],
  exports: [GiraService],
})
export class GiraModule {}

