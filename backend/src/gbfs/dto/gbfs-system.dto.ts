// backend/src/gbfs/dto/gbfs-system.dto.ts

/**
 * DTO para expor um registo da tabela `gbfs_systems` (Prisma).
 *
 * Representa um sistema de bike/scooter share configurado na BD,
 * carregado a partir do ficheiro `systems_PT.csv`.
 */
export class GbfsSystemDto {
  /** ID interno (autoincrement) na base de dados */
  id: number;

  /** Código ISO do país (ex.: "PT") */
  countryCode: string;

  /** Nome legível do sistema (ex.: "GIRA", "Bird Lisboa") */
  name: string;

  /** Localização/resumo textual (ex.: "Lisboa") */
  location?: string | null;

  /** Identificador único do sistema vindo do CSV (`System ID`) */
  systemId: string;

  /** URL principal (site do operador), quando disponível */
  url?: string | null;

  /** URL de auto-discovery (`gbfs.json` / `gbfs`) */
  autoDiscoveryUrl?: string | null;

  /** Versões de GBFS suportadas, tal como vem no CSV */
  supportedVersions?: string | null;

  /** URL com informação de autenticação (se for necessária) */
  authenticationInfoUrl?: string | null;
}
