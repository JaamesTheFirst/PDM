import { IsArray, IsInt, IsOptional, IsString, IsBoolean } from 'class-validator';

export class UpdatePreferencesDto {
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
}
