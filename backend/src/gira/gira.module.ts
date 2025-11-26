import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GiraService } from './gira.service';
import { GiraController } from './gira.controller';
import { PrismaModule } from '../prisma/prisma.module';

@Module({
  imports: [ConfigModule, PrismaModule],
  providers: [GiraService],
  controllers: [GiraController],
  exports: [GiraService],
})
export class GiraModule {}
