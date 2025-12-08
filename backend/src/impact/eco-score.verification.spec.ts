// src/impact/eco-score.verification.spec.ts
//
// Verification tests for eco score calculations
// These tests verify that emission factors and calculations are correct

import { calculateEcoScoreFromLegs } from './eco-score.util';

describe('Eco Score Verification', () => {
  describe('Emission Factors Consistency', () => {
    it('should calculate zero CO2 for walking', () => {
      const result = calculateEcoScoreFromLegs([
        { mode: 'WALK', distanceMeters: 1000 },
      ]);

      expect(result.co2Kg).toBe(0);
      expect(result.co2PerKm).toBe(0);
      expect(result.score).toBe(100); // Zero emission + physical activity bonus
    });

    it('should calculate correct CO2 for bus route', () => {
      // 5km bus ride
      // Expected: (0.089 kg/km × 5 km) / 20 passengers = 0.02225 kg
      const result = calculateEcoScoreFromLegs([
        { mode: 'BUS', distanceMeters: 5000 },
      ]);

      const expectedCo2 = (0.089 * 5) / 20; // 0.02225 kg
      expect(result.co2Kg).toBeCloseTo(expectedCo2, 5);
      expect(result.co2PerKm).toBeCloseTo(expectedCo2 / 5, 5); // 0.00445 kg/km
    });

    it('should calculate correct CO2 for rail route', () => {
      // 10km rail ride
      // Expected: (0.014 kg/km × 10 km) / 150 passengers = 0.000933 kg
      const result = calculateEcoScoreFromLegs([
        { mode: 'RAIL', distanceMeters: 10000 },
      ]);

      const expectedCo2 = (0.014 * 10) / 150; // 0.000933 kg
      expect(result.co2Kg).toBeCloseTo(expectedCo2, 6);
      expect(result.co2PerKm).toBeCloseTo(expectedCo2 / 10, 6);
    });

    it('should calculate correct CO2 for IC train', () => {
      // 10km IC train ride
      // Expected: (0.014 kg/km × 10 km) / 120 passengers = 0.001167 kg
      // Note: IC uses occupancy 120, not 150
      const result = calculateEcoScoreFromLegs([
        { mode: 'IC', distanceMeters: 10000 },
      ]);

      const expectedCo2 = (0.014 * 10) / 120; // 0.001167 kg
      expect(result.co2Kg).toBeCloseTo(expectedCo2, 6);
      expect(result.co2PerKm).toBeCloseTo(expectedCo2 / 10, 6);
    });

    it('should calculate correct CO2 for mixed route', () => {
      // Walk 500m + Bus 3km + Rail 8km
      const result = calculateEcoScoreFromLegs([
        { mode: 'WALK', distanceMeters: 500 },
        { mode: 'BUS', distanceMeters: 3000 },
        { mode: 'RAIL', distanceMeters: 8000 },
      ]);

      const walkCo2 = 0;
      const busCo2 = (0.089 * 3) / 20; // 0.01335 kg
      const railCo2 = (0.014 * 8) / 150; // 0.000747 kg
      const expectedTotal = walkCo2 + busCo2 + railCo2; // 0.014097 kg

      expect(result.co2Kg).toBeCloseTo(expectedTotal, 6);
      expect(result.hasPhysicalActivity).toBe(true);
    });
  });

  describe('Score Calculation', () => {
    it('should give maximum score for zero-emission route', () => {
      const result = calculateEcoScoreFromLegs([
        { mode: 'WALK', distanceMeters: 1000 },
        { mode: 'BIKE', distanceMeters: 2000 },
      ]);

      expect(result.score).toBe(100);
      expect(result.hasPhysicalActivity).toBe(true);
    });

    it('should apply physical activity bonus', () => {
      // Route with low emissions + walking
      const result = calculateEcoScoreFromLegs([
        { mode: 'RAIL', distanceMeters: 10000 }, // Very low emissions
        { mode: 'WALK', distanceMeters: 500 },
      ]);

      // Should have physical activity bonus (+10)
      expect(result.hasPhysicalActivity).toBe(true);
      // Score should be high (low emissions) + bonus
      expect(result.score).toBeGreaterThan(90);
    });

    it('should penalize fossil buses', () => {
      // Route with fossil bus
      const result = calculateEcoScoreFromLegs([
        { mode: 'BUS', distanceMeters: 5000 },
      ]);

      // Fossil bus penalty should be applied (-18 points)
      // With 4.45 g/km, base score would be ~80, minus 18 = ~62
      expect(result.score).toBeLessThan(70);
    });
  });

  describe('IC Train Occupancy Fix', () => {
    it('should use occupancy 120 for IC trains (not 150)', () => {
      const icResult = calculateEcoScoreFromLegs([
        { mode: 'IC', distanceMeters: 10000 },
      ]);

      const railResult = calculateEcoScoreFromLegs([
        { mode: 'RAIL', distanceMeters: 10000 },
      ]);

      // IC should have slightly higher CO2 per passenger (lower occupancy)
      expect(icResult.co2Kg).toBeGreaterThan(railResult.co2Kg);

      // IC: (0.014 * 10) / 120 = 0.001167 kg
      // Rail: (0.014 * 10) / 150 = 0.000933 kg
      expect(icResult.co2Kg).toBeCloseTo(0.001167, 6);
      expect(railResult.co2Kg).toBeCloseTo(0.000933, 6);
    });
  });
});

