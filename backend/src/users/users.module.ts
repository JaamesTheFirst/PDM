import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { PrismaService } from '../prisma/prisma.service';
import { UsersPreferencesService } from './preferences/users-preferences.service';

/**
 * Módulo de Users:
 * - expõe UsersService para outras partes (auth, etc.)
 * - regista UsersController (endpoints /users)
 * - inclui UsersPreferencesService para gerir userPreferences.
 */
@Module({
  providers: [UsersService, PrismaService, UsersPreferencesService],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule {}
