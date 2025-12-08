// src/flixbus/dto/flixbus-graph.dto.ts

// Linha FlixBus vinda do grafo OTP/GTFS
/**
 * Representa uma rota/linha FlixBus tal como vem do grafo GTFS (OTP),
 * já normalizada para consumo pelo backend/frontend.
 */
export interface FlixbusGraphRouteDto {
  /** Identificador GTFS da rota (ex.: "FLIXBUS:123") */
  gtfsId: string;
  /** Nome curto da linha (quando existir) */
  shortName?: string | null;
  /** Nome longo/descritivo da linha */
  longName?: string | null;
  /** Modo de transporte (BUS, COACH, etc.) */
  mode: string;
  /** Nome da agência (ex.: "FlixBus") */
  agencyName?: string | null;
  /** Identificador GTFS da agência */
  agencyGtfsId?: string | null;
}

// Stop básico (id + nome + coords)
/**
 * Representação básica de uma paragem/paragem FlixBus,
 * usada tanto em detalhes de linha como em resultados de pesquisa.
 */
export interface FlixbusStopBasicDto {
  /** Identificador GTFS da paragem */
  gtfsId: string;
  /** Nome da paragem (geralmente o nome da estação de autocarros) */
  name: string;
  /** Latitude da paragem (quando presente no GTFS) */
  lat?: number;
  /** Longitude da paragem (quando presente no GTFS) */
  lon?: number;
}

// Detalhe de linha + lista de stops
/**
 * Detalhe de uma rota FlixBus, incluindo a lista de paragens associadas.
 */
export interface FlixbusGraphRouteDetailDto extends FlixbusGraphRouteDto {
  /** Lista de paragens desta rota (sem ordem garantida) */
  stops: FlixbusStopBasicDto[];
}

// Resultado de pesquisa de stops
/**
 * Resultado de pesquisa de paragens FlixBus (para autocomplete, etc.).
 */
export interface FlixbusStopSearchResultDto {
  /** Identificador GTFS da paragem */
  gtfsId: string;
  /** Nome da paragem */
  name: string;
  /** Latitude (se disponível) */
  lat?: number;
  /** Longitude (se disponível) */
  lon?: number;
}

// Partida bruta vinda do grafo (tipo CPDepartureDto)
/**
 * Representa uma partida (stoptime) FlixBus em formato "bruto" GTFS,
 * semelhante ao modelo usado para CP.
 *
 * - `serviceDay` é o início do dia de serviço em epoch seconds
 * - os tempos de partida são segundos desde `serviceDay`
 */
export interface FlixbusDepartureDto {
  /** ID GTFS da rota associada */
  routeGtfsId?: string;
  /** Nome curto da rota */
  routeShortName?: string | null;
  /** Nome longo da rota */
  routeLongName?: string | null;
  /** Modo (BUS / COACH, etc.) */
  mode: string; // BUS / COACH, etc.
  /** Nome da agência (idealmente "FlixBus") */
  agencyName?: string | null;
  /** Destino / headsign da viagem */
  headsign?: string | null;
  /** Partida agendada – segundos desde `serviceDay` */
  scheduledDeparture: number; // segundos desde serviceDay
  /** Partida em tempo real – segundos desde `serviceDay` */
  realtimeDeparture: number; // idem, com atraso
  /** Indica se o valor de realtime é efetivamente em tempo real */
  realtime: boolean;
  /** Epoch (segundos) da meia-noite local do dia de serviço */
  serviceDay: number; // epoch (segundos, meia-noite local)
}

// Resposta bruta de partidas por stop
/**
 * Pacote de partidas FlixBus para uma paragem específica,
 * ainda no formato "raw" GTFS.
 */
export interface FlixbusStopDeparturesDto {
  /** ID GTFS da paragem */
  stopId: string;
  /** Nome da paragem */
  stopName: string;
  /** Latitude da paragem */
  lat?: number;
  /** Longitude da paragem */
  lon?: number;
  /** Lista de partidas dentro da janela temporal pedida */
  departures: FlixbusDepartureDto[];
}

// Linha da board formatada para UI
/**
 * Linha individual de um "quadro de partidas" FlixBus,
 * já formatada para apresentação na interface.
 */
export interface FlixbusStopBoardRowDto {
  /** Hora de partida formatada ("HH:MM") */
  time: string; // "HH:MM"
  /** Destino da viagem (headsign ou similar) */
  destination: string | null; // headsign
  /** Nome curto da linha */
  lineShortName?: string | null;
  /** Nome longo da linha */
  lineLongName?: string | null;
  /** ID GTFS da rota associada */
  routeGtfsId?: string;
  /** Atraso em minutos (pode ser 0) */
  delayMinutes: number; // pode ser 0
  /** Indica se a informação é realtime ou apenas planeada */
  isRealtime: boolean;
}

// Board completo de uma paragem
/**
 * Quadro de partidas FlixBus para uma paragem,
 * pronto a ser consumido pelo frontend.
 */
export interface FlixbusStopBoardDto {
  /** ID GTFS da paragem */
  stopId: string;
  /** Nome da paragem */
  stopName: string;
  /** Latitude da paragem */
  lat?: number;
  /** Longitude da paragem */
  lon?: number;
  /** Lista de linhas do quadro de partidas (ordenadas por hora) */
  departures: FlixbusStopBoardRowDto[];
}
