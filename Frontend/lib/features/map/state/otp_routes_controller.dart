import 'package:flutter/material.dart';
import '../../../services/routes_service.dart';

/// Controlador responsável por pedir itinerários ao backend/OTP
/// e expor o estado para a UI (lista de rotas, erros, seleção, etc.).
///
/// Funções principais:
/// - Chamar o serviço de rotas (`RoutesService.plan`) com coordenadas e filtros.
/// - Aplicar lógica de fallback quando não existem itinerários para os filtros
///   escolhidos (ex.: tentar mais modos, WALK-only, etc.).
/// - Gerir estado de loading/erro.
/// - Guardar o índice do itinerário selecionado.
///
/// Este controlador é tipicamente usado com `Provider`/`ChangeNotifierProvider`
/// para alimentar widgets como o overlay de opções de rota.
class OtpRoutesController extends ChangeNotifier {
  /// Cria uma instância do controlador de rotas OTP.
  ///
  /// [service] é o wrapper de acesso ao backend que expõe o método `plan`.
  OtpRoutesController(this._service);

  /// Serviço que encapsula as chamadas ao backend/OTP.
  final RoutesService _service;

  /// Indica se está a decorrer um pedido de planeamento de rota.
  bool isLoading = false;

  /// Mensagem de erro (caso o último pedido falhe), ou `null`.
  String? error;

  /// Resultado bruto devolvido pelo serviço de rotas (pode ser `null`).
  PlannedRoutesResult? _result;

  /// Índice do itinerário atualmente selecionado (ou `null` se nenhum).
  int? selectedIndex;

  /// Lista de itinerários planeados (ou lista vazia).
  ///
  /// É derivada de `_result?.itineraries`.
  List<OtpItinerary> get itineraries => _result?.itineraries ?? [];

  /// Faz o pedido de itinerários ao serviço de rotas, com fallback inteligente.
  ///
  /// Parâmetros:
  /// - [fromLat], [fromLon]: coordenadas da origem.
  /// - [toLat], [toLon]: coordenadas do destino.
  /// - [filters]: filtros de modos/distâncias (opcional).
  ///
  /// Fluxo:
  /// 1. Marca `isLoading = true` e limpa erro anterior.
  /// 2. Chama `_service.plan` com filtros primários (ou default WALK+TRANSIT).
  /// 3. Se não houver itinerários, aplica regras de fallback:
  ///    - Respeita o caso em que o utilizador quer explicitamente só modos
  ///      de transporte sem WALK (não faz fallback agressivo).
  ///    - Se WALK está incluído ou não havia filtros, tenta combinações extra
  ///      de modos (ex.: adicionar BICYCLE, CAR, TRANSIT).
  ///    - Em último caso, pode tentar WALK-only se fizer sentido.
  /// 4. Guarda o resultado final e define `selectedIndex` para 0 se houver
  ///    itinerários.
  /// 5. Em caso de erro, guarda `error` e limpa resultado/seleção.
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

      // Para pedidos apenas de WALK, deixa o OTP decidir a distância máxima
      // se o utilizador não especificar `maxWalkDistanceMeters`. Isto permite
      // percursos longos a pé (ex.: peregrinos).
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
        
        // Não fazer fallback agressivo se o utilizador escolheu explicitamente
        // apenas modos de transporte (sem WALK). Respeita a escolha.
        if (hasOnlyTransportModes) {
          print('[OtpRoutesController] User selected only transport modes (no WALK), respecting choice - no fallback');
        } 
        // Fallback se: user selecionou WALK, ou não tinha filtros (caso default)
        else if (hasWalkSelected || primaryFilters == null || userSelectedModes.isEmpty) {
          print('[OtpRoutesController] No routes found, trying fallback modes...');
          
          // Construir lista de modos para fallback
          final fallbackModes = <String>[];
          
          if (userSelectedModes.isNotEmpty) {
            // Utilizador escolheu modos - preserva e adiciona alternativas
            fallbackModes.addAll(userSelectedModes);
            
            // Se WALK foi selecionado, tenta adicionar outros modos
            if (hasWalkSelected) {
              if (!fallbackModes.contains('BICYCLE')) fallbackModes.add('BICYCLE');
              if (!fallbackModes.contains('CAR')) fallbackModes.add('CAR');
              if (!fallbackModes.contains('TRANSIT')) fallbackModes.add('TRANSIT');
            }
          } else {
            // Sem seleção explícita (default) - tentar todos os modos principais
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
              // Se o utilizador selecionou WALK mas ainda assim não há rotas,
              // tentar WALK-only (ou WALK com constraint explícita).
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

  /// Marca o itinerário com índice [index] como selecionado, se existir.
  ///
  /// Não notifica se o índice já estiver selecionado, para evitar rebuilds
  /// desnecessários.
  void selectItinerary(int index) {
    if (index < 0 || index >= itineraries.length) return;
    if (selectedIndex == index) return;
    selectedIndex = index;
    notifyListeners();
  }

  /// Limpa o estado do controlador (resultado, erros, seleção).
  ///
  /// Útil quando o utilizador muda de origem/destino ou fecha o fluxo de rotas.
  void clear() {
    _result = null;
    error = null;
    selectedIndex = null;
    notifyListeners();
  }
}
