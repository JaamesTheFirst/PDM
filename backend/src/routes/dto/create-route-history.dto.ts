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

export class CreateRouteHistoryDto {
  @IsString()
  @IsNotEmpty()
  originName: string;

  @Type(() => Number)
  @IsNumber()
  originLatitude: number;

  @Type(() => Number)
  @IsNumber()
  originLongitude: number;

  @IsString()
  @IsNotEmpty()
  destinationName: string;

  @Type(() => Number)
  @IsNumber()
  destinationLatitude: number;

  @Type(() => Number)
  @IsNumber()
  destinationLongitude: number;

  @IsEnum(TransportMode)
  primaryMode: TransportMode;

  @IsArray()
  @IsEnum(TransportMode, { each: true })
  modes: TransportMode[];

  @Type(() => Number)
  @IsInt()
  @Min(0)
  distanceMeters: number;

  @Type(() => Number)
  @IsInt()
  @Min(0)
  durationSeconds: number;

  @IsOptional()
  @IsEnum(RouteStatus)
  status?: RouteStatus;

  @IsOptional()
  @IsDateString()
  startedAt?: string;

  @IsOptional()
  @IsDateString()
  finishedAt?: string;

  @IsOptional()
  @IsString()
  polyline?: string;

  // podes mandar legs normalizados ou o que fizer sentido
  @IsOptional()
  segments?: unknown;

  // payload bruto do OTP (para debug, opcional)
  @IsOptional()
  metadata?: unknown;

  // no futuro o módulo ECO pode recalcular isto automaticamente
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  co2Kg?: number;

  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(0)
  co2SavedVsCarKg?: number;
}
