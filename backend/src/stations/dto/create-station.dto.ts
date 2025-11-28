import { IsString, IsOptional, IsNumber, IsInt, Min } from 'class-validator';
import { StationType } from '@prisma/client';

export class CreateStationDto {
  @IsString()
  name: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsNumber()
  latitude: number;

  @IsNumber()
  longitude: number;

  @IsOptional()
  @IsString()
  address?: string;

  @IsOptional()
  @IsString()
  city?: string;

  @IsOptional()
  @IsString()
  country?: string;

  @IsOptional()
  @IsString()
  externalId?: string;

  // Accept a string (either the full enum value like "BIKE_STATION" or a short alias like "BIKE").
  // Normalisation is performed server-side before persisting.
  @IsString()
  stationType: string;

  @IsOptional()
  @IsInt()
  @Min(0)
  capacity?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  availableVehicles?: number;

  @IsOptional()
  @IsInt()
  @Min(0)
  availableDocks?: number;
}
