// src/impact/eco-score.util.ts

export interface EcoScoreResultBackend {
  co2Kg: number;
  co2PerKm: number;
  score: number; // 0-100
  hasPhysicalActivity: boolean;
  primaryMode?: string | null;
}

// Default emission factors (kg CO2 per km)
const defaultEmissionFactors: Record<string, number> = {
  WALK: 0.0,
  WALKING: 0.0,
  BICYCLE: 0.0,
  BIKE: 0.0,
  BIKE_SHARE: 0.0,
  SCOOTER: 0.0,
  SCOOTER_SHARE: 0.0,
  BUS: 0.089,
  TRAM: 0.03,
  METRO: 0.03,
  RAIL: 0.014,
  TRAIN: 0.014,
  R: 0.014,
  IC: 0.014,
  CAR: 0.12,
  TAXI: 0.12,
  EV_CAR: 0.0,
  COACH: 0.027,
  FLIXBUS: 0.027,
};

// Default occupancy (passengers per vehicle)
const defaultOccupancyRates: Record<string, number> = {
  BUS: 20.0,
  TRAM: 50.0,
  METRO: 100.0,
  RAIL: 150.0,
  TRAIN: 150.0,
  R: 150.0,
  IC: 150.0,
  COACH: 30.0,
  FLIXBUS: 30.0,
  CAR: 1.5,
  TAXI: 1.0,
};

const BASELINE_CO2_PER_KM = 0.12;
const MAX_CO2_PER_KM = 0.2;

export interface EcoScoreLegInput {
  mode: string;
  distanceMeters: number;
}

/**
 * Lógica de EcoScore equivalente à do Flutter,
 * mas recebendo só (mode, distanceMeters) por perna.
 */
