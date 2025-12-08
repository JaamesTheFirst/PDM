// src/carris/dto/carris.dto.ts

/**
 * Informação da agência Carris, tal como exposta pelo backend para o frontend.
 * Baseada nos dados de agência do grafo OTP/GTFS.
 */
export interface CarrisAgencyDto {
  /** Identificador interno da agência no OTP (ex.: `CARRIS`) */
  id: string;
  /** Nome legível da agência (ex.: "Carris") */
  name: string;
  /** URL oficial da agência */
  url?: string;
  /** Timezone usada pela agência (ex.: "Europe/Lisbon") */
  timezone?: string;
  /** Código de idioma (ex.: "pt") */
  lang?: string;
  /** Número de telefone de contacto */
  phone?: string;
}

/**
 * Representação simplificada de uma rota/linha Carris.
 * Normaliza o que vem do OTP para algo amigável ao frontend.
 */
export interface CarrisRouteDto {
  /** Identificador da rota no grafo OTP (ex.: "CARRIS:708") */
  id: string;
  /** Código curto da linha (ex.: "708") */
  shortName?: string | null;
  /** Nome longo/descritivo da linha */
  longName?: string | null;
  /** Modo de transporte (deverá ser sempre "BUS" para Carris) */
  mode?: string | null;
  /** Cor principal da linha em hex (ex.: "#FFFF00") */
  color?: string | null;
  /** Cor do texto em hex para contraste (ex.: "#000000") */
  textColor?: string | null;
  /** Agência a que a rota pertence (filtrada para Carris) */
  agency?: CarrisAgencyDto | null;
}

/**
 * Representação de uma paragem Carris.
 * É o "view model" para o frontend, baseado nos stops do OTP.
 */
export interface CarrisStopDto {
  /** Identificador da paragem no OTP (ex.: "CARRIS:stop:1234") */
  id: string;
  /** Código curto da paragem (ex.: "1234") */
  code?: string | null;
  /** Nome da paragem */
  name: string;
  /** Descrição adicional da paragem */
  desc?: string | null;
  /** Latitude da paragem */
  lat: number;
  /** Longitude da paragem */
  lon: number;
  /** Identificador de zona tarifária (quando disponível) */
  zoneId?: string | null;
  /** URL com mais informação sobre a paragem */
  url?: string | null;
  /** ID da estação-pai, quando a paragem faz parte de um hub */
  parentStation?: string | null;
}

/**
 * Informação de horário para uma paragem concreta (stoptime).
 * Usa o modelo da OTP:
 *  - `serviceDay` é o início do dia de serviço em epoch seconds
 *  - os tempos são segundos desde `serviceDay`
 */
export interface CarrisStopTimeDto {
  /** ID da paragem a que este horário se refere */
  stopId: string;
  /** Nome da paragem (para conveniência no frontend) */
  stopName: string;

  /** Epoch seconds correspondentes ao início do "service day" (local) */
  serviceDay: number;
  /** Hora de partida agendada (segundos desde `serviceDay`) */
  scheduledDeparture: number;
  /** Hora de partida em tempo real (segundos desde `serviceDay`) */
  realtimeDeparture: number;
  /** Atraso em segundos (realtime - scheduled) */
  departureDelay: number;

  /** Headsign (destino) visível na paragem, se existir */
  stopHeadsign?: string | null;
  /** Headsign da viagem/trip (pode coincidir com o stopHeadsign) */
  tripHeadsign?: string | null;

  /** ID da rota associada a esta partida */
  routeId?: string | null;
  /** ID da viagem/trip específica */
  tripId?: string | null;
  /** Direção da viagem, quando disponível (0/1 ou similar) */
  directionId?: string | null;
}

/**
 * DTO agregado para uma partida próxima:
 * combina paragem, rota e stoptime numa única estrutura.
 */
export interface CarrisUpcomingDepartureDto {
  /** Paragem onde a partida ocorre */
  stop: CarrisStopDto;
  /** Rota/linha desta partida (filtrada para Carris BUS) */
  route: CarrisRouteDto;
  /** Informação de horário (planeado vs realtime) */
  stopTime: CarrisStopTimeDto;
}
