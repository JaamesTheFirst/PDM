import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { AuthService } from './auth.service';
import { AuthController } from './auth.controller';
import { JwtStrategy } from './strategies/jwt.strategy';

/**
 * Módulo de autenticação.
 *
 * Responsável por:
 *  - configurar JWT (secret + expiração)
 *  - integrar Passport com a estratégia 'jwt'
 *  - expor `AuthService` para outros módulos
 */
@Module({
  imports: [
    // Integração com Passport (necessário para o AuthGuard)
    PassportModule,
    // Configuração do módulo JWT (assinatura e verificação de tokens)
    JwtModule.register({
      secret: process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-this-in-production',
      signOptions: { expiresIn: process.env.JWT_EXPIRES_IN || '1d' },
    }),
  ],
  controllers: [AuthController],
  providers: [AuthService, JwtStrategy],
  exports: [AuthService],
})
export class AuthModule {}
