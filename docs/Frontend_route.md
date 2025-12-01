# Frontend Routing & Navigation Guide (Flutter + Mapbox)

This document defines how the **frontend routing system** must work, including planning, selecting, rendering, and navigating multimodal routes using **Flutter** and **Mapbox**, integrated with the backend `/routes` module (OTP-based).

Its purpose is to enable **any developer or AI** to fully understand and continue the implementation without ambiguity.

---

# 1. Overview

The routing module is responsible for providing a complete, Google‑Maps‑style navigation experience:

1. User selects **origin** and **destination**.
2. Frontend requests `/routes/plan` from backend.
3. Backend returns one or more **itineraries**, each composed of multiple **legs**.
4. User chooses one itinerary.
5. App displays:

   * The full route polyline on Mapbox.
   * User's GPS position.
   * A structured "Path" panel with all steps.
6. As the user moves, the app detects:

   * Progress inside each leg.
   * Arrival at intermediate stops.
   * Arrival at final destination.

---

# 2. Data Contract with Backend

## 2.1 Request

The frontend must send:

```json
{
  "from": { "lat": 0.0, "lon": 0.0, "name": "optional" },
  "to":   { "lat": 0.0, "lon": 0.0, "name": "optional" },
  "preferences": {
    "maxWalkingDistanceMeters": 1500,
    "modes": ["WALK", "BUS", "RAIL", "METRO"],
    "ecoFriendlyOnly": false
  }
}
```

## 2.2 Expected Response

The backend returns itineraries:

```json
{
  "itineraries": [
    {
      "id": "uuid-example",
      "durationSeconds": 1800,
      "distanceMeters": 5500,
      "co2Kg": 0.75,
      "legs": [
        {
          "mode": "WALK",
          "start": { "lat": 0.0, "lon": 0.0, "name": "Origin" },
          "end":   { "lat": 0.0, "lon": 0.0, "name": "Stop A" },
          "distanceMeters": 400,
          "durationSeconds": 300,
          "geometry": { "points": "ENCODED_POLYLINE" },
          "steps": [
            {
              "streetName": "Rua X",
              "distanceMeters": 120,
              "relativeDirection": "RIGHT"
            }
          ]
        }
      ]
    }
  ]
}
```

### Required guarantees for frontend

* Each `leg.geometry.points` contains a valid **encoded polyline**.
* `start` and `end` define meaningful place names.
* `steps` may exist on WALK legs (optional).

---

# 3. Route Planning Flow (RoutePlannerPage)

The Route Planner screen must provide:

### 3.1 Origin & Destination Selection

* Tap or long‑press on Mapbox to set **Origin**.
* Tap or long‑press to set **Destination**.
* Or choose via search field.
* Display markers for the two points.

### 3.2 Planning Request

When user taps **Plan Route**:

1. Validate both points exist.
2. Call backend `/routes/plan`.
3. On success: store itineraries & navigate to `RouteOptionsPage`.

---

# 4. RouteOptionsPage – Selecting an Itinerary

Displays cards for each itinerary:

Each card must show:

* Total duration (minutes)
* Distance (km)
* Transport modes (icons)
* Optional: CO₂ estimate

Example visual layout:

```
[icons]   32 min • 5.5 km
          WALK + BUS
          0.75 kg CO₂
```

On selection:

1. Save the selected itinerary in memory/state.
2. Optionally call `/routes/history` to register the plan.
3. Open `RouteNavigationPage`.

---

# 5. Route Navigation Page (RouteNavigationPage)

This is the central screen of the navigation experience.
It must:

* Display the **full route polyline** on Mapbox.
* Show origin/destination markers.
* Show markers for **intermediate legs** (e.g., bus stops, train stations).
* Track user location in real time.
* Display a **bottom sheet** with step-by-step instructions.
* Detect arrival at each leg's endpoint.
* Detect arrival at final destination.

## 5.1 Polyline Rendering

Procedure:

1. For each leg:

   * Decode polyline → `List<LatLng>`.
2. Optionally merge all decoded lists into `routePoints`.
3. Draw route using Mapbox line layer.
4. Fit camera to bounds of entire path.

## 5.2 Path Panel (Bottom Sheet)

List all legs in order:

Example:

```
1. Walk to Bus Stop A (5 min – 400 m)
2. Bus 758 to Station B (20 min – 4 km)
3. Walk to Destination (10 min – 1.1 km)
```

Highlight the **current leg**.

If available, WALK legs may include sub‑steps.

---

# 6. Live Navigation (GPS Tracking)

## 6.1 Requirements

* Use a continuous GPS location stream.
* On every new location:

  * Update user marker.
  * Run progress logic.

## 6.2 Navigation State Structure

```dart
class RouteNavigationState {
  final Itinerary itinerary;
  final int currentLegIndex;
  final bool isCompleted;
  final LatLng? userPosition;
}
```

## 6.3 Leg Progression Logic

Pseudocode:

```dart
void onUserLocationUpdated(LatLng userPos) {
  if (state.isCompleted) return;

  final legs = state.itinerary.legs;
  final currentLeg = legs[state.currentLegIndex];

  final LatLng legEnd = LatLng(
    currentLeg.end.lat,
    currentLeg.end.lon,
  );

  final distanceToEnd = distanceInMeters(userPos, legEnd);

  if (distanceToEnd <= 30) {
    final nextLeg = state.currentLegIndex + 1;

    if (nextLeg >= legs.length) {
      emit(state.copyWith(isCompleted: true));
      onRouteCompleted();
    } else {
      emit(state.copyWith(currentLegIndex: nextLeg));
    }
  } else {
    emit(state.copyWith(userPosition: userPos));
  }
}
```

## 6.4 Visual Behavior

* When a leg is completed:

  * Highlight the next step.
  * Optionally shift camera.
* When final destination is reached:

  * Show a completion dialog.
  * Optionally update route history status.

---

# 7. Waypoints (Optional but Supported)

The system supports optional **intermediate places** (waypoints):

* The frontend may include an array `waypoints[]` when planning.
* OTP will split the itinerary into additional legs.
* The existing progress logic handles this automatically.
* Map should show markers for each waypoint.

---

# 8. History & Eco Integration

Although not part of direct navigation:

* When itinerary is selected, frontend may call `/routes/history` to record it.
* On completion, frontend may update route to `COMPLETED`.
* Eco statistics (CO₂ saved) are retrieved from `/eco/summary`.

---

# 9. Implementation Checklist

## Must Implement

* [ ] Origin selection
* [ ] Destination selection
* [ ] Backend call: `/routes/plan`
* [ ] List of itineraries
* [ ] Navigation page
* [ ] Polyline decoding & rendering
* [ ] Leg markers
* [ ] User position tracking (GPS)
* [ ] Leg progression logic
* [ ] Destination completion logic
* [ ] Bottom sheet with legs/steps

## Optional (Recommended)

* [ ] Turn-by-turn WALK instructions
* [ ] Reroute if user strays off-path
* [ ] Waypoint support
* [ ] CO₂ display in itineraries
* [ ] Heuristic camera auto-follow

---

# 10. Summary for Any Developer/AI Reading This

A developer following this document must:

1. **Plan a route** by calling `/routes/plan`.
2. **Display options** to the user.
3. **Render the chosen route** on Mapbox using decoded polylines.
4. **Track the user** in real time and compare their position to leg endpoints.
5. **Advance steps automatically** when user reaches end of leg.
6. **Finish navigation** when last leg ends.
7. Use the backend for **history** and **eco tracking**.

This defines the complete behaviour of the frontend Routing System for the MVP.
