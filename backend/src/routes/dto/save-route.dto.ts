import { IsNotEmpty, IsOptional, IsString, IsNumber } from 'class-validator';

/**
 * DTO usado quando o frontend escolhe um itinerary e o envia
 * para ser persistido como RouteHistory.
 */
export class SaveRouteDto {
  /**
   * Itinerary bruto devolvido pelo OTP (já com legs, times, etc.).
   * Mantido como any para não acoplar demasiado ao schema GraphQL.
   */
  @IsNotEmpty()
  itinerary: any;

  /** Override opcional do nome de origem escolhido pelo utilizador */
  @IsOptional()
  @IsString()
  originName?: string;

  /** Override opcional da latitude da origem */
  @IsOptional()
  @IsNumber()
  originLatitude?: number;

  /** Override opcional da longitude da origem */
  @IsOptional()
  @IsNumber()
  originLongitude?: number;

  /** Override opcional do nome de destino */
  @IsOptional()
  @IsString()
  destinationName?: string;

  /** Override opcional da latitude do destino */
  @IsOptional()
  @IsNumber()
  destinationLatitude?: number;

  /** Override opcional da longitude do destino */
  @IsOptional()
  @IsNumber()
  destinationLongitude?: number;
}
