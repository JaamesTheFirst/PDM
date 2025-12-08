// src/impact/eco-score.util.ts
//
// Utilitários de cálculo de EcoScore no backend.
//
// A ideia é manter a lógica o mais próxima possível do que existe
// no frontend (Flutter), para que o score apresentado ao utilizador
// seja consistente em todas as plataformas.

/**
 * Resultado completo do cálculo de EcoScore no backend.
 */
export interface EcoScoreResultBackend {
  /** Emissões totais de CO2 da viagem (kg). */
  co2Kg: number;
  /** Emissões por km (kg/km). */
  co2PerKm: number;
  /** Score final de sustentabilidade (0–100). */
  score: number; // 0-100
  /** Indica se houve atividade física (walk/bike/scooter). */
  hasPhysicalActivity: boolean;
  /** Modo principal inferido da viagem (caso exista). */
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

/**
 * Input simplificado de uma perna/leg da viagem para o cálculo do ecoScore.
 */
export interface EcoScoreLegInput {
  /** Modo da perna (ex: "BUS", "RAIL", "WALK"). */
  mode: string;
  /** Distância da perna em metros. */
  distanceMeters: number;
}

/**
 * Lógica de EcoScore equivalente à do Flutter,
 * mas recebendo só (mode, distanceMeters) por perna.
 *
 * Faz:
 *  - normalização de modos
 *  - cálculo de CO2 com fatores + ocupação
 *  - deteção de atividade física
 *  - heurísticas para viagens zero-emissão e car-only
 *  - mapeamento final para score 0–100
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

    // 1) fator de emissão base
    let emissionFactor = defaultEmissionFactors[mode] ?? 0;

    // fallback: tentar deduzir categoria pelo nome do modo
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

    // 2) taxa de ocupação (passageiros/veículo)
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

    // 3) CO2 por perna: ou por veículo, ou por passageiro usando ocupação
    let legCo2Kg: number;
    if (occupancy != null && occupancy > 0) {
      legCo2Kg = (emissionFactor * distanceKm) / occupancy;
    } else {
      legCo2Kg = emissionFactor * distanceKm;
    }

    totalCo2Kg += legCo2Kg;

    // detetar atividade física
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

    // modo principal = primeiro modo não-walk encontrado
    if (primaryMode == null && mode !== 'WALK' && mode !== 'WALKING') {
      primaryMode = mode;
    }
  }

  if (primaryMode == null) {
    primaryMode = 'WALKING';
  }

  const co2PerKm =
    totalDistanceKm > 0 ? totalCo2Kg / totalDistanceKm : 0;

  // ------------- detetar viagem zero-emissão -------------
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

  // ------------- detetar “car-only” -------------
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

  // ------------- detetar autocarros a combustíveis fósseis -------------
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

  // ------------- mapeamento para score 0–100 -------------
  let baseScore = 0;

  if (isOnlyZeroEmission && co2PerKm <= 0.0001) {
    // viagens 100% zero-emissão recebem score máximo
    baseScore = 100;
  } else if (isCarOnly) {
    // curva específica para viagens apenas de carro
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

    // penalização se usar autocarros fósseis
    if (hasFossilBus) {
      baseScore = Math.max(0, baseScore - 18);
    }
  }

  // bónus por atividade física
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
 * Versão agregada para um período inteiro.
 *
 * Em vez de receber legs individuais, trabalha só com:
 *  - emissões totais
 *  - distância total
 *  - flag de viagem ativa
 *  - flag se é apenas zero-emissão
 *
 * Usa a mesma escala, mas sem heurísticas de car-only / fossil bus,
 * porque não temos detalhe por leg.
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

  // pequeno bónus se houve pelo menos uma viagem ativa no período
  if (hasAnyActiveTrip && baseScore < 100) {
    baseScore = Math.min(100, baseScore + 10);
  }

  return Math.round(baseScore);
}
