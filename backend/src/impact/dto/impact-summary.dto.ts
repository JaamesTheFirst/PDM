export class ImpactDayBucketDto {
  date: string; // '2025-12-03'
  totalCo2Kg: number;
  totalCo2SavedKg: number;
  totalDistanceKm: number;
  trips: number;
}

export class ImpactSummaryDto {
  periodStart: string;
  periodEnd: string;

  totalCo2Kg: number;
  totalCo2SavedKg: number;
  totalDistanceKm: number;
  totalTrips: number;

  ecoTrips: number;
  ecoTripsRatio: number; // 0–1

  activeTrips: number;
  activeTripsRatio: number; // 0–1

  /// 🔥 média de ecoScore (0–100) das viagens do período
  avgEcoScore: number;

  days: ImpactDayBucketDto[];
}
