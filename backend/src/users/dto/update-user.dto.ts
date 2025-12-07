import { IsOptional, IsString, IsEmail, MinLength, MaxLength } from 'class-validator';

/**
 * DTO para atualizar dados básicos do utilizador (perfil).
 * Todos os campos são opcionais; só o que vier é aplicado.
 */
export class UpdateUserDto {
  /** Atualizar primeiro nome */
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  firstName?: string;

  /** Atualizar último nome */
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  lastName?: string;

  /** Atualizar email (único). Validado no service. */
  @IsOptional()
  @IsEmail()
  email?: string;

  /** Atualizar username (único). Validado no service. */
  @IsOptional()
  @IsString()
  @MinLength(3)
  @MaxLength(30)
  username?: string;

  /**
   * Atualizar password.
   * Vai ser hasheada no service antes de persistir.
   */
  @IsOptional()
  @IsString()
  @MinLength(8)
  password?: string;
}
