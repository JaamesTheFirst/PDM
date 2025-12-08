import { Type } from 'class-transformer';
import {
  IsArray,
  IsDateString,
  IsEnum,
  IsInt,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { RouteStatus, TransportMode } from '@prisma/client';

/**
 * DTO para criar um registo de histórico de rota (RouteHistory).
 * 
 * Normalmente é preenchido pelo backend quando guarda um itinerary
 * planeado pelo OTP, mas a estrutura suporta também criação manual/
 * futura via API se precisares.
 */
export class CreateRouteHistoryDto {
  /** Nome amigável da origem (ex: "Casa", "Avenida da Liberdade") */
  @IsString()
  @IsNotEmpty()
  originName: string;

  /** Latitude da origem (WGS84) */
  @Type(() => Number)
  @IsNumber()
  originLatitude: number;

  /** Longitude da origem (WGS84) */
  @Type(() => Number)
  @IsNumber()
  originLongitude: number;

  /** Nome amigável do destino (ex: "Trabalho") */
  @IsString()
  @IsNotEmpty()
  destinationName: string;

  /** Latitude do destino (WGS84) */
  @Type(() => Number)
  @IsNumber()
  destinationLatitude: number;

  /** Longitude do destino (WGS84) */
  @Type(() => Number)
  @IsNumber()
  destinationLongitude: number;

  /**
   * Modo principal da viagem, segundo enum TransportMode do Prisma.
   * Tipicamente é o modo com maior distância (BUS, TRAIN, METRO, CAR, etc.).
   */
  @IsEnum(TransportMode)
  primaryMode: TransportMode;

  /**
   * Conjunto de modos presentes na viagem (sem duplicados),
   * também baseados em TransportMode do Prisma.
   */
  @IsArray()
  @IsEnum(TransportMode, { each: true })
  modes: TransportMode[];

  /** Distância total em metros (soma de todos os legs) */
  @Type(() => Number)
  @IsInt()
  @Min(0)
  distanceMeters: number;

  /** Duração total em segundos (endTime - startTime) */
  @Type(() => Number)
  @IsInt()
  @Min(0)
  durationSeconds: number;

  /**
   * Estado da rota (PLANNED, COMPLETED, CANCELLED, ...).
   * Opcional – pode assumir default na camada de persistência.
   */
  @IsOptional()
  @IsEnum(RouteStatus)
  status?: RouteStatus;

  /** Timestamp ISO8601 de início da viagem */
  @IsOptional()
  @IsDateString()
  startedAt?: string;

  /** Timestamp ISO8601 de fim da viagem */
  @IsOptional()
  @IsDateString()
  finishedAt?: string;

  /**
   * Polyline codificada (se quiseres guardar uma versão simplificada
   * da geometria da rota).
   */
  @IsOptional()
  @IsString()
  polyline?: string;

  /**
   * Segmentos normalizados por perna (per-leg), em qualquer formato
   * que tenhas definido para o frontend/backend.
   */
  @IsOptional()
  segments?: unknown;

  /**
   * Payload bruto do OTP ou de outro motor de rotas,
   * útil para debug ou reprocessamento futuro.
   */
  @IsOptional()
  metadata?: unknown;

  /**
   * Emissões totais de CO₂ da viagem (kg).
   * Se não vier preenchido, podes calcular noutra camada.
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  co2Kg?: number;

  /**
   * CO₂ poupado em relação a um cenário de carro (kg).
   * baseline definido no eco/impact module.
   */
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  co2SavedVsCarKg?: number;
}
