import { Body, Controller, Get, HttpCode, HttpStatus, Post, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { SignUpDto } from './dto/signup.dto';
import { LoginDto } from './dto/login.dto';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { CurrentUser } from './decorators/current-user.decorator';
import { JwtPayload } from './types/jwt-payload.type';

/**
 * Controller responsável pelos endpoints de autenticação.
 *
 * Endpoints:
 *  - POST /auth/register → registo de novo utilizador
 *  - POST /auth/login    → login com email/username + password
 *  - GET  /auth/me       → devolve info do utilizador autenticado
 */
@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  /**
   * Regista um novo utilizador e devolve um token de acesso (JWT).
   *
   * Body: `SignUpDto`
   * Response: `{ access_token: string }`
   */
  @Post('register')
  async register(@Body() dto: SignUpDto) {
    const token = await this.auth.register(dto);
    return { access_token: token };
  }

  /**
   * Efetua login com email **ou** username e password.
   *
   * Body: `LoginDto`
   * Response: `{ access_token: string }`
   */
  @HttpCode(HttpStatus.OK)
  @Post('login')
  async login(@Body() dto: LoginDto) {
    const token = await this.auth.login(dto);
    return { access_token: token };
  }

  /**
   * Devolve o utilizador autenticado (payload do token).
   *
   * Protegido por JWT:
   *  - requer header Authorization: Bearer <token>
   *  - utiliza `JwtAuthGuard` + `JwtStrategy`
   */
  @UseGuards(JwtAuthGuard)
  @Get('me')
  async me(@CurrentUser() user: JwtPayload) {
    // Podes devolver só o payload ou fazer lookup na BD aqui
    return user; // { sub, email, username, iat, exp }
  }
}
