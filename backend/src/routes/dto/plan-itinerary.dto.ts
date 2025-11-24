import { IsArray, IsEnum, IsNumber, IsOptional, IsString } from 'class-validator';
import { Type } from 'class-transformer';

export enum TransitMode {
  BUS = 'BUS',
  TRAM = 'TRAM',
  METRO = 'METRO',
  RAIL = 'RAIL',
  COACH = 'COACH',
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

  @IsOptional()
  @IsArray()
  @IsEnum(TransitMode, { each: true })
  transitModes?: TransitMode[];
}

