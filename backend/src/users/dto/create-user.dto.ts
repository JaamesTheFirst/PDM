import { IsEmail, IsString, MinLength, MaxLength, IsOptional } from 'class-validator';

/**
 * DTO para criação de utilizador (signup).
 *
 * Este DTO é usado pelo Auth/Users para registar um novo user
 * com email + password + username e nomes opcionais.
 */
export class CreateUserDto {
  /** Email de login, validado com formato de email. */
  @IsEmail()
  email: string;

  /**
   * Password em texto plano (vai ser hasheada com bcrypt no service).
   * Mínimo 6 caracteres para evitar passwords demasiado fracas.
   */
  @IsString()
  @MinLength(6)
  password: string;

  /**
   * Username público (não precisa ser único na DB, mas é validado à mão).
   */
  @IsString()
  @MinLength(3)
  @MaxLength(30)
  username: string;

  /** Primeiro nome opcional (para perfis, UX, etc.) */
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  firstName?: string;

  /** Último nome opcional */
  @IsOptional()
  @IsString()
  @MinLength(2)
  @MaxLength(50)
  lastName?: string;
}
