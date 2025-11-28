import { Injectable, NotFoundException, BadRequestException, InternalServerErrorException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { UsersPreferencesService } from './preferences/users-preferences.service';
import { CreateUserDto } from './dto/create-user.dto';
import { UpdateUserDto } from './dto/update-user.dto';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import * as bcrypt from 'bcryptjs';

@Injectable()
export class UsersService {
  constructor(private prisma: PrismaService, private usersPreferencesService: UsersPreferencesService) {}

  async create(data: CreateUserDto) {
    // valida unicidade do email
    const existingEmail = await this.prisma.user.findUnique({ where: { email: data.email } });
    if (existingEmail) throw new BadRequestException('Email already in use');

    // valida unicidade do username
    if (data.username) {
      const existingUsername = await this.prisma.user.findFirst({ where: { username: data.username } });
      if (existingUsername) throw new BadRequestException('Username already in use');
    }

    const hashed = await bcrypt.hash(data.password, 10);

    // cria user e devolve campos seguros (sem password)
    return this.prisma.user.create({
      data: {
        email: data.email,
        username: data.username,
        firstName: data.firstName ?? null,
        lastName: data.lastName ?? null,
        password: hashed,
      },
      select: {
        id: true,
        email: true,
        username: true,
        firstName: true,
        lastName: true,
        createdAt: true,
      },
    });
  }

  async findByEmail(email: string) {
    return this.prisma.user.findUnique({ where: { email } });
  }

  async findById(id: string) {
    return this.prisma.user.findUnique({
      where: { id },
      select: {
        id: true,
        email: true,
        username: true,
        firstName: true,
        lastName: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async updateUser(userId: string, data: UpdateUserDto) {
    // validações básicas e mapeamento para campos que existem no Prisma
    const updates: any = {};

    if (data.firstName !== undefined) updates.firstName = data.firstName;
    if (data.lastName !== undefined) updates.lastName = data.lastName;
    if (data.email !== undefined) {
      // garante unicidade do email
      const existing = await this.prisma.user.findFirst({
        where: { email: data.email, NOT: { id: userId } },
      });
      if (existing) throw new BadRequestException('Email already in use');
      updates.email = data.email;
    }
    if (data.username !== undefined) {
      const existingU = await this.prisma.user.findFirst({
        where: { username: data.username, NOT: { id: userId } },
      });
      if (existingU) throw new BadRequestException('Username already in use');
      updates.username = data.username;
    }
    if (data.password !== undefined) {
      const hashed = await bcrypt.hash(data.password, 10);
      updates.password = hashed;
    }

    if (Object.keys(updates).length === 0) {
      // nada para atualizar — devolve o user atual
      return this.findById(userId);
    }

    return this.prisma.user.update({
      where: { id: userId },
      data: updates,
      select: {
        id: true,
        email: true,
        username: true,
        firstName: true,
        lastName: true,
        createdAt: true,
        updatedAt: true,
      },
    });
  }

  async updatePreferences(userId: string, prefs: UpdatePreferencesDto) {
    return this.usersPreferencesService.updatePreferences(userId, prefs);
  }

  async getPreferences(userId: string) {
    return this.usersPreferencesService.getPreferences(userId);
  }
}
