// src/cp/dto/cp-vehicle.dto.ts

/**
 * Representa um veículo CP em tempo real,
 * tal como devolvido pela API pública comboios.live.
 */
export interface CpVehicleDto {
  /** Número do comboio (trainNumber) */
  trainNumber: number;
  /** Data de circulação (YYYY-MM-DD ou formato similar) */
  runDate: string;
  /** Atraso atual em minutos (ou null se desconhecido) */
  delay: number | null;
  /** Última estação registada no feed de realtime */
  lastStation: string | null;
  /** Latitude atual do comboio como string (ou null) */
  latitude: string | null;
  /** Longitude atual do comboio como string (ou null) */
  longitude: string | null;
  /** Estado textual (ex.: "IN_SERVICE", "CANCELLED") */
  status: string;
  /** Indica se há perturbações associadas a este comboio */
  hasDisruptions: boolean;

  /** Informação sobre o serviço (tipo de comboio) */
  service: {
    /** Código interno do serviço (ex.: "ALFA", "IR") */
    code: string;
    /** Designação legível do serviço */
    designation: string;
  };

  /** Origem da viagem */
  origin: {
    /** Código interno da origem */
    code: string;
    /** Nome/designação da origem */
    designation: string;
  };

  /** Destino da viagem */
  destination: {
    /** Código interno do destino */
    code: string;
    /** Nome/designação do destino */
    designation: string;
  };
}

/**
 * Envelope de resposta da API comboios.live para o endpoint de veículos.
 */
export interface CpVehiclesApiResponse {
  /** Lista de veículos CP em circulação ou planeados */
  vehicles: CpVehicleDto[];
}
