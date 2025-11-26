import { Module } from '@nestjs/common';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';
import { PrismaService } from '../prisma/prisma.service';
import { UsersPreferencesService } from './preferences/users-preferences.service';

@Module({
  providers: [UsersService, PrismaService, UsersPreferencesService],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule {}
