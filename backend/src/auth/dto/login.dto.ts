import { IsNotEmpty, IsString } from 'class-validator';

// "identifier" pode ser email OU username
export class LoginDto {
  @IsNotEmpty()
  @IsString()
  identifier: string;

  @IsNotEmpty()
  @IsString()
  password: string;
}
