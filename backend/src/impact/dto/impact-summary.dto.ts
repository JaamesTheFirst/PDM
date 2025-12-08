// src/impact/dto/impact-summary.dto.ts

/**
 * Bucket diário de impacto ecológico.
 *
 * Representa os totais agregados para um único dia (YYYY-MM-DD):
 *  - emissões
 *  - CO2 poupado
 *  - distância
 *  - número de viagens
 */
export class ImpactDayBucketDto {
  /** Data no formato 'YYYY-MM-DD' (por exemplo, '2025-12-03'). */
  date: string; // '2025-12-03'

  /** Emissões totais de CO2 nesse dia (kg). */
  totalCo2Kg: number;

  /** CO2 total poupado nesse dia comparado com cenário base (carro). */
  totalCo2SavedKg: number;

  /** Distância total percorrida nesse dia (km). */
  totalDistanceKm: number;

  /** Número de viagens nesse dia. */
  trips: number;
}

/**
 * Resumo de impacto para um período arbitrário.
 *
 * Pode representar:
 *  - última semana
 *  - últimos N dias
 *  - intervalo [from, to]
 *  - all-time
 *
 * Inclui totais, rácios de viagens "eco"/ativas e média de ecoScore.
 */
export class ImpactSummaryDto {
  /** Início do período em ISO string (UTC). */
  periodStart: string;

  /** Fim do período em ISO string (UTC). */
  periodEnd: string;

  /** Emissões totais de CO2 no período (kg). */
  totalCo2Kg: number;

  /** CO2 total poupado no período comparado com cenário base (carro). */
  totalCo2SavedKg: number;

  /** Distância total percorrida no período (km). */
  totalDistanceKm: number;

  /** Número total de viagens no período. */
  totalTrips: number;

  /** Número de viagens com emissões inferiores ao cenário base do carro. */
  ecoTrips: number;

  /**
   * Proporção de viagens "eco" no período (0–1).
   * Exemplo: 0.6 significa 60% das viagens foram mais sustentáveis que o carro.
   */
  ecoTripsRatio: number; // 0–1

  /** Número de viagens com atividade física (walk/bike/scooter). */
  activeTrips: number;

  /**
   * Proporção de viagens ativas no período (0–1).
   * Exemplo: 0.4 significa 40% das viagens tiveram componente ativa.
   */
  activeTripsRatio: number; // 0–1

  /**
   * Média do ecoScore (0–100) das viagens no período.
   * Calculado a partir do score individual de cada RouteHistory.
   */
  avgEcoScore: number;

  /** Lista de buckets diários com os mesmos campos agregados. */
  days: ImpactDayBucketDto[];
}
