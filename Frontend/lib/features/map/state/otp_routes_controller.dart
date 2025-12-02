import 'package:flutter/material.dart';
import '../../../services/routes_service.dart';

class OtpRoutesController extends ChangeNotifier {
  OtpRoutesController(this._service);

  final RoutesService _service;

  bool isLoading = false;
  String? error;
  PlannedRoutesResult? _result;
  int? selectedIndex;

  List<OtpItinerary> get itineraries => _result?.itineraries ?? [];

  Future<void> fetch({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    RouteFilters? filters,
  }) async {
    try {
      print('[OtpRoutesController] fetch called: fromLat=$fromLat, fromLon=$fromLon, toLat=$toLat, toLon=$toLon');
      isLoading = true;
      error = null;
      notifyListeners();

      // First try: public transport (TRANSIT + WALK) if no filters specified
      RouteFilters? primaryFilters = filters;
      if (primaryFilters == null) {
        primaryFilters = const RouteFilters(
          modes: ['WALK', 'TRANSIT'],
        );
      }

      _result = await _service.plan(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: toLat,
        toLon: toLon,
        filters: primaryFilters,
      );
      
      print('[OtpRoutesController] Primary result: ${_result?.itineraries.length ?? 0} itineraries');
      
      // Fallback: if no public transport routes, try walk/bike/car
      if ((_result?.itineraries.isEmpty ?? true) && filters == null) {
        print('[OtpRoutesController] No public transport routes, trying fallback modes...');
        final fallbackFilters = const RouteFilters(
          modes: ['WALK', 'BICYCLE', 'CAR'],
        );
        
        try {
          final fallbackResult = await _service.plan(
            fromLat: fromLat,
            fromLon: fromLon,
            toLat: toLat,
            toLon: toLon,
            filters: fallbackFilters,
          );
          
          if (fallbackResult.itineraries.isNotEmpty) {
            print('[OtpRoutesController] Fallback result: ${fallbackResult.itineraries.length} itineraries');
            _result = fallbackResult;
          } else {
            print('[OtpRoutesController] Fallback also returned no routes');
          }
        } catch (e) {
          print('[OtpRoutesController] Fallback request failed: $e');
          // Keep the original (empty) result
        }
      }
      
      print('[OtpRoutesController] Final result: ${_result?.itineraries.length ?? 0} itineraries');
      selectedIndex = itineraries.isNotEmpty ? 0 : null;
      print('[OtpRoutesController] Selected index: $selectedIndex');
    } catch (e, stackTrace) {
      print('[OtpRoutesController] Error: $e');
      print('[OtpRoutesController] Stack: $stackTrace');
      error = e.toString();
      _result = null;
      selectedIndex = null;
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectItinerary(int index) {
    if (index < 0 || index >= itineraries.length) return;
    if (selectedIndex == index) return;
    selectedIndex = index;
    notifyListeners();
  }

  void clear() {
    _result = null;
    error = null;
    selectedIndex = null;
    notifyListeners();
  }
}

