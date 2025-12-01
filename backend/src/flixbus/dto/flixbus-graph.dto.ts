// src/flixbus/dto/flixbus-graph.dto.ts

// Linha FlixBus vinda do grafo OTP/GTFS
export interface FlixbusGraphRouteDto {
  gtfsId: string;
  shortName?: string | null;
  longName?: string | null;
  mode: string;
  agencyName?: string | null;
  agencyGtfsId?: string | null;
}

// Stop básico (id + nome + coords)
export interface FlixbusStopBasicDto {
  gtfsId: string;
  name: string;
  lat?: number;
  lon?: number;
}

// Detalhe de linha + lista de stops
export interface FlixbusGraphRouteDetailDto extends FlixbusGraphRouteDto {
  stops: FlixbusStopBasicDto[];
}

// Resultado de pesquisa de stops
export interface FlixbusStopSearchResultDto {
  gtfsId: string;
  name: string;
  lat?: number;
  lon?: number;
}

// Partida bruta vinda do grafo (tipo CPDepartureDto)
export interface FlixbusDepartureDto {
  routeGtfsId?: string;
  routeShortName?: string | null;
  routeLongName?: string | null;
  mode: string;                    // BUS / COACH, etc.
  agencyName?: string | null;
  headsign?: string | null;
  scheduledDeparture: number;      // segundos desde serviceDay
  realtimeDeparture: number;       // idem, com atraso
  realtime: boolean;
  serviceDay: number;              // epoch (segundos, meia-noite local)
}

// Resposta bruta de partidas por stop
export interface FlixbusStopDeparturesDto {
  stopId: string;
  stopName: string;
  lat?: number;
  lon?: number;
  departures: FlixbusDepartureDto[];
}

// Linha da board formatada para UI
export interface FlixbusStopBoardRowDto {
  time: string;                     // "HH:MM"
  destination: string | null;       // headsign
  lineShortName?: string | null;
  lineLongName?: string | null;
  routeGtfsId?: string;
  delayMinutes: number;             // pode ser 0
  isRealtime: boolean;
}

// Board completo de uma paragem
export interface FlixbusStopBoardDto {
  stopId: string;
  stopName: string;
  lat?: number;
  lon?: number;
  departures: FlixbusStopBoardRowDto[];
}
