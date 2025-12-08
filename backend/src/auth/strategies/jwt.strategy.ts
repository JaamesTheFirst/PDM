import { Injectable } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { JwtPayload } from '../types/jwt-payload.type';

/**
 * Estratégia JWT para Passport/NestJS.
 *
 * Responsável por:
 *  - extrair o token do header Authorization (Bearer)
 *  - validar assinatura e expiração com `JWT_SECRET`
 *  - devolver o payload que será exposto em `req.user`
 */
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor() {
    const secret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production';

    // Aviso para não usar a secret default em produção
    if (!secret || secret === 'your-super-secret-jwt-key-change-this-in-production') {
      console.warn('⚠️  Using default JWT secret. Set JWT_SECRET in your .env file!');
    }

    super({
      // Extrai token do header Authorization: Bearer <token>
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: secret,
    });
  }

  /**
   * Função de validação executada depois de o token ser verificado.
   *
   * Aqui poderias:
   *  - carregar o utilizador a partir da BD
   *  - aplicar lógica extra de autorização
   *
   * Neste caso, simplesmente devolvemos o payload já validado,
   * que ficará disponível como `req.user`.
   */
  async validate(payload: JwtPayload) {
    // payload: { sub, email, username, iat, exp }
    return payload;
  }
}
