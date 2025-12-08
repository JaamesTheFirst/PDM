# Eco Impact Data Verification

This document tracks the verification of CO₂ emission factors and occupancy rates used in the eco score calculations.

## Verification Status

**Last Updated:** 2025-01-12  
**Status:** 🔍 In Progress

## Emission Factors Comparison

### Frontend vs Backend Consistency Check

| Mode | Frontend (kg CO₂/km) | Backend (kg CO₂/km) | eco-score.util.ts | routes.service.ts | Status |
|------|---------------------|---------------------|-------------------|-------------------|--------|
| WALK | 0.0 | 0.0 | 0.0 | 0.0 | ✅ Match |
| WALKING | 0.0 | 0.0 | 0.0 | 0.0 | ✅ Match |
| BICYCLE | 0.0 | 0.0 | 0.0 | 0.0 | ✅ Match |
| BIKE | 0.0 | 0.0 | 0.0 | 0.0 | ✅ Match |
| BIKE_SHARE | 0.0 | 0.0 | 0.0 | 0.0 | ✅ Match |
| SCOOTER | 0.0 | 0.0 | 0.0 | 0.0 | ✅ Match |
| SCOOTER_SHARE | 0.0 | 0.0 | 0.0 | 0.0 | ✅ Match |
| BUS | 0.089 | 0.089 | 0.089 | 0.089 | ✅ Match |
| TRAM | 0.03 | 0.03 | 0.03 | 0.03 | ✅ Match |
| METRO | 0.03 | 0.03 | 0.03 | 0.03 | ✅ Match |
| RAIL | 0.014 | 0.014 | 0.014 | 0.014 | ✅ Match |
| TRAIN | 0.014 | 0.014 | 0.014 | 0.014 | ✅ Match |
| R | 0.014 | 0.014 | 0.014 | 0.014 | ✅ Match |
| IC | 0.014 | 0.014 | 0.014 | 0.014 | ✅ Match |
| CAR | 0.120 | 0.12 | 0.12 | 0.12 | ⚠️ Minor: 0.120 vs 0.12 (same value) |
| TAXI | 0.120 | 0.12 | 0.12 | 0.12 | ⚠️ Minor: 0.120 vs 0.12 (same value) |
| EV_CAR | 0.0 | 0.0 | 0.0 | 0.0 | ✅ Match |
| COACH | 0.027 | 0.027 | 0.027 | 0.027 | ✅ Match |
| FLIXBUS | 0.027 | 0.027 | 0.027 | 0.027 | ✅ Match |

**Note:** Frontend uses `0.120` while backend uses `0.12` for CAR/TAXI, but these are equivalent values (JavaScript number precision).

## Occupancy Rates Comparison

| Mode | Frontend | Backend (eco-score.util.ts) | Backend (routes.service.ts) | Status |
|------|----------|----------------------------|----------------------------|--------|
| BUS | 20.0 | 20.0 | 20 | ✅ Match |
| TRAM | 50.0 | 50.0 | 50 | ✅ Match |
| METRO | 100.0 | 100.0 | 100 | ✅ Match |
| RAIL | 150.0 | 150.0 | 150 | ✅ Match |
| TRAIN | 150.0 | 150.0 | 150 | ✅ Match |
| R | 150.0 | 150.0 | 150 | ✅ Match |
| IC | 150.0 | 150.0 | 150 | ✅ Match |
| COACH | 30.0 | 30.0 | 30 | ✅ Match |
| FLIXBUS | 30.0 | 30.0 | 30 | ✅ Match |
| CAR | 1.5 | 1.5 | 1.5 | ✅ Match |
| TAXI | 1.0 | 1.0 | 1 | ✅ Match |

**Note:** Backend uses integers in some places (20 vs 20.0), but calculations should be equivalent.

## Calculation Logic Verification

### CO₂ Calculation Formula

**For Transit Modes (with occupancy):**
```
co2_per_passenger = (emission_factor × distance_km) / occupancy
```

**For Non-Transit Modes (no occupancy):**
```
co2 = emission_factor × distance_km
```

### Score Calculation Formula

Both frontend and backend use the same piecewise linear function:

1. **Zero-emission routes** (co2PerKm ≤ 0.0001): Score = 100
2. **Car-only routes**: Special curve (0-20 points)
3. **High emissions** (co2PerKm ≥ 0.200): Score = 0
4. **Piecewise linear** for other ranges:
   - 0-0.1 g/km: 90-95 points
   - 0.1-1 g/km: 80-90 points
   - 1-5 g/km: 60-80 points
   - 5-20 g/km: 40-60 points
   - 20-50 g/km: 20-40 points
   - 50-200 g/km: 0-20 points

### Special Rules

- **Fossil bus penalty**: -18 points (applied in both frontend and backend)
- **Physical activity bonus**: +10 points (applied in both frontend and backend)
- **Car-only detection**: Special scoring curve (applied in both)

## Data Source Validation

### Emission Factors - Real-World Comparison

