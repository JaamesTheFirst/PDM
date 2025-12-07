import {
  IsArray,
  IsEnum,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Modos macro suportados pelo OTP na GraphQL API.
 * Isto controla o que o OTP tem permissão para usar.
 */
export enum TransportMode {
  WALK = 'WALK',
  BICYCLE = 'BICYCLE',
  CAR = 'CAR',
  TRANSIT = 'TRANSIT',
}

/**
 * Filtro adicional aplicado somente no backend,
 * depois de receber os itinerários do OTP.
 */
export enum FilterMode {
  ANY = 'ANY',           // não filtra por modo, devolve todos
  WALK_ONLY = 'WALK_ONLY',
  BUS_ONLY = 'BUS_ONLY',
  RAIL_ONLY = 'RAIL_ONLY',
  CAR_ONLY = 'CAR_ONLY',
  BICYCLE_ONLY = 'BICYCLE_ONLY',
  METRO_ONLY = 'METRO_ONLY',
}

/**
 * DTO base para planeamento de itinerário via OTP.
 * Usado pelo endpoint /routes/plan.
 */
export class PlanItineraryDto {
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
   * Data/hora completa em ISO8601.
   * Se fornecida, tem prioridade sobre date/time separados.
   */
  @IsOptional()
  @IsString()
  dateTime?: string;

  /** Data "YYYY-MM-DD" (usar com time) */
  @IsOptional()
  @IsString()
  date?: string;

  /** Hora "HH:mm" (usar com date) */
  @IsOptional()
  @IsString()
  time?: string;

  /** Nº de itinerários pedidos ao OTP */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  numItineraries?: number;

  /**
   * Modos que o OTP está autorizado a usar.
   * Default no service: [WALK, TRANSIT].
   */
  @IsOptional()
  @IsArray()
  @IsEnum(TransportMode, { each: true })
  modes?: TransportMode[];

  /**
   * Filtro aplicado NO BACKEND em cima dos itinerários devolvidos:
   * - WALK_ONLY   → só itinerários 100% a pé
   * - BUS_ONLY    → só itinerários cujo transporte é BUS (pode ter WALK)
   * - RAIL_ONLY   → idem para RAIL/TRAIN
   * - METRO_ONLY  → METRO/SUBWAY/TRAM
   * - CAR_ONLY    → apenas carro
   * - BICYCLE_ONLY→ apenas bicicleta
   */
  @IsOptional()
  @IsEnum(FilterMode)
  filterMode?: FilterMode;

  /**
   * Máximo admissível de caminhada total (soma dos legs WALK), em metros.
   * Itinerários acima deste valor são descartados.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  maxWalkDistanceMeters?: number;
}
