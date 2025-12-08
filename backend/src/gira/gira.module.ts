// src/gira/gira.module.ts
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { GiraService } from './gira.service';
import { GiraController } from './gira.controller';
import { PrismaModule } from '../prisma/prisma.module';

/**
 * Módulo GIRA.
 *
 * Responsável por:
 *  - carregar o ficheiro de estações GIRA para a tabela `gira_stations`
 *  - expor endpoints de leitura/pesquisa dessas estações
 */
@Module({
  imports: [ConfigModule, PrismaModule],
  providers: [GiraService],
  controllers: [GiraController],
  exports: [GiraService],
})
export class GiraModule {}
