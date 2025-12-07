// backend/src/gbfs/gbfs.module.ts
import { Module } from '@nestjs/common';
import { HttpModule } from '@nestjs/axios';
import { GbfsService } from './gbfs.service';
import { GbfsController } from './gbfs.controller';
import { PrismaModule } from '../prisma/prisma.module';

/**
 * Módulo responsável pela integração com sistemas GBFS.
 *
 * Depende de:
 *  - HttpModule: para fazer requests aos endpoints dos operadores
 *  - PrismaModule: para ler/escrever metadados de sistemas e estações
 */
@Module({
  imports: [HttpModule, PrismaModule],
  providers: [GbfsService],
  controllers: [GbfsController],
  exports: [GbfsService],
})
export class GbfsModule {}
