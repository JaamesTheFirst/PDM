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

      // For walking-only requests, ensure maxWalkDistanceMeters is only applied if explicitly set
      // This allows long walking routes when user doesn't set a constraint
      if (primaryFilters.modes != null && 
          primaryFilters.modes!.length == 1 && 
          primaryFilters.modes!.contains('WALK') &&
          primaryFilters.maxWalkDistanceMeters == null) {
        // User selected WALK only with no distance constraint - allow unlimited walking
        print('[OtpRoutesController] WALK-only selected with no maxWalkDistanceMeters - allowing unlimited distance');
      }

      _result = await _service.plan(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: toLat,
        toLon: toLon,
        filters: primaryFilters,
      );
      
      print('[OtpRoutesController] Primary result: ${_result?.itineraries.length ?? 0} itineraries');
      
      // Fallback logic: only fallback if appropriate
      // Rules:
      // 1. If user selected ONLY transport modes (no WALK) and no routes found, don't fallback (user's choice)
      // 2. If user selected WALK (with or without constraints), try fallback if no routes
      // 3. If no filters specified (default), always try fallback
      if ((_result?.itineraries.isEmpty ?? true)) {
        final userSelectedModes = primaryFilters?.modes ?? [];
        final hasWalkSelected = userSelectedModes.contains('WALK');
        final hasOnlyTransportModes = userSelectedModes.isNotEmpty && 
                                      !hasWalkSelected && 
                                      userSelectedModes.every((m) => ['TRANSIT', 'CAR', 'BICYCLE'].contains(m));
        
        // Don't fallback if user explicitly selected only transport modes (no WALK)
        // This respects their choice to exclude walking
        if (hasOnlyTransportModes) {
          print('[OtpRoutesController] User selected only transport modes (no WALK), respecting choice - no fallback');
        } 
        // Fallback if: user selected WALK, or no filters specified (default case)
        else if (hasWalkSelected || primaryFilters == null || userSelectedModes.isEmpty) {
          print('[OtpRoutesController] No routes found, trying fallback modes...');
          
          // Build fallback modes
          final fallbackModes = <String>[];
          
          if (userSelectedModes.isNotEmpty) {
            // User selected modes - preserve them and add alternatives
            fallbackModes.addAll(userSelectedModes);
            
            // If WALK is selected, try adding other modes for more options
            if (hasWalkSelected) {
              if (!fallbackModes.contains('BICYCLE')) fallbackModes.add('BICYCLE');
              if (!fallbackModes.contains('CAR')) fallbackModes.add('CAR');
              if (!fallbackModes.contains('TRANSIT')) fallbackModes.add('TRANSIT');
            }
          } else {
            // No user selection (default) - try all modes
            fallbackModes.addAll(['WALK', 'BICYCLE', 'CAR', 'TRANSIT']);
          }
          
          final fallbackFilters = RouteFilters(
            modes: fallbackModes,
            maxWalkDistanceMeters: primaryFilters?.maxWalkDistanceMeters, // Preserve user's walk distance constraint
          );
          
          try {
            print('[OtpRoutesController] Trying fallback with modes: ${fallbackModes.join(", ")}');
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
            } else if (hasWalkSelected) {
              // If user selected WALK but still no routes, try WALK only (maybe other modes are causing issues)
              // If user selected WALK only and didn't set max_walk_distance, don't apply any constraint
              // This allows long walking routes (e.g., for pilgrims)
              final isWalkOnly = userSelectedModes.length == 1 && userSelectedModes.contains('WALK');
              final shouldApplyWalkConstraint = primaryFilters?.maxWalkDistanceMeters != null;
              
              print('[OtpRoutesController] Fallback returned no routes, trying WALK only...');
              print('[OtpRoutesController] isWalkOnly=$isWalkOnly, shouldApplyWalkConstraint=$shouldApplyWalkConstraint');
              
              final walkOnlyFilters = RouteFilters(
                modes: ['WALK'],
                maxWalkDistanceMeters: shouldApplyWalkConstraint 
                    ? primaryFilters?.maxWalkDistanceMeters 
                    : null, // Only apply constraint if user explicitly set it
              );
              
              try {
                final walkOnlyResult = await _service.plan(
                  fromLat: fromLat,
                  fromLon: fromLon,
                  toLat: toLat,
                  toLon: toLon,
                  filters: walkOnlyFilters,
                );
                
                if (walkOnlyResult.itineraries.isNotEmpty) {
                  print('[OtpRoutesController] WALK-only result: ${walkOnlyResult.itineraries.length} itineraries');
                  _result = walkOnlyResult;
                } else {
                  print('[OtpRoutesController] WALK-only also returned no routes (likely due to maxWalkDistanceMeters constraint)');
                }
              } catch (e) {
                print('[OtpRoutesController] WALK-only request failed: $e');
              }
            } else {
              print('[OtpRoutesController] Fallback returned no routes and WALK was not selected');
            }
          } catch (e) {
            print('[OtpRoutesController] Fallback request failed: $e');
          }
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

