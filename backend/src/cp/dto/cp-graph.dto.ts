// src/cp/dto/cp-graph.dto.ts

/**
 * Representa uma rota/linha CP tal como vem do grafo GTFS (OTP),
 * já normalizada para uso no backend/frontend.
 */
export interface CpGraphRouteDto {
  /** Identificador GTFS da rota (ex.: "CP:Line:123") */
  gtfsId: string;
  /** Nome curto da linha (ex.: "ALFA", "IR", "R") */
  shortName?: string | null;
  /** Nome longo/descritivo da linha */
  longName?: string | null;
  /** Modo de transporte (ex.: "RAIL") */
  mode: string;
  /** Nome da agência (ex.: "CP - Comboios de Portugal") */
  agencyName?: string | null;
  /** Identificador GTFS da agência */
  agencyGtfsId?: string | null;
}

/**
 * Representação básica de uma paragem/estação CP como aparece em rotas.
 */
export interface CpStopBasicDto {
  /** Identificador GTFS da paragem */
  gtfsId: string;
  /** Nome da paragem/estação */
  name: string;
  /** Latitude da paragem (opcional se ausência no GTFS) */
  lat?: number;
  /** Longitude da paragem (opcional se ausência no GTFS) */
  lon?: number;
}

/**
 * Detalhe de uma rota CP, incluindo a lista de paragens.
 */
export interface CpGraphRouteDetailDto extends CpGraphRouteDto {
  /** Lista de paragens que compõem a rota */
  stops: CpStopBasicDto[];
}

/**
 * Resultado de pesquisa de paragens CP a partir do OTP (para autocomplete).
 */
export interface CpStopSearchResultDto {
  /** Identificador GTFS da paragem */
  gtfsId: string;
  /** Nome da paragem */
  name: string;
  /** Latitude da paragem (quando disponível) */
  lat?: number;
  /** Longitude da paragem (quando disponível) */
  lon?: number;
}

/**
 * Partida (stoptime) bruta a partir do grafo GTFS da CP.
 *
 * Usa o modelo clássico OTP:
 *  - `serviceDay`: epoch seconds da meia-noite do "service day"
 *  - `scheduledDeparture`/`realtimeDeparture`: segundos desde `serviceDay`
 */
export interface CpDepartureDto {
  /** ID GTFS da rota associada à partida */
  routeGtfsId?: string;
  /** Nome curto da linha (ex.: "ALFA") */
  routeShortName?: string | null;
  /** Nome longo da linha */
  routeLongName?: string | null;
  /** Modo de transporte (esperado: "RAIL"/"TRAIN") */
  mode: string;
  /** Nome da agência (ex.: "CP - Comboios de Portugal") */
  agencyName?: string | null;
  /** Destino/heading visível (headsign) */
  headsign?: string | null;
  /** Partida agendada – segundos desde `serviceDay` */
  scheduledDeparture: number;
  /** Partida em tempo real – segundos desde `serviceDay` */
  realtimeDeparture: number;
  /** Indica se a informação é em tempo real ou apenas agendada */
  realtime: boolean;
  /** Epoch seconds da meia-noite local do dia de serviço */
  serviceDay: number;
}

/**
 * Partidas de uma paragem específica, no formato "bruto GTFS".
 */
export interface CpStopDeparturesDto {
  /** ID GTFS da paragem */
  stopId: string;
  /** Nome da paragem */
  stopName: string;
  /** Latitude da paragem */
  lat?: number;
  /** Longitude da paragem */
  lon?: number;
  /** Lista de partidas dentro da janela temporal pedida */
  departures: CpDepartureDto[];
}

/**
 * Linha formatada para um "quadro de partidas" (stop board) amigável.
 */
export interface CpStopBoardRowDto {
  /** Hora de partida formatada para UI ("HH:MM") */
  time: string;
  /** Destino da viagem (headsign), se disponível */
  destination: string | null;
  /** Nome curto da linha */
  lineShortName?: string | null;
  /** Nome longo da linha */
  lineLongName?: string | null;
  /** ID GTFS da rota associada */
  routeGtfsId?: string;
  /** Atraso em minutos (pode ser 0) */
  delayMinutes: number;
  /** Indica se os dados são em tempo real ou apenas planeados */
  isRealtime: boolean;
}

/**
 * Modelo de "quadro de partidas" completo para uma paragem,
 * pronto a ser consumido pela UI.
 */
export interface CpStopBoardDto {
  /** ID GTFS da paragem */
  stopId: string;
  /** Nome da paragem */
  stopName: string;
  /** Latitude da paragem */
  lat?: number;
  /** Longitude da paragem */
  lon?: number;
  /** Linhas do quadro de partidas, ordenadas por hora */
  departures: CpStopBoardRowDto[];
}
