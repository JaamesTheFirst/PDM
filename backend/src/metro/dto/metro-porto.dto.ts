// src/metro/dto/metro-porto.dto.ts
//
// DTOs usados para expor dados do Metro do Porto,
// consumidos a partir do grafo OTP (GraphQL).

/**
 * Metadados da agência do Metro do Porto devolvidos pelo OTP.
 */
export interface MetroPortoAgencyDto {
  id: string;
  name: string;
  url?: string;
  timezone?: string;
  lang?: string;
  phone?: string;
}

/**
 * Linha do Metro do Porto vinda do OTP.
 */
export interface MetroPortoRouteDto {
  id: string;
  shortName?: string;
  longName?: string;
  mode?: string;
  color?: string;
  textColor?: string;
  agency?: MetroPortoAgencyDto;
}

/**
 * Paragem/estação do Metro do Porto vinda do OTP.
 */
export interface MetroPortoStopDto {
  id: string;
  code?: string;
  name: string;
  desc?: string;
  lat: number;
  lon: number;
  zoneId?: string;
  url?: string;
  parentStation?: string;
}

/**
 * Informação de uma partida em determinada paragem
 * (stoptime) tal como calculado pelo OTP.
 */
export interface MetroPortoStopTimeDto {
  stopId: string;
  stopName: string;

  /** Epoch (segundos) do início do serviceDay. */
  serviceDay: number;

  /** Hora prevista de partida (segundos desde serviceDay). */
  scheduledDeparture: number;

  /** Hora real de partida (segundos desde serviceDay). */
  realtimeDeparture: number;

  /** Atraso em segundos (realtime - scheduled). */
  departureDelay: number;

  stopHeadsign?: string;
  tripHeadsign?: string;

  routeId?: string;
  tripId?: string;
  directionId?: string;
}

/**
 * Estrutura consolidada para uma partida próxima:
 * junta paragem, linha e stoptime.
 */
export interface MetroPortoUpcomingDepartureDto {
  stop: MetroPortoStopDto;
  route: MetroPortoRouteDto;
  stopTime: MetroPortoStopTimeDto;
}
