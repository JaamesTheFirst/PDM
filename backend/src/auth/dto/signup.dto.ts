import { IsEmail, IsNotEmpty, IsOptional, IsString, MinLength } from 'class-validator';

/**
 * DTO de registo de novo utilizador.
 *
 * Contém os dados mínimos para criar um utilizador e as suas preferências
 * iniciais (parte feita no `AuthService`).
 */
export class SignUpDto {
  /**
   * Email do utilizador (único).
   */
  @IsEmail()
  email: string;

  /**
   * Username público/único do utilizador.
   */
  @IsNotEmpty()
  @IsString()
  username: string;

  /**
   * Password em texto simples (min. 6 caracteres).
   * Será guardada na BD como hash.
   */
  @MinLength(6)
  password: string;

  /**
   * Primeiro nome do utilizador (opcional).
   */
  @IsOptional()
  @IsString()
  firstName?: string;

  /**
   * Último nome do utilizador (opcional).
   */
  @IsOptional()
  @IsString()
  lastName?: string;
}
