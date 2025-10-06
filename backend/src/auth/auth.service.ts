import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { SignUpDto } from './dto/signup.dto';
import { LoginDto } from './dto/login.dto';

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async register(dto: SignUpDto): Promise<string> {
    const [byEmail, byUsername] = await Promise.all([
      this.prisma.user.findUnique({ where: { email: dto.email } }),
      this.prisma.user.findUnique({ where: { username: dto.username } }),
    ]);
    if (byEmail) throw new BadRequestException('Email já registado.');
    if (byUsername) throw new BadRequestException('Username já registado.');

    const hash = await bcrypt.hash(dto.password, 12);

    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        username: dto.username,
        password: hash,
        firstName: dto.firstName ?? null,
        lastName: dto.lastName ?? null,
        preferences: {
          create: {
            preferredTransportTypes: [],
            maxWalkingDistance: 500,
            avoidHighways: false,
            ecoFriendlyOnly: true,
          },
        },
      },
      select: { id: true, email: true, username: true },
    });

    return this.signToken(user.id, user.email, user.username);
  }

  async login(dto: LoginDto): Promise<string> {
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: dto.identifier }, { username: dto.identifier }] },
    });
    if (!user) throw new UnauthorizedException('Credenciais inválidas.');

    const ok = await bcrypt.compare(dto.password, user.password);
    if (!ok) throw new UnauthorizedException('Credenciais inválidas.');

    return this.signToken(user.id, user.email, user.username);
  }

  private signToken(userId: string, email: string, username: string): string {
    const payload = { sub: userId, email, username };
    return this.jwt.sign(payload);
  }
}
