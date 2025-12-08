import { BadRequestException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcrypt from 'bcrypt';
import { PrismaService } from '../prisma/prisma.service';
import { SignUpDto } from './dto/signup.dto';
import { LoginDto } from './dto/login.dto';

/**
 * Serviço de autenticação.
 *
 * Responsável por:
 *  - registar novos utilizadores
 *  - validar credenciais de login
 *  - gerar tokens JWT
 *  - configurar preferências iniciais do utilizador
 */
@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  /**
   * Regista um novo utilizador na BD.
   *
   * Passos:
   *  - verifica se o email ou username já existem
   *  - faz hash da password com bcrypt
   *  - cria o utilizador + preferências default
   *  - devolve um token JWT para login imediato
   *
   * @param dto Dados de registo (`SignUpDto`)
   * @returns Token JWT assinado
   */
  async register(dto: SignUpDto): Promise<string> {
    // Verifica se email ou username já estão em uso
    const [byEmail, byUsername] = await Promise.all([
      this.prisma.user.findUnique({ where: { email: dto.email } }),
      this.prisma.user.findUnique({ where: { username: dto.username } }),
    ]);

    if (byEmail) throw new BadRequestException('Email já registado.');
    if (byUsername) throw new BadRequestException('Username já registado.');

    // Gera hash seguro da password
    const hash = await bcrypt.hash(dto.password, 12);

    // Cria o utilizador + preferências default
    const user = await this.prisma.user.create({
      data: {
        email: dto.email,
        username: dto.username,
        password: hash,
        firstName: dto.firstName ?? null,
        lastName: dto.lastName ?? null,
        preferences: {
          create: {
            preferredTransportModes: [],
            maxWalkingDistance: 500,
            avoidHighways: false,
            ecoFriendlyOnly: true,
          },
        },
      },
      // Só devolvemos os campos necessários para o token
      select: { id: true, email: true, username: true },
    });

    return this.signToken(user.id, user.email, user.username);
  }

  /**
   * Faz login de um utilizador existente.
   *
   * Passos:
   *  - procura user por email **ou** username (campo `identifier`)
   *  - compara password fornecida com hash guardado
   *  - devolve token JWT se credenciais forem válidas
   *
   * @param dto Dados de login (`LoginDto`)
   * @returns Token JWT assinado
   */
  async login(dto: LoginDto): Promise<string> {
    // Tenta encontrar o utilizador por email ou username
    const user = await this.prisma.user.findFirst({
      where: { OR: [{ email: dto.identifier }, { username: dto.identifier }] },
    });

    if (!user) throw new UnauthorizedException('Credenciais inválidas.');

    // Compara password em texto plano com o hash na BD
    const ok = await bcrypt.compare(dto.password, user.password);
    if (!ok) throw new UnauthorizedException('Credenciais inválidas.');

    return this.signToken(user.id, user.email, user.username);
  }

  /**
   * Assina e gera um token JWT para o utilizador.
   *
   * @param userId ID do utilizador (sub)
   * @param email Email do utilizador
   * @param username Username público do utilizador
   * @returns Token JWT assinado
   */
  private signToken(userId: string, email: string, username: string): string {
    const payload = { sub: userId, email, username };
    return this.jwt.sign(payload);
  }
}
