import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/**
 * Guard de autenticação baseado em JWT.
 *
 * Usa a estratégia 'jwt' (configurada em `JwtStrategy`) para validar
 * o token Bearer enviado no header Authorization.
 *
 * Exemplo:
 * ```ts
 * @UseGuards(JwtAuthGuard)
 * @Get('me')
 * async me() { ... }
 * ```
 */
@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {}
