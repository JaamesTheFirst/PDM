import 'package:flutter/material.dart';

import '../../../services/routes_service.dart';

class OtpRoutesController extends ChangeNotifier {
  OtpRoutesController(this._service);

  final RoutesService _service;

  bool isLoading = false;
  String? error;
  List<OtpItinerary> itineraries = [];

  Future<void> fetch({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) async {
    try {
      isLoading = true;
      error = null;
      notifyListeners();

      itineraries = await _service.plan(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: toLat,
        toLon: toLon,
      );
    } catch (e) {
      error = e.toString();
      itineraries = [];
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void clear() {
    itineraries = [];
    error = null;
    notifyListeners();
  }
}

