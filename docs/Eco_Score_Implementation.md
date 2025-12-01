# Eco Score Implementation

## Overview

The Eco Score feature provides a carbon footprint-based score (0-100) for each route option, helping users compare the environmental impact of different transportation choices. The score is calculated based on CO₂ emissions per kilometer, with bonuses for physical activity modes.

## Implementation Summary

### 1. EcoScoreService (`Frontend/lib/services/eco_score_service.dart`)

A service that calculates CO₂ emissions and Eco Scores for OTP itineraries.

**Key Features:**
- Calculates CO₂ emissions per itinerary leg based on transport mode and distance
- Uses emission factors per transport mode (with defaults for Portugal/Europe)
- Applies occupancy rates for transit modes (bus, train, metro, etc.)
- Calculates a 0-100 score (lower CO₂ = higher score)
- Adds +10 bonus points for physical activity (walking, cycling, scooter)
- Provides formatting and color utilities for display

**Key Methods:**
- `calculateScore(OtpItinerary itinerary)`: Main calculation method
- `formatCo2(double co2Kg)`: Formats CO₂ for display (g or kg)
- `getScoreColor(int score)`: Returns color code based on score range

### 2. Route Display Integration (`route_options_overlay.dart`)

The Eco Score is displayed in each route option card with:
- **Eco Score badge** with color coding:
  - **80-100**: Green (eco mint `#3CD4A0`)
  - **60-79**: Green (`#4CAF50`)
  - **40-59**: Amber (`#FFC107`)
  - **0-39**: Red/orange (`#FF5722`)
- **CO₂ emissions** displayed (formatted as g or kg)
- **Physical activity icon** (fitness center icon) when applicable
- Integrated seamlessly into existing route cards

## Feedback on Original Suggestions

### ✅ Emission Factors Per Mode
**Suggestion:** Calculate scores based on type of vehicle and carbon footprint.

**Implementation:** Implemented with default emission factors for each transport mode. The system uses Portugal/Europe-specific values:
- Walking/Cycling: 0.0 kg CO₂/km
- Electric transit (metro, tram, rail): 0.014-0.03 kg CO₂/km
- Bus: 0.089 kg CO₂/km
- Car/Taxi: 0.120 kg CO₂/km

### ✅ Occupancy Rates
**Suggestion:** Use occupancy rate calculation like `cf_of_train * 1/occupancy`.

**Implementation:** Implemented using average occupancy rates:
- **Bus**: 20 passengers
- **Tram**: 50 passengers
- **Metro**: 100 passengers
- **Rail/Train**: 150 passengers
- **Car**: 1.5 passengers
- **Taxi**: 1.0 passenger

**Note:** The formula used is `co2_per_passenger = (emission_factor × distance_km) / occupancy`, which is mathematically equivalent to `cf_of_train / occupancy` (not `* 1/occupancy`).

**Limitation:** Real-time occupancy data is not available from OTP, so we use average occupancy rates. This is a reasonable assumption for comparative scoring.

### ✅ Physical Activity Boost
**Suggestion:** Implement boosts related to physical activity.

**Implementation:** Added +10 bonus points for routes that include walking, cycling, bike share, scooter, or scooter share modes. This encourages users to choose more active transportation options.

## How It Works

### Step 1: CO₂ Calculation Per Leg

For each leg in an itinerary:

1. **Get emission factor** for the transport mode
2. **Calculate CO₂**:
   - **For transit modes** (bus, train, metro, etc.):
     ```
     co2_per_passenger = (emission_factor × distance_km) / occupancy_rate
     ```
   - **For non-transit modes** (walking, bike, car, etc.):
     ```
     co2 = emission_factor × distance_km
     ```
3. **Sum total CO₂** across all legs

### Step 2: Score Calculation

1. **Calculate CO₂ per kilometer**:
   ```
   co2PerKm = totalCo2Kg / totalDistanceKm
   ```

2. **Base score formula**:
   ```
   if co2PerKm <= 0:
     baseScore = 100.0  // Zero emissions (walking, cycling)
   else if co2PerKm >= maxCo2PerKm (0.200):
     baseScore = 0.0  // Very high emissions
   else:
     baseScore = 100.0 × (1.0 - (co2PerKm / maxCo2PerKm))
   ```

3. **Physical activity bonus**:
   ```
   if hasPhysicalActivity:
     finalScore = min(100.0, baseScore + 10.0)
   else:
     finalScore = baseScore
   ```

4. **Round to integer** (0-100)

### Step 3: Display

The score is displayed in route cards with:
- Color-coded badge showing the score
- CO₂ emissions in grams or kilograms
- Physical activity icon (fitness center) when applicable
- All integrated into the existing route option UI

## Default Emission Factors

| Mode | Emission Factor (kg CO₂/km) | Notes |
|------|----------------------------|-------|
| WALK / WALKING | 0.0 | Zero emissions |
| BICYCLE / BIKE / BIKE_SHARE | 0.0 | Zero emissions |
| SCOOTER / SCOOTER_SHARE | 0.0 | Zero emissions (assuming electric) |
| BUS | 0.089 | Average bus in Portugal |
| TRAM | 0.03 | Electric tram |
| METRO | 0.03 | Electric metro |
| RAIL / TRAIN | 0.014 | Electric train (Portugal's trains are mostly electric) |
| COACH | 0.027 | Long-distance bus |
| CAR | 0.120 | Average car |
| TAXI | 0.120 | Average car |
| EV_CAR | 0.0 | Electric car (assuming renewable energy) |

## Default Occupancy Rates

| Mode | Occupancy (passengers) | Notes |
|------|----------------------|-------|
| BUS | 20.0 | Average bus occupancy |
| TRAM | 50.0 | Average tram occupancy |
| METRO | 100.0 | Average metro occupancy |
| RAIL / TRAIN | 150.0 | Average train occupancy |
| COACH | 30.0 | Long-distance bus |
| CAR | 1.5 | Average car occupancy |
| TAXI | 1.0 | Single passenger |

## Score Color Coding

| Score Range | Color | Hex Code | Meaning |
|-------------|-------|----------|---------|
| 80-100 | Eco Mint | `#3CD4A0` | Excellent - Very eco-friendly |
| 60-79 | Green | `#4CAF50` | Good - Eco-friendly |
| 40-59 | Amber | `#FFC107` | Moderate - Some environmental impact |
| 0-39 | Red/Orange | `#FF5722` | Poor - High environmental impact |

## Future Enhancements

1. **Backend Integration**: Connect to `EmissionFactor` database table for dynamic emission factors
2. **Real-time Occupancy**: Integrate with transit APIs for real-time occupancy data
3. **Regional Factors**: Use region-specific emission factors (e.g., different values for different countries)
4. **Energy Source**: Consider energy source for electric vehicles (renewable vs. grid mix)
5. **Time-based Factors**: Adjust factors based on time of day (peak vs. off-peak occupancy)
6. **User Preferences**: Allow users to customize emission factors or scoring weights

## Technical Notes

- The service uses default emission factors when backend data is unavailable
- Occupancy rates are averages and may not reflect real-time conditions
- Physical activity bonus encourages active transportation
- Score calculation is linear between 0 and max CO₂ per km
- All calculations are done client-side for immediate feedback

## Files Modified

1. `Frontend/lib/services/eco_score_service.dart` - New service for Eco Score calculation
2. `Frontend/lib/features/map/widgets/route_options_overlay.dart` - Updated to display Eco Score in route cards

