// backend/src/prisma/prisma.module.ts
//
// Módulo global que expõe o PrismaService para o resto da aplicação NestJS.
// Como está marcado com @Global(), não é preciso importar explicitamente
// este módulo em todos os outros; basta uma vez no root module, e o
// PrismaService fica injetável em qualquer lugar.

import { Global, Module } from '@nestjs/common';
import { PrismaService } from './prisma.service';

@Global()
@Module({
  providers: [PrismaService],
  exports: [PrismaService],
})
export class PrismaModule {}
