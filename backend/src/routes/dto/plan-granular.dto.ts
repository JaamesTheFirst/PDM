import { IsArray, IsInt, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Tipos de transporte granular que o utilizador pode escolher explicitamente
 * (em cima dos modos macro do OTP).
 */
export enum GranularTransitType {
  BUS = 'BUS',
  RAIL = 'RAIL',
  METRO = 'METRO',
  TRAM = 'TRAM',
  BICYCLE_SHARE = 'BICYCLE_SHARE',
  SCOOTER_SHARE = 'SCOOTER_SHARE',
}

/**
 * DTO para planeamento granular:
 * - baseModes controla os modos macro permitidos no OTP
 * - transitTypes controla filtros adicionais aplicados no backend
 *   (apenas itinerários que usam exatamente esses tipos).
 */
export class PlanGranularDto {
  /** Latitude de origem */
  @Type(() => Number)
  @IsNumber()
  fromLat: number;

  /** Longitude de origem */
  @Type(() => Number)
  @IsNumber()
  fromLon: number;

  /** Latitude de destino */
  @Type(() => Number)
  @IsNumber()
  toLat: number;

  /** Longitude de destino */
  @Type(() => Number)
  @IsNumber()
  toLon: number;

  /**
   * Data/hora completa em ISO8601 (ex: "2025-11-26T18:06:57.644Z").
   * Se fornecido, tem prioridade sobre date/time separados.
   */
  @IsOptional()
  @IsString()
  dateTime?: string;

  /** Alternativa: apenas data "YYYY-MM-DD" (usar com time) */
  @IsOptional()
  @IsString()
  date?: string;

  /** Alternativa: apenas hora "HH:mm" (usar com date) */
  @IsOptional()
  @IsString()
  time?: string;

  /** Nº de itinerários a pedir ao OTP (default definido no service) */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  numItineraries?: number;

  /**
   * Modos base que o OTP pode usar (WALK, BICYCLE, CAR, TRANSIT).
   * Default: [WALK, TRANSIT].
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  baseModes?: string[];

  /**
   * Tipos de transporte granular a incluir:
   * - BUS, RAIL, METRO, TRAM, BICYCLE_SHARE, SCOOTER_SHARE
   *
   * Se fornecido, só são aceites itinerários que utilizem APENAS
   * estes tipos (mais WALK para acessos).
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  transitTypes?: string[];

  /**
   * Máximo de caminhada total permitida (soma de todos os legs WALK), em metros.
   * Itinerários acima deste valor são descartados.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  maxWalkDistanceMeters?: number;
}