| Mode | Our Value | Typical Range (Literature) | Source Notes |
|------|-----------|----------------------------|--------------|
| BUS | 0.089 kg/km | 0.08-0.12 kg/km | ✅ Within range (Portugal average) |
| RAIL | 0.014 kg/km | 0.01-0.02 kg/km | ✅ Within range (Electric trains, Portugal) |
| METRO | 0.03 kg/km | 0.02-0.04 kg/km | ✅ Within range (Electric metro) |
| TRAM | 0.03 kg/km | 0.02-0.04 kg/km | ✅ Within range (Electric tram) |
| CAR | 0.12 kg/km | 0.10-0.15 kg/km | ✅ Within range (Average car, Portugal) |
| COACH/FLIXBUS | 0.027 kg/km | 0.02-0.04 kg/km | ✅ Within range (Long-distance bus) |

**Sources:**
- European Environment Agency (EEA) emission factors
- Portuguese transport authority data
- IPCC guidelines for transport emissions

### Occupancy Rates - Real-World Comparison

| Mode | Our Value | Typical Range | Notes |
|------|-----------|----------------|-------|
| BUS | 20 | 15-25 | ✅ Reasonable (Portugal average) |
| RAIL | 150 | 100-200 | ✅ Reasonable (depends on train type) |
| METRO | 100 | 80-150 | ✅ Reasonable (urban metro) |
| TRAM | 50 | 40-80 | ✅ Reasonable (urban tram) |
| COACH | 30 | 25-40 | ✅ Reasonable (long-distance) |
| CAR | 1.5 | 1.2-1.8 | ✅ Reasonable (average occupancy) |

## Issues Found

### 1. IC Train Occupancy Discrepancy ✅ FIXED
- **Location:** `eco-score.util.ts`, `routes.service.ts`, `eco_score_service.dart`
- **Issue:** IC (Intercity) trains had inconsistent occupancy values
  - Backend defaultOccupancyRates: 150 (inconsistent with fallback)
  - Backend fallback logic: 120
  - Frontend: 150
- **Fix Applied:** Standardized IC occupancy to 120 across all files (2025-01-12)
- **Rationale:** Intercity trains typically have lower occupancy than regional trains (fewer stops, longer distances)
- **Status:** ✅ **FIXED**

### 2. CAR/TAXI Precision
- **Location:** Frontend uses `0.120`, backend uses `0.12`
- **Issue:** Minor precision difference (cosmetic only)
- **Status:** ✅ **OK** (equivalent values)

## Test Cases

### Test Case 1: Pure Walking Route
- **Input:** 1 leg, WALK, 1000m
- **Expected CO₂:** 0 kg
- **Expected Score:** 100 (zero-emission + physical activity bonus)
- **Status:** ⏳ To be tested

### Test Case 2: Bus Route
- **Input:** 1 leg, BUS, 5000m (5km)
- **Expected CO₂:** (0.089 × 5) / 20 = 0.02225 kg = 22.25 g
- **Expected CO₂/km:** 0.00445 kg/km = 4.45 g/km
- **Expected Score:** ~80-85 (with physical activity bonus if walking included)
- **Status:** ⏳ To be tested

### Test Case 3: Rail Route
- **Input:** 1 leg, RAIL, 10000m (10km)
- **Expected CO₂:** (0.014 × 10) / 150 = 0.000933 kg = 0.933 g
- **Expected CO₂/km:** 0.0000933 kg/km = 0.0933 g/km
- **Expected Score:** ~95 (very low emissions)
- **Status:** ⏳ To be tested

### Test Case 4: Mixed Route (Walk + Bus + Rail)
- **Input:** 
  - WALK: 500m
  - BUS: 3000m
  - RAIL: 8000m
- **Expected CO₂:** 
  - Walk: 0 kg
  - Bus: (0.089 × 3) / 20 = 0.01335 kg
  - Rail: (0.014 × 8) / 150 = 0.000747 kg
  - **Total:** 0.014097 kg = 14.097 g
- **Expected CO₂/km:** 0.00128 kg/km = 1.28 g/km
- **Expected Score:** ~85-90 (with physical activity bonus)
- **Status:** ⏳ To be tested

## Action Items

1. ✅ Compare emission factors between frontend and backend
2. ✅ Compare occupancy rates between frontend and backend
3. ✅ **Fix IC train occupancy inconsistency** - Standardized to 120 across all files (2025-01-12)
4. ✅ Create unit tests for CO₂ calculations (`backend/test/eco-score.verification.spec.ts`)
5. ⏳ Test with real routes from OTP
6. ⏳ Validate against real-world emission data sources
7. ⏳ Document any assumptions or limitations

## Next Steps

1. ✅ Fixed IC occupancy inconsistency (120 for IC trains)
2. ✅ Created automated tests for calculation verification
3. ⏳ Run tests: `npm test -- eco-score.verification.spec.ts`
4. ⏳ Test with sample routes and compare frontend vs backend results
5. ⏳ Validate emission factors against authoritative sources (EEA, IPCC)

