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
  }) async {
    try {
      print('[OtpRoutesController] fetch called: fromLat=$fromLat, fromLon=$fromLon, toLat=$toLat, toLon=$toLon');
      isLoading = true;
      error = null;
      notifyListeners();

      _result = await _service.plan(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: toLat,
        toLon: toLon,
      );
      print('[OtpRoutesController] Got result: ${_result?.itineraries.length ?? 0} itineraries');
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

