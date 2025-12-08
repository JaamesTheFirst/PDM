import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { JwtPayload } from '../types/jwt-payload.type';

/**
 * Decorator para obter o utilizador autenticado (payload JWT) a partir do request.
 *
 * Uso típico:
 * ```ts
 * @Get('me')
 * async me(@CurrentUser() user: JwtPayload) { ... }
 * ```
 *
 * O valor vem de `req.user`, preenchido pelo `JwtStrategy`.
 */
export const CurrentUser = createParamDecorator((_: unknown, ctx: ExecutionContext): JwtPayload => {
  const req = ctx.switchToHttp().getRequest();
  return req.user as JwtPayload;
});
