// backend/src/gbfs/dto/gbfs-index.dto.ts

/**
 * Metadados de um feed individual dentro do índice GBFS (`gbfs.json`).
 *
 * Exemplo:
 * ```json
 * {
 *   "name": "station_information",
 *   "url": "https://example.com/gbfs/pt/station_information.json"
 * }
 * ```
 */
export interface GbfsFeedMeta {
  /** Nome lógico do feed (ex.: "station_information", "station_status") */
  name: string;
  /** URL absoluto do ficheiro JSON desse feed */
  url: string;
}

/**
 * Bloco de dados por idioma dentro do `gbfs.json`.
 * A especificação GBFS organiza feeds por idioma (pt, en, ...).
 */
export interface GbfsIndexLanguageBlock {
  /** Lista de feeds disponíveis neste idioma */
  feeds: GbfsFeedMeta[];
}

/**
 * Representação tipada do ficheiro `gbfs.json` de um sistema.
 *
 * Referência: GBFS v2.x – ficheiro de auto-discovery.
 */
export interface GbfsIndexDto {
  /** Epoch seconds da última atualização do índice */
  last_updated: number;
  /** TTL sugerido pelo operador (segundos) para cache do índice */
  ttl: number;
  /**
   * Feeds por idioma, indexados pelo código de idioma ("pt", "en", ...).
   * Cada valor é um `GbfsIndexLanguageBlock`.
   */
  data: Record<string, GbfsIndexLanguageBlock>; // "pt", "en", ...
  /** Versão do schema GBFS (ex.: "2.3") */
  version: string;
}
