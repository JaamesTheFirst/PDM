import { Type } from 'class-transformer';
import { IsInt, IsOptional, IsString, Min } from 'class-validator';

/**
 * Query DTO simplificado para listagem de histórico
 * via /routes/history (usado pelo RoutesService.listHistoryForUser).
 */
export class ListHistoryQueryDto {
  /** Filtrar por estado (string, validado depois contra RouteStatus) */
  @IsOptional()
  @IsString()
  status?: string;

  /** Filtrar por primaryMode (string, validado depois contra TransportMode) */
  @IsOptional()
  @IsString()
  primaryMode?: string;

  /** Limite máximo de registos devolvidos */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;
}
