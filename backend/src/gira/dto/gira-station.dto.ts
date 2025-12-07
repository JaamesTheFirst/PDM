// src/gira/dto/gira-station.dto.ts

/**
 * Representa uma linha genérica do ficheiro original de estações GIRA.
 *
 * Como o ficheiro pode ter colunas diferentes consoante a versão,
 * usamos um dicionário `coluna -> valor`, onde o valor pode ser
 * string, number ou null.
 *
 * Exemplos de chaves comuns:
 *  - "ID"
 *  - "Name"
 *  - "Address"
 *  - "Latitude"
 *  - "Longitude"
 *  - "Capacity"
 */
export interface GiraStationRecordDto {
  [column: string]: string | number | null;
}

/**
 * Resultado paginado de estações GIRA.
 *
 * Usado pelo endpoint `GET /gira/stations` para devolver:
 *  - total de registos na BD
 *  - fatia (`slice`) com as linhas pedidas (limit/offset)
 */
export interface GiraStationsSliceDto {
  /** Número total de registos de estações na BD */
  total: number;
  /** Fatia de registos devolvida nesta página */
  slice: GiraStationRecordDto[];
}
