// src/cp/dto/cp-graph.dto.ts

export interface CpGraphRouteDto {
  gtfsId: string;
  shortName?: string | null;
  longName?: string | null;
  mode: string;
  agencyName?: string | null;
  agencyGtfsId?: string | null;
}

export interface CpStopBasicDto {
  gtfsId: string;
  name: string;
  lat?: number;
  lon?: number;
}

export interface CpGraphRouteDetailDto extends CpGraphRouteDto {
  stops: CpStopBasicDto[];
}

export interface CpStopSearchResultDto {
  gtfsId: string;
  name: string;
  lat?: number;
  lon?: number;
}

export interface CpDepartureDto {
  routeGtfsId?: string;
  routeShortName?: string | null;
  routeLongName?: string | null;
  mode: string;
  agencyName?: string | null;
  headsign?: string | null;
  scheduledDeparture: number;   // segundos desde serviceDay
  realtimeDeparture: number;    // idem, com atraso
  realtime: boolean;
  serviceDay: number;           // epoch (segundos, meia-noite local)
}

export interface CpStopDeparturesDto {
  stopId: string;
  stopName: string;
  lat?: number;
  lon?: number;
  departures: CpDepartureDto[];
}

export interface CpStopBoardRowDto {
  time: string;                // "HH:MM"
  destination: string | null;  // headsign
  lineShortName?: string | null;
  lineLongName?: string | null;
  routeGtfsId?: string;
  delayMinutes: number;        // pode ser 0
  isRealtime: boolean;
}

export interface CpStopBoardDto {
  stopId: string;
  stopName: string;
  lat?: number;
  lon?: number;
  departures: CpStopBoardRowDto[];
}
