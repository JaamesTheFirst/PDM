import {
  IsArray,
  IsInt,
  IsOptional,
  IsString,
  IsBoolean,
  IsNumber,
} from 'class-validator';

/**
 * DTO para atualização das preferências de navegação/rotas do utilizador.
 *
 * Tem:
 * - propriedades canónicas usadas na DB (preferredTransportModes, maxWalkingDistance, ...)
 * - aliases para retrocompatibilidade com versões antigas do frontend.
 */
export class UpdatePreferencesDto {
  // ===== Propriedades canónicas (usadas na DB / service) =====

  /**
   * Lista de modos de transporte preferidos (strings livres, ex: ["BUS", "METRO"]).
   * No service isto é persistido como array de strings numa tabela userPreferences.
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferredTransportModes?: string[];

  /**
   * Distância máxima de walking em metros.
   * Pode ser derivada de radiusKm se o cliente mandar só em km.
   */
  @IsOptional()
  @IsInt()
  maxWalkingDistance?: number;

  /** Flag para evitar autoestradas (dependente do planner de rotas). */
  @IsOptional()
  @IsBoolean()
  avoidHighways?: boolean;

  /**
   * Se true, o utilizador quer apenas opções eco-friendly.
   * Cabe ao planner interpretar isto (filtrar modos, etc.).
   */
  @IsOptional()
  @IsBoolean()
  ecoFriendlyOnly?: boolean;

  // ===== Aliases para retrocompatibilidade com clientes antigos =====

  /**
   * Alias antigo para preferredTransportModes.
   * Se vier definido e a versão canónica estiver vazia, é usado pelo service.
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferredTransport?: string[];

  /**
   * Outro alias antigo para preferredTransportModes.
   */
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  preferredModes?: string[];

  /**
   * Raio em quilómetros (mais amigável para o cliente).
   * No service é convertido para maxWalkingDistance em metros.
   */
  @IsOptional()
  @IsNumber()
  radiusKm?: number;
}
