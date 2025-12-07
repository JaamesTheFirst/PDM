// backend/src/prisma/prisma.service.ts
//
// Wrapper fino em torno do PrismaClient gerado,
// registado como provider NestJS. Faz apenas o
// connect na inicialização do módulo.

import { Injectable, OnModuleInit } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';

@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit {
  /**
   * Hook chamado pelo Nest quando o módulo é inicializado.
   * Aqui apenas garantimos que a ligação à base de dados é
   * estabelecida no arranque da aplicação.
   */
  async onModuleInit() {
    await this.$connect();
  }
}
