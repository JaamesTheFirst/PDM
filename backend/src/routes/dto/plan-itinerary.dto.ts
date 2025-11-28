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
 * Modos macro que o OTP aceita em transportModes.
 * Isto controla o que o OTP PODE usar.
 */
export enum TransportMode {
  WALK = 'WALK',
  BICYCLE = 'BICYCLE',
  CAR = 'CAR',
  TRANSIT = 'TRANSIT',
}

/**
 * Filtro que o backend vai aplicar em cima dos itinerários
 * depois de receber a resposta do OTP.
 */
export enum FilterMode {
  ANY = 'ANY',           // não filtra por modo, devolve tudo
  WALK_ONLY = 'WALK_ONLY',
  BUS_ONLY = 'BUS_ONLY',
  RAIL_ONLY = 'RAIL_ONLY',
  CAR_ONLY = 'CAR_ONLY',
  BICYCLE_ONLY = 'BICYCLE_ONLY',
  METRO_ONLY = 'METRO_ONLY',
}

export class PlanItineraryDto {
  @Type(() => Number)
  @IsNumber()
  fromLat: number;

  @Type(() => Number)
  @IsNumber()
  fromLon: number;

  @Type(() => Number)
  @IsNumber()
  toLat: number;

  @Type(() => Number)
  @IsNumber()
  toLon: number;

  // ISO opcional: "2025-11-26T18:06:57.644Z"
  @IsOptional()
  @IsString()
  dateTime?: string;

  // Alternativa: "YYYY-MM-DD"
  @IsOptional()
  @IsString()
  date?: string;

  // Alternativa: "HH:mm"
  @IsOptional()
  @IsString()
  time?: string;

  // Nº de itinerários que o OTP calcula
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(1)
  numItineraries?: number;

  /**
   * Modos que o OTP está autorizado a usar.
   * Default: [WALK, TRANSIT] (caminhar + transportes).
   */
  @IsOptional()
  @IsArray()
  @IsEnum(TransportMode, { each: true })
  modes?: TransportMode[];

  /**
   * Filtro aplicado PELO BACKEND em cima dos itinerários:
   * - WALK_ONLY   → só itinerários 100% a pé
   * - BUS_ONLY    → só itinerários cujo transporte é autocarro (pode ter WALK à volta)
   * - RAIL_ONLY   → idem mas com comboio
   * - etc.
   */
  @IsOptional()
  @IsEnum(FilterMode)
  filterMode?: FilterMode;

  /**
   * Walk máximo aceitável (soma de todos os legs WALK) em metros.
   * Se passar disto, o itinerary é descartado.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  maxWalkDistanceMeters?: number;
}
