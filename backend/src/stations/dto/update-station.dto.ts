import { IsString, IsOptional, IsNumber, IsInt, Min } from 'class-validator';
import { StationType } from '@prisma/client';

/**
 * DTO para atualização parcial de uma Station.
 * Todos os campos são opcionais; só o que vier definido é atualizado.
 */
export class UpdateStationDto {
  /** Novo nome da estação (se quiseres alterar) */
  @IsOptional()
  @IsString()
  name?: string;

  /** Nova descrição / notas adicionais */
  @IsOptional()
  @IsString()
  description?: string;

  /** Atualizar latitude */
  @IsOptional()
  @IsNumber()
  latitude?: number;

  /** Atualizar longitude */
  @IsOptional()
  @IsNumber()
  longitude?: number;

  /** Atualizar morada textual */
  @IsOptional()
  @IsString()
  address?: string;

  /** Atualizar cidade */
  @IsOptional()
  @IsString()
  city?: string;

  /** Atualizar país */
  @IsOptional()
  @IsString()
  country?: string;

  /** Atualizar externalId (ID do operador / fonte) */
  @IsOptional()
  @IsString()
  externalId?: string;

  /**
   * Atualizar tipo de estação.
   *
   * Aceita alias (ex: "BIKE") ou valor completo de enum (ex: "BIKE_STATION").
   * A normalização é feita na StationsService.
   */
  @IsOptional()
  @IsString()
  stationType?: string;

  /** Atualizar capacidade total */
  @IsOptional()
  @IsInt()
  @Min(0)
  capacity?: number;

  /** Atualizar nº de veículos disponíveis */
  @IsOptional()
  @IsInt()
  @Min(0)
  availableVehicles?: number;

  /** Atualizar nº de docas / lugares livres */
  @IsOptional()
  @IsInt()
  @Min(0)
  availableDocks?: number;
}
