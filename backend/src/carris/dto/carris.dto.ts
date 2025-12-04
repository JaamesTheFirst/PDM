// src/carris/dto/carris.dto.ts

export interface CarrisAgencyDto {
  id: string;
  name: string;
  url?: string;
  timezone?: string;
  lang?: string;
  phone?: string;
}

export interface CarrisRouteDto {
  id: string;
  shortName?: string | null;
  longName?: string | null;
  mode?: string | null;
  color?: string | null;
  textColor?: string | null;
  agency?: CarrisAgencyDto | null;
}

export interface CarrisStopDto {
  id: string;
  code?: string | null;
  name: string;
  desc?: string | null;
  lat: number;
  lon: number;
  zoneId?: string | null;
  url?: string | null;
  parentStation?: string | null;
}

export interface CarrisStopTimeDto {
  stopId: string;
  stopName: string;

  serviceDay: number;          // epoch seconds (start of service day)
  scheduledDeparture: number;  // seconds since serviceDay
  realtimeDeparture: number;   // seconds since serviceDay
  departureDelay: number;      // seconds (realtime - scheduled)

  stopHeadsign?: string | null;
  tripHeadsign?: string | null;

  routeId?: string | null;
  tripId?: string | null;
  directionId?: string | null;
}

export interface CarrisUpcomingDepartureDto {
  stop: CarrisStopDto;
  route: CarrisRouteDto;
  stopTime: CarrisStopTimeDto;
}
