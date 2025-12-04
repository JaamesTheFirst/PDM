import { IsNotEmpty, IsOptional, IsString, IsNumber } from 'class-validator';

export class SaveRouteDto {
  @IsNotEmpty()
  itinerary: any; // mantém como any ou o tipo que já tinhas para o itinerary

  @IsOptional()
  @IsString()
  originName?: string;

  @IsOptional()
  @IsNumber()
  originLatitude?: number;

  @IsOptional()
  @IsNumber()
  originLongitude?: number;

  @IsOptional()
  @IsString()
  destinationName?: string;

  @IsOptional()
  @IsNumber()
  destinationLatitude?: number;

  @IsOptional()
  @IsNumber()
  destinationLongitude?: number;
}
