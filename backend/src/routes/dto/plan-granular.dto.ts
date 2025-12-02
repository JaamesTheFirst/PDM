import {
  IsArray,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  Min,
} from 'class-validator';
import { Type } from 'class-transformer';

/**
 * Granular transit types that users can select
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
 * DTO for granular route planning with specific transit type selections
 * This allows users to select specific transport types (e.g., bus + metro but not rail)
 */
export class PlanGranularDto {
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
   * Base modes that OTP can use (WALK, BICYCLE, CAR, TRANSIT)
   * Default: [WALK, TRANSIT]
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  baseModes?: string[];

  /**
   * Granular transit types to include (BUS, RAIL, METRO, TRAM, BICYCLE_SHARE, SCOOTER_SHARE)
   * If provided, only routes that use EXACTLY these transit types (plus walking for ingress/egress) will be returned.
   * Example: If user selects BUS only, routes using BUS+METRO will be excluded.
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  transitTypes?: string[];

  /**
   * Walk máximo aceitável (soma de todos os legs WALK) em metros.
   */
  @IsOptional()
  @Type(() => Number)
  @IsInt()
  @Min(0)
  maxWalkDistanceMeters?: number;
}