export function calculateEcoScoreFromLegs(
  legs: EcoScoreLegInput[],
): EcoScoreResultBackend {
  let totalCo2Kg = 0;
  let totalDistanceKm = 0;
  let hasPhysicalActivity = false;
  let primaryMode: string | null = null;

  for (const leg of legs) {
    const mode = (leg.mode || '').toUpperCase();
    const distanceKm = (leg.distanceMeters ?? 0) / 1000;
    totalDistanceKm += distanceKm;

    let emissionFactor = defaultEmissionFactors[mode] ?? 0;

    if (emissionFactor === 0 && mode !== 'WALK' && mode !== 'WALKING') {
      if (
        mode.includes('RAIL') ||
        mode.includes('TRAIN') ||
        mode === 'R' ||
        mode === 'IC'
      ) {
        emissionFactor = defaultEmissionFactors['RAIL'] ?? 0.014;
      } else if (mode.includes('BUS') || mode === 'COACH') {
        emissionFactor = defaultEmissionFactors['BUS'] ?? 0.089;
      } else if (mode.includes('METRO') || mode.includes('SUBWAY')) {
        emissionFactor = defaultEmissionFactors['METRO'] ?? 0.03;
      } else if (mode.includes('TRAM')) {
        emissionFactor = defaultEmissionFactors['TRAM'] ?? 0.03;
      }
    }

    let occupancy = defaultOccupancyRates[mode];

    if (occupancy == null && mode !== 'WALK' && mode !== 'WALKING') {
      if (
        mode.includes('RAIL') ||
        mode.includes('TRAIN') ||
        mode === 'R' ||
        mode === 'IC'
      ) {
        occupancy = mode === 'IC' ? 120 : 150;
      } else if (mode.includes('BUS') || mode === 'COACH') {
        occupancy = mode === 'FLIXBUS' || mode === 'COACH' ? 30 : 20;
      } else if (mode.includes('METRO') || mode.includes('SUBWAY')) {
        occupancy = 100;
      } else if (mode.includes('TRAM')) {
        occupancy = 50;
      }
    }

    let legCo2Kg: number;
    if (occupancy != null && occupancy > 0) {
      legCo2Kg = (emissionFactor * distanceKm) / occupancy;
    } else {
      legCo2Kg = emissionFactor * distanceKm;
    }

    totalCo2Kg += legCo2Kg;

    if (
      mode === 'WALK' ||
      mode === 'WALKING' ||
      mode === 'BICYCLE' ||
      mode === 'BIKE' ||
      mode === 'BIKE_SHARE' ||
      mode === 'SCOOTER' ||
      mode === 'SCOOTER_SHARE'
    ) {
      hasPhysicalActivity = true;
    }

    if (primaryMode == null && mode !== 'WALK' && mode !== 'WALKING') {
      primaryMode = mode;
    }
  }

  if (primaryMode == null) {
    primaryMode = 'WALKING';
  }

  const co2PerKm =
    totalDistanceKm > 0 ? totalCo2Kg / totalDistanceKm : 0;

  // check zero-emission
  let isOnlyZeroEmission = true;
  for (const leg of legs) {
    const mode = (leg.mode || '').toUpperCase();
    let emissionFactor = defaultEmissionFactors[mode] ?? 0;

    if (emissionFactor === 0 && mode !== 'WALK' && mode !== 'WALKING') {
      if (
        mode.includes('RAIL') ||
        mode.includes('TRAIN') ||
        mode === 'R' ||
        mode === 'IC'
      ) {
        emissionFactor = defaultEmissionFactors['RAIL'] ?? 0.014;
      } else if (mode.includes('BUS') || mode === 'COACH') {
        emissionFactor = defaultEmissionFactors['BUS'] ?? 0.089;
      } else if (mode.includes('METRO') || mode.includes('SUBWAY')) {
        emissionFactor = defaultEmissionFactors['METRO'] ?? 0.03;
      } else if (mode.includes('TRAM')) {
        emissionFactor = defaultEmissionFactors['TRAM'] ?? 0.03;
      } else if (mode === 'CAR' || mode === 'TAXI') {
        emissionFactor = defaultEmissionFactors['CAR'] ?? 0.12;
      }
    }

    if (emissionFactor > 0) {
      isOnlyZeroEmission = false;
      break;
    }
  }

  // car-only?
  let isCarOnly = true;
  for (const leg of legs) {
    const mode = (leg.mode || '').toUpperCase();
    if (
      mode !== 'WALK' &&
      mode !== 'WALKING' &&
      mode !== 'CAR' &&
      !mode.includes('CAR')
    ) {
      isCarOnly = false;
      break;
    }
  }
  if (
    !legs.some((l) => {
      const m = (l.mode || '').toUpperCase();
      return m === 'CAR' || m.includes('CAR');
    })
  ) {
    isCarOnly = false;
  }

  // fossil buses?
  let hasFossilBus = false;
  for (const leg of legs) {
    const mode = (leg.mode || '').toUpperCase();
    if (
      mode.includes('BUS') &&
      !mode.includes('ELECTRIC') &&
      !mode.includes('HYBRID')
    ) {
      hasFossilBus = true;
      break;
    }
  }

  // score
  let baseScore = 0;

  if (isOnlyZeroEmission && co2PerKm <= 0.0001) {
    baseScore = 100;
  } else if (isCarOnly) {
    const co2PerKmGram = co2PerKm * 1000;
    if (co2PerKmGram >= 120) {
      baseScore = 0;
    } else if (co2PerKmGram >= 80) {
      baseScore =
        20 - ((co2PerKmGram - 80) / 40) * 20;
    } else {
      baseScore = 20;
    }
  } else if (co2PerKm >= MAX_CO2_PER_KM) {
    baseScore = 0;
  } else {
    const co2PerKmGram = co2PerKm * 1000;

    if (co2PerKmGram <= 0.1) {
      baseScore = 95 - (co2PerKmGram / 0.1) * 5;
    } else if (co2PerKmGram <= 1) {
      baseScore =
        90 - ((co2PerKmGram - 0.1) / 0.9) * 10;
    } else if (co2PerKmGram <= 5) {
      baseScore =
        80 - ((co2PerKmGram - 1) / 4) * 20;
    } else if (co2PerKmGram <= 20) {
      baseScore =
        60 - ((co2PerKmGram - 5) / 15) * 20;
    } else if (co2PerKmGram <= 50) {
      baseScore =
        40 - ((co2PerKmGram - 20) / 30) * 20;
    } else {
      baseScore =
        20 - ((co2PerKmGram - 50) / 150) * 20;
    }

    if (hasFossilBus) {
      baseScore = Math.max(0, baseScore - 18);
    }
  }

  if (hasPhysicalActivity && baseScore < 100) {
    baseScore = Math.min(100, baseScore + 10);
  }

  return {
    co2Kg: totalCo2Kg,
    co2PerKm,
    score: Math.round(baseScore),
    hasPhysicalActivity,
    primaryMode,
  };
}

/**
 * Versão “agregada” para um período inteiro:
 * recebe totalCo2Kg, totalDistanceKm, se há viagens ativas e se é zero-emissão.
 * Usa a mesma escala de score mas sem car-only / fossil bus (não temos legs).
 */
export function calculateEcoScoreForPeriod(params: {
  totalCo2Kg: number;
  totalDistanceKm: number;
  hasAnyActiveTrip: boolean;
  isOnlyZeroEmission: boolean;
}): number {
  const { totalCo2Kg, totalDistanceKm, hasAnyActiveTrip, isOnlyZeroEmission } =
    params;

  if (totalDistanceKm <= 0) {
    return 0;
  }

  const co2PerKm = totalCo2Kg / totalDistanceKm;

  let baseScore = 0;

  if (isOnlyZeroEmission && co2PerKm <= 0.0001) {
    baseScore = 100;
  } else if (co2PerKm >= MAX_CO2_PER_KM) {
    baseScore = 0;
  } else {
    const ratio = co2PerKm / MAX_CO2_PER_KM;
    baseScore = 100 * (1 - ratio);
  }

  if (hasAnyActiveTrip && baseScore < 100) {
    baseScore = Math.min(100, baseScore + 10);
  }

  return Math.round(baseScore);
}
