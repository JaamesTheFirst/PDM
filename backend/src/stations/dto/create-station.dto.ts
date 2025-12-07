import { IsString, IsOptional, IsNumber, IsInt, Min } from 'class-validator';
import { StationType } from '@prisma/client';

/**
 * DTO para criação de uma Station na base de dados.
 *
 * Nota: `stationType` vem como string (alias ou nome completo),
 * e é normalizado na StationsService antes de gravar.
 */
export class CreateStationDto {
  /** Nome legível da estação (ex: "GIRA - Cais do Sodré") */
  @IsString()
  name: string;

  /** Descrição opcional / notas adicionais */
  @IsOptional()
  @IsString()
  description?: string;

  /** Latitude em WGS84 (ex: 38.7123) */
  @IsNumber()
  latitude: number;

  /** Longitude em WGS84 (ex: -9.1359) */
  @IsNumber()
  longitude: number;

  /** Morada textual, se existir (rua, nº, etc.) */
  @IsOptional()
  @IsString()
  address?: string;

  /** Cidade (ex: "Lisboa", "Porto") */
  @IsOptional()
  @IsString()
  city?: string;

  /** País (ex: "PT", "Portugal") */
  @IsOptional()
  @IsString()
  country?: string;

  /**
   * Identificador externo (ID da API do operador, GBFS, GIRA, etc.).
   * Normalmente usado em syncs / integrações.
   */
  @IsOptional()
  @IsString()
  externalId?: string;

  /**
   * Tipo de estação.
   *
   * Aceita:
   * - nome completo do enum (ex: "BIKE_STATION")
   * - alias curto (ex: "BIKE", "SCOOTER", "BUS")
   *
   * A normalização para StationType válido é feita no service.
   */
  @IsString()
  stationType: string;

  /** Capacidade total (ex: nº de docas / lugares) */
  @IsOptional()
  @IsInt()
  @Min(0)
  capacity?: number;

  /** Nº de veículos disponíveis (bicicletas, trotinetes, etc.) */
  @IsOptional()
  @IsInt()
  @Min(0)
  availableVehicles?: number;

  /** Nº de docas / lugares livres disponíveis */
  @IsOptional()
  @IsInt()
  @Min(0)
  availableDocks?: number;
}
