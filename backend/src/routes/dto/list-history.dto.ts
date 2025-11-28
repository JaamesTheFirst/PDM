import { IsOptional, IsString } from 'class-validator';

export class ListHistoryQueryDto {
  @IsOptional()
  @IsString()
  status?: string;

  @IsOptional()
  @IsString()
  primaryMode?: string;
}
