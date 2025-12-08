import { IsNotEmpty, IsString } from 'class-validator';

/**
 * DTO de login.
 *
 * Permite autenticação via email **ou** username usando o campo `identifier`.
 */
export class LoginDto {
  /**
   * Identificador do utilizador.
   * Pode ser email ou username.
   */
  @IsNotEmpty()
  @IsString()
  identifier: string;

  /**
   * Password em texto simples (será validada e comparada com o hash).
   */
  @IsNotEmpty()
  @IsString()
  password: string;
}
