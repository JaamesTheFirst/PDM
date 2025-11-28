import { IsArray, IsInt, IsOptional, IsString, IsBoolean, IsNumber } from 'class-validator';

export class UpdatePreferencesDto {
  // Canonical properties used by the DB/service
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferredTransportModes?: string[];

  @IsOptional()
  @IsInt()
  maxWalkingDistance?: number;

  @IsOptional()
  @IsBoolean()
  avoidHighways?: boolean;

  @IsOptional()
  @IsBoolean()
  ecoFriendlyOnly?: boolean;

  // Aliases accepted for backwards-compatibility with older clients
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferredTransport?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferredModes?: string[];

  // radius in kilometres (client-friendly) — will be mapped to `maxWalkingDistance` (meters)
  @IsOptional()
  @IsNumber()
  radiusKm?: number;
}
