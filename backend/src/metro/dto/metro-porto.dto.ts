// src/metro/dto/metro-porto.dto.ts

export interface MetroPortoAgencyDto {
  id: string;
  name: string;
  url?: string;
  timezone?: string;
  lang?: string;
  phone?: string;
}

export interface MetroPortoRouteDto {
  id: string;
  shortName?: string;
  longName?: string;
  mode?: string;
  color?: string;
  textColor?: string;
  agency?: MetroPortoAgencyDto;
}

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

export interface MetroPortoStopTimeDto {
  stopId: string;
  stopName: string;
  serviceDay: number;
  scheduledDeparture: number;
  realtimeDeparture: number;
  departureDelay: number;
  stopHeadsign?: string;
  tripHeadsign?: string;
  routeId?: string;
  tripId?: string;
  directionId?: string;
}

export interface MetroPortoUpcomingDepartureDto {
  stop: MetroPortoStopDto;
  route: MetroPortoRouteDto;
  stopTime: MetroPortoStopTimeDto;
}
