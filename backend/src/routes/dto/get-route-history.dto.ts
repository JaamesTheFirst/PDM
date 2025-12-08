import { Type } from 'class-transformer';
import { IsDateString, IsEnum, IsInt, IsOptional, Min } from 'class-validator';
import { RouteStatus, TransportMode } from '@prisma/client';

/**
 * Filtros para consulta de histórico de rotas (GET).
 */
export class GetRouteHistoryQueryDto {
  /** Incluir viagens com startedAt >= from (ISO8601) */
  @IsOptional()
  @IsDateString()
  from?: string;

  /** Incluir viagens com startedAt <= to (ISO8601) */
  @IsOptional()
  @IsDateString()
  to?: string;

  /** Filtrar por modo principal (primaryMode) */
  @IsOptional()
  @IsEnum(TransportMode)
  primaryMode?: TransportMode;

  /** Filtrar por estado da rota (PLANNED, COMPLETED, CANCELLED, ...) */
  @IsOptional()
  @IsEnum(RouteStatus)
  status?: RouteStatus;

  /** Limite de registos devolvidos (paginações simples) */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  limit?: number;

  /** Offset para paginação (skip) */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  offset?: number;
}
