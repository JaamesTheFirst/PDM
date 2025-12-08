import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mbx;

import '../../../../services/mapbox_geocoding_service.dart';
import '../../../../services/mapbox_directions_service.dart';
import '../../../../services/mapbox_searchbox_service.dart';
import '../../../../services/search_history_service.dart';
import '../../../../services/routes_service.dart';
import './route_options_overlay.dart'; // RouteOptionsArgs

/// Overlay de pesquisa de rotas sobre o mapa.
///
/// Responsabilidades principais:
/// - Gerir os campos "De" e "Para" (origem/destino) com autocomplete.
/// - Mostrar sugestões próximas (nearby) e resultados de pesquisa Mapbox Searchbox.
/// - Desenhar pré-visualização de rota (linha no mapa) e marcador de destino.
/// - Permitir configuração de filtros de rota (modos de transporte, tipos de transit, distância máxima a pé).
/// - Ao confirmar, devolve via [onConfirmOptions] os argumentos necessários
///   para abrir o overlay de opções de rota (`RouteOptionsOverlay`).
class RouteSearchOverlay extends StatefulWidget {
  /// Instância de [MapboxMap] usada para desenhar anotações e ajustar a câmara.
  final mbx.MapboxMap mapboxMap;

  /// Localização atual do utilizador, em coordenadas Mapbox.
  ///
  /// Usada como contexto de proximidade para:
  /// - Sugestões por perto (nearby).
  /// - Pesquisa (proximity / origin).
  /// - Origem padrão da rota (quando "De" é a localização atual).
  final mbx.Point userLocation;

  /// Callback para fechar o overlay (ex.: fechar bottom sheet).
  final VoidCallback onClose;

  /// Callback que devolve os argumentos necessários para abrir o overlay
  /// de opções de rota (`RouteOptionsOverlay`).
  ///
  /// Contém:
  /// - [RouteOptionsArgs.mapboxMap]: o mapa atual
  /// - [RouteOptionsArgs.from]: origem selecionada (ou localização atual)
  /// - [RouteOptionsArgs.to]: destino selecionado
  /// - [RouteOptionsArgs.filters]: filtros ativos
  final ValueChanged<RouteOptionsArgs> onConfirmOptions;

  const RouteSearchOverlay({
    super.key,
    required this.mapboxMap,
    required this.userLocation,
    required this.onClose,
    required this.onConfirmOptions,
  });

  @override
  State<RouteSearchOverlay> createState() => _RouteSearchOverlayState();
}

/// Campo atualmente ativo (em edição) no formulário.
///
/// Usado para decidir:
/// - Que sugestões carregar (baseado em origem ou destino).
/// - Que campo deve ser atualizado ao escolher uma sugestão.
enum _ActiveField { from, to }

/// Estado interno do [RouteSearchOverlay].
///
/// Mantém:
/// - Controladores e focus nodes dos campos "De"/"Para".
/// - Estado das sugestões (searchbox, nearby).
/// - Filtros de rota ativos.
/// - Anotações do mapa (círculo de destino, linha da rota).
/// - Pré-visualização de distância e duração do preview da rota.
class _RouteSearchOverlayState extends State<RouteSearchOverlay> {
  // Controladores e focus dos campos de texto
  final TextEditingController _fromController = TextEditingController();
  final TextEditingController _toController = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();

  /// Campo atualmente selecionado para edição.
  _ActiveField _active = _ActiveField.to;

  /// Cores de design
  static const _ecoMint = Color(0xFF3CD4A0);
  static const _offWhiteSand = Color(0xFFF8F7F4);
  static const _destRed = Color(0xFFE53935);

  /// Token de sessão para Mapbox Searchbox (permite agrupar requests).
  String _sessionToken = 's_${DateTime.now().millisecondsSinceEpoch}';

  /// Lista de sugestões devolvidas pelo Searchbox (modo "search").
  final List<SearchboxSuggestion> _sbSuggestions = [];

  /// Cache de detalhes de lugares (por mapboxId), enriquecidos com distância.
  final Map<String, SearchboxPlace> _sbCache = {};

  /// Lista de POIs/lugares próximos (modo "nearby").
  final List<SearchboxPlace> _nearby = [];

  /// Lugar de destino selecionado (campo "Para").
  SearchboxPlace? _selectedTo;

  /// Lugar de origem selecionado (caso o utilizador mude a partir da localização atual).
  SearchboxPlace? _selectedFrom;

  /// Indica se está a decorrer uma pesquisa (autocomplete) no Searchbox.
  bool _isSearching = false;

  /// Indica se estamos a carregar sugestões "nearby".
  bool _isLoadingNearby = false;

  /// Mensagem informativa quando não há resultados ou há erros.
  String? _emptyMsg;

  /// Timer de debounce para evitar chamadas excessivas à API enquanto o
  /// utilizador escreve.
  Timer? _debounce;

  /// Geração atual de pedidos "nearby" (para evitar race conditions).
  ///
  /// Cada novo load incrementa o contador; respostas antigas são ignoradas
  /// se o valor não coincidir.
  int _nearbyGen = 0;

  /// Filtros de rota ativos (modos, transitTypes, maxWalkDistance).
  RouteFilters? _activeFilters;

  /// Gerente de anotações de círculos (para o marcador de destino).
  mbx.CircleAnnotationManager? _circleMgr;

  /// Gerente de anotações de polylines (para a pré-visualização da rota).
  mbx.PolylineAnnotationManager? _lineMgr;

  /// Anotação do círculo do destino atual (se existir).
  mbx.CircleAnnotation? _destCircle;

  /// Anotação da polyline da rota atual (se existir).
  mbx.PolylineAnnotation? _routeLine;

  /// Distância da pré-visualização da rota (metros).
  double? _distance;

  /// Duração da pré-visualização da rota (segundos).
  double? _duration;

  /// Perfil de modo da rota preview (usado no Mapbox Directions).
  ///
  /// - 'walking', 'cycling', etc.
  /// - Caso seja 'scooter', adaptamos para 'cycling' no pedido.
  String _mode = 'walking';

  /// Indica se o campo "De" representa a localização atual.
  bool _fromIsCurrent = true;

  /// Regex para detetar códigos postais isolados (sem mais contexto),
  /// que tendem a ser maus nomes de exibição.
  final RegExp _zipOnly = RegExp(r'^\d{4}-\d{3}$', caseSensitive: false);

  /// Determina se um nome é “mau” para exibição (vazio ou apenas código postal).
  bool _badName(String s) => s.trim().isEmpty || _zipOnly.hasMatch(s.trim());

  /// Verifica se uma posição está dentro de bounding box aproximada de Portugal.
  ///
  /// Ajuda a definir o `countryIso2` para a pesquisa (PT ou global).
  bool _isInPortugalBounds(mbx.Position p) {
    const minLon = -32.0, maxLon = -6.0, minLat = 31.5, maxLat = 42.6;
    final lon = p.lng.toDouble(), lat = p.lat.toDouble();
    return lon >= minLon && lon <= maxLon && lat >= minLat && lat <= maxLat;
  }

  /// Devolve 'pt' se a posição estiver dentro de Portugal, caso contrário `null`.
  String? _countryIsoFor(mbx.Position p) =>
      _isInPortugalBounds(p) ? 'pt' : null;

  /// Formata o campo "Para" a partir de um [SearchboxPlace] para algo mais
  /// legível, removendo:
  /// - Códigos postais que vêm isolados.
  /// - Prefixos como "Distrito de".
  /// - Repetições de "Portugal".
  ///
  /// Preferimos:
  /// - Nome do POI/rua
  /// - Cidade / localidade
  /// - País (quando ± útil)
  String _formatToField(SearchboxPlace p) {
    final name = p.name.trim();
    final zipAtStart = RegExp(r'^\d{4}-\d{3}\s*', caseSensitive: false);

    String _cleanSeg(String s) {
      var x = s.trim();
      if (_zipOnly.hasMatch(x)) return '';
      x = x.replaceFirst(zipAtStart, '').trim();
      if (x.toLowerCase().startsWith('distrito de ')) return '';
      return x;
    }

    final parts = p.placeName
        .split(',')
        .map(_cleanSeg)
        .where((s) => s.isNotEmpty)
        .toList();

    String? city;
    for (final seg in parts) {
      final low = seg.toLowerCase();
      if (low == 'portugal') continue;
      if (!RegExp(r'\d').hasMatch(seg)) {
        city = seg;
        break;
      }
    }

    final hasPortugal = parts.any((s) => s.toLowerCase() == 'portugal');
    final country = hasPortugal ? 'Portugal' : null;

    final pieces = <String>[];
    if (name.isNotEmpty) pieces.add(name);
    if (city != null &&
        city.isNotEmpty &&
        city.toLowerCase() != name.toLowerCase()) {
      pieces.add(city);
    } else if (city == null || city.isEmpty) {
      final firstAlt = parts.firstWhere(
        (s) =>
            s.toLowerCase() != 'portugal' &&
            s.toLowerCase() != name.toLowerCase(),
        orElse: () => '',
      );
      if (firstAlt.isNotEmpty) pieces.add(firstAlt);
    }
    if (country != null) pieces.add(country);

    return pieces.isNotEmpty
        ? pieces.join(', ')
        : (name.isNotEmpty ? name : p.placeName);
  }

  @override
  void initState() {
    super.initState();
    _resetSession();

    // Validação inicial da posição do utilizador para debug
    final p = widget.userLocation.coordinates;
    print(
      '[RouteSearchOverlay] Initializing with userLocation: lat=${p.lat}, lng=${p.lng}',
    );

    if (p.lat == 0.0 && p.lng == 0.0) {
      print(
        '[RouteSearchOverlay] WARNING: userLocation appears to be invalid (0,0)',
      );
    }

    // Preenche o campo "De" com localização atual (reverse geocoding)
    _initFromAddress();

    _fromFocus.addListener(_onFocusChange);
    _toFocus.addListener(_onFocusChange);
    _active = _ActiveField.to;

    // Debug do contexto de Searchbox (proximidade/GPS)
    MapboxSearchBoxService.instance.debugCheck(
      lon: p.lng.toDouble(),
      lat: p.lat.toDouble(),
    );

    // Carrega sugestões "nearby" iniciais para o campo ativo
    _loadNearbyForActive();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _fromController.dispose();
    _toController.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _circleMgr?.deleteAll().catchError((_) {});
    _lineMgr?.deleteAll().catchError((_) {});
    _circleMgr = null;
    _lineMgr = null;
    super.dispose();
  }

  /// Gera um novo token de sessão para Mapbox Searchbox.
  ///
  /// Idealmente chamado sempre que se muda o campo ativo (De/Para).
  void _resetSession() {
    _sessionToken = 's_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Handler para mudanças de foco entre campos "De" e "Para".
  ///
  /// Atualiza:
  /// - `_active` (campo ativo).
  /// - Limpa sugestões/estado de erro.
  /// - Reinicia token de sessão.
  /// - Carrega sugestões "nearby" adequadas ao campo ativo.
  void _onFocusChange() {
    final newActive = _fromFocus.hasFocus
        ? _ActiveField.from
        : (_toFocus.hasFocus ? _ActiveField.to : _active);
    if (newActive != _active) {
      setState(() {
        _active = newActive;
        _sbSuggestions.clear();
        _sbCache.clear();
        _emptyMsg = null;
      });
      _resetSession();
      _loadNearbyForActive();
    }
  }

  /// Inicializa o campo "De" com a morada da localização atual (reverse geocoding).
  ///
  /// Em caso de erro, preenche com o texto "Localização atual".
  Future<void> _initFromAddress() async {
    try {
      final pos = widget.userLocation.coordinates;
      print(
        '[RouteSearchOverlay] Initializing from address. Location: lat=${pos.lat}, lng=${pos.lng}',
      );

      final place = await MapboxGeocodingService.instance.reverseGeocode(
        pos.lng.toDouble(),
        pos.lat.toDouble(),
      );
      if (!mounted) return;
      setState(() {
        _fromController.text = place?.placeName.isNotEmpty == true
            ? place!.placeName
            : 'Localização atual';
        _fromIsCurrent = true;
        _selectedFrom = null;
      });
    } catch (e) {
      print('[RouteSearchOverlay] Error initializing from address: $e');
      if (!mounted) return;
      setState(() {
        _fromController.text = 'Localização atual';
        _fromIsCurrent = true;
        _selectedFrom = null;
      });
    }
  }

  /// Carrega sugestões "nearby" (POIs/ruas por perto) para o campo ativo.
  ///
  /// A posição base depende:
  /// - Se o campo ativo é "De" e não estamos na localização atual, usa a origem selecionada.
  /// - Caso contrário, usa a localização atual do utilizador.
  Future<void> _loadNearbyForActive() async {
    final myGen = ++_nearbyGen;
    setState(() {
      _isLoadingNearby = true;
      _nearby.clear();
      _emptyMsg = null;
    });

    try {
      final base =
          _active == _ActiveField.from &&
              !_fromIsCurrent &&
              _selectedFrom != null
          ? mbx.Position(_selectedFrom!.longitude, _selectedFrom!.latitude)
          : widget.userLocation.coordinates;

      print(
        '[RouteSearchOverlay] Loading nearby places. Base location: lat=${base.lat}, lng=${base.lng}',
      );

      final iso = _countryIsoFor(base);

      final sb = await MapboxSearchBoxService.instance.nearbyMixedWithFallback(
        lon: base.lng.toDouble(),
        lat: base.lat.toDouble(),
        sessionToken: _sessionToken,
        countryIso2: iso,
        total: 12,
      );

      print('[RouteSearchOverlay] Found ${sb.length} nearby places');

      if (!mounted || myGen != _nearbyGen) return;
      setState(() {
        _nearby.addAll(sb);
        if (_nearby.isEmpty) {
          _emptyMsg = 'Não encontrei POIs/ruas por perto 😕';
        }
      });
    } catch (e) {
      print('[RouteSearchOverlay] Error loading nearby places: $e');
      if (!mounted || myGen != _nearbyGen) return;
      setState(
        () => _emptyMsg = 'Não foi possível carregar sugestões perto de ti.',
      );
    } finally {
      if (!mounted || myGen != _nearbyGen) return;
      setState(() => _isLoadingNearby = false);
    }
  }

  /// Handler genérico de `onChanged` para o campo atualmente ativo (De/Para).
  ///
  /// Implementa:
  /// - Debounce de 250ms antes de chamar a API.
  /// - Limpeza de sugestões se o texto for demasiado curto (< 2 chars).
  /// - Contexto de pesquisa (proximity/origin + país).
  /// - Gestão de estado de loading e mensagens de erro/vazio.
  void _onChangedActive(String value) {
    _debounce?.cancel();
    setState(() => _emptyMsg = null);

    if (value.trim().length < 2) {
      setState(() {
        _sbSuggestions.clear();
        _sbCache.clear();
      });
      return;
    }

    final ctx = _effectiveContextForSearch();
    final oLon = ctx.lng.toDouble(), oLat = ctx.lat.toDouble();
    final iso = _countryIsoFor(ctx);

    print(
      '[RouteSearchOverlay] Searching for "$value" with GPS context: lat=$oLat, lng=$oLon, country=$iso',
    );

    _debounce = Timer(const Duration(milliseconds: 250), () async {
      setState(() {
        _isSearching = true;
        _sbSuggestions.clear();
      });

      try {
        final results = await MapboxSearchBoxService.instance.suggest(
          value,
          sessionToken: _sessionToken,
          proximityLon: oLon,
          proximityLat: oLat,
          originLon: oLon,
          originLat: oLat,
          limit: 10,
          countryIso2: iso,
          types: const ['poi', 'address', 'street', 'place'],
        );

        print('[RouteSearchOverlay] Search returned ${results.length} results');

        if (!mounted) return;

        if (results.isEmpty) {
          setState(() {
            _isSearching = false;
            _emptyMsg = 'Sem resultados por perto para "$value".';
          });
          return;
        }

        setState(() {
          _isSearching = false;
          _sbSuggestions.addAll(results);
        });

        _enrichDistances(results, oLon, oLat);
      } catch (e) {
        print('[RouteSearchOverlay] Error during search: $e');
        if (!mounted) return;
        setState(() {
          _isSearching = false;
          _emptyMsg = 'Erro ao pesquisar. Tenta novamente.';
        });
      }
    });
  }

  /// Enriquecer sugestões [results] com detalhes e distância ao contexto (oLat/oLon).
  ///
  /// Faz um `retrieveManyParallel` e:
  /// - Corrige nomes "maus" (apenas ZIP) com o nome da sugestão.
  /// - Calcula distância haversine entre contexto e cada lugar.
  /// - Preenche o cache [_sbCache] com [SearchboxPlace] completos.
  Future<void> _enrichDistances(
    List<SearchboxSuggestion> results,
    double oLon,
    double oLat,
  ) async {
    final byId = <String, SearchboxSuggestion>{
      for (final s in results) s.mapboxId: s,
    };

    final ids = results.map((s) => s.mapboxId).toList();
    final retrieved = await MapboxSearchBoxService.instance
        .retrieveManyParallel(
          mapboxIds: ids,
          sessionToken: _sessionToken,
          language: 'pt',
        );
    if (!mounted) return;
    setState(() {
      for (final e in retrieved.entries) {
        final r = e.value;
        final sug = byId[e.key];
        final fixedName = _badName(r.name) ? (sug?.name ?? r.name) : r.name;

        _sbCache[e.key] = SearchboxPlace(
          id: r.id,
          name: fixedName,
          placeName: r.placeName,
          longitude: r.longitude,
          latitude: r.latitude,
          featureType: r.featureType,
          category: r.category,
          distanceMeters: MapboxSearchBoxService.haversineMeters(
            oLat,
            oLon,
            r.latitude,
            r.longitude,
          ),
        );
      }
    });
  }

  /// Devolve a posição base a usar como contexto de pesquisa (proximity/origin).
  ///
  /// Regras:
  /// - Campo "De": se está na localização atual ou não há origem selecionada,
  ///   usa a localização atual; caso contrário, usa a origem escolhida.
  /// - Campo "Para": usa sempre a localização atual do utilizador.
  mbx.Position _effectiveContextForSearch() {
    if (_active == _ActiveField.from) {
      if (_fromIsCurrent || _selectedFrom == null) {
        final p = widget.userLocation.coordinates;
        return mbx.Position(p.lng, p.lat);
      }
      return mbx.Position(_selectedFrom!.longitude, _selectedFrom!.latitude);
    } else {
      final p = widget.userLocation.coordinates;
      return mbx.Position(p.lng, p.lat);
    }
  }

  /// Aplica uma sugestão [SearchboxSuggestion] ao campo ativo.
  ///
  /// Se ainda não tivermos detalhes em cache, faz um `retrieve` primeiro.
  Future<void> _applySuggestion(SearchboxSuggestion s) async {
    var p = _sbCache[s.mapboxId];
    if (p == null) {
      final r = await MapboxSearchBoxService.instance.retrieve(
        mapboxId: s.mapboxId,
        sessionToken: _sessionToken,
        language: 'pt',
      );
      if (r == null) return;

      final fixedName = _badName(r.name) ? s.name : r.name;
      p = SearchboxPlace(
        id: r.id,
        name: fixedName,
        placeName: r.placeName,
        longitude: r.longitude,
        latitude: r.latitude,
        featureType: r.featureType,
        category: r.category,
        distanceMeters: r.distanceMeters,
      );
    }
    await _applySelection(p);
  }

  /// Aplica a seleção de um [SearchboxPlace] ao campo ativo (De/Para).
  ///
  /// Efeitos:
  /// - Atualiza controllers e flags (`_fromIsCurrent`, `_selectedFrom`, `_selectedTo`).
  /// - Limpa sugestões ativas.
  /// - Para o destino:
  ///   - Regista no histórico de pesquisa.
  ///   - Atualiza mapa com destino/preview da rota via [_setDestination].
  Future<void> _applySelection(SearchboxPlace place) async {
    _fromFocus.unfocus();
    _toFocus.unfocus();

    if (_active == _ActiveField.from) {
      setState(() {
        _fromController.text =
            place.name.isNotEmpty ? place.name : place.placeName;
        _fromIsCurrent = false;
        _selectedFrom = place;
        _sbSuggestions.clear();
      });
    } else {
      setState(() {
        _toController.text = _formatToField(place);
        _sbSuggestions.clear();
      });
      // Guardar em histórico quando o destino é selecionado
      await SearchHistoryService.instance.addDestination(
        address: place.placeName,
        name: place.name.isNotEmpty ? place.name : place.placeName,
        latitude: place.latitude,
        longitude: place.longitude,
      );
      await _setDestination(place);
    }
  }

  /// Atualiza o destino no mapa e carrega a pré-visualização da rota.
  ///
  /// Passos:
  /// 1. Guarda [_selectedTo] e desenha marcador de destino (círculo vermelho).
  /// 2. Determina origem efetiva ([fromPos]).
  /// 3. Chama Mapbox Directions para obter rota preliminar.
  /// 4. Desenha polyline com cor eco (_ecoMint).
  /// 5. Atualiza [_distance] e [_duration] para preview textual.
  /// 6. Ajusta a câmara ([_fitFromTo]) para enquadrar origem e destino.
  Future<void> _setDestination(SearchboxPlace place) async {
    if (!mounted) return;

    _selectedTo = place;
    final destPoint = mbx.Point(
      coordinates: mbx.Position(place.longitude, place.latitude),
    );

    // Gestor de círculos
    _circleMgr ??= await widget.mapboxMap.annotations
        .createCircleAnnotationManager();
    if (!mounted) return;

    // Remove círculo anterior, se existir
    if (_destCircle != null) {
      await _circleMgr!.delete(_destCircle!);
      if (!mounted) return;
    }

    // Cria novo círculo para destino
    _destCircle = await _circleMgr!.create(
      mbx.CircleAnnotationOptions(
        geometry: destPoint,
        circleRadius: 10,
        circleColor: _destRed.value,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 2.5,
      ),
    );
    if (!mounted) return;

    final fromPos = _effectiveFromPosition();
    if (fromPos == null) return;

    // Rota preview (Mapbox Directions)
    final route = await MapboxDirectionsService.instance.getRoute(
      fromLon: fromPos.lng.toDouble(),
      fromLat: fromPos.lat.toDouble(),
      toLon: place.longitude,
      toLat: place.latitude,
      profile: _mode == 'scooter' ? 'cycling' : _mode,
    );
    if (!mounted || route == null) return;

    // Gestor de polylines
    _lineMgr ??= await widget.mapboxMap.annotations
        .createPolylineAnnotationManager();
    if (!mounted) return;

    // Remove polyline anterior se existir
    if (_routeLine != null) {
      await _lineMgr!.delete(_routeLine!);
      if (!mounted) return;
    }

    // Desenha nova polyline
    _routeLine = await _lineMgr!.create(
      mbx.PolylineAnnotationOptions(
        geometry: mbx.LineString(
          coordinates: route.geometry
              .map((c) => mbx.Position((c[0]).toDouble(), (c[1]).toDouble()))
              .toList(),
        ),
        lineColor: _ecoMint.value,
        lineWidth: 5.0,
      ),
    );
    if (!mounted) return;

    setState(() {
      _distance = route.distance.toDouble();
      _duration = route.duration.toDouble();
    });

    // Ajuste da câmara para enquadrar origem e destino
    await _fitFromTo(fromPos, mbx.Position(place.longitude, place.latitude));
  }

  /// Ajusta a câmara do mapa para enquadrar dois pontos [a] e [b]
  /// com um zoom aproximado baseado na distância entre eles.
  ///
  /// Usa uma função haversine simplificada em km para determinar o zoom.
  Future<void> _fitFromTo(mbx.Position a, mbx.Position b) async {
    final center = mbx.Position((a.lng + b.lng) / 2, (a.lat + b.lat) / 2);

    double _haversineKm(num lat1n, num lon1n, num lat2n, num lon2n) {
      final lat1 = lat1n.toDouble();
      final lon1 = lon1n.toDouble();
      final lat2 = lat2n.toDouble();
      final lon2 = lon2n.toDouble();

      const r = 6371.0;
      final dLat = (lat2 - lat1) * (math.pi / 180.0);
      final dLon = (lon2 - lon1) * (math.pi / 180.0);
      final la1 = lat1 * (math.pi / 180.0);
      final la2 = lat2 * (math.pi / 180.0);
      final a_ =
          (math.sin(dLat / 2) * math.sin(dLat / 2)) +
          (math.sin(dLon / 2) * math.sin(dLon / 2)) *
              math.cos(la1) *
              math.cos(la2);
      final c = 2 * math.atan2(math.sqrt(a_), math.sqrt(1 - a_));
      return r * c;
    }

    final km = _haversineKm(a.lat, a.lng, b.lat, b.lng);

    double zoom;
    if (km < 0.5) {
      zoom = 15.5;
    } else if (km < 1) {
      zoom = 15.0;
    } else if (km < 2) {
      zoom = 14.5;
    } else if (km < 5) {
      zoom = 13.5;
    } else if (km < 10) {
      zoom = 12.5;
    } else if (km < 20) {
      zoom = 11.5;
    } else {
      zoom = 10.5;
    }

    await widget.mapboxMap.flyTo(
      mbx.CameraOptions(
        center: mbx.Point(coordinates: center),
        zoom: zoom,
      ),
      mbx.MapAnimationOptions(duration: 900),
    );
  }

  /// Devolve a posição efetiva da origem:
  /// - Se `from` é "Localização atual" → usa [userLocation].
  /// - Se o utilizador escolheu outra origem → usa as coordenadas dessa seleção.
  mbx.Position? _effectiveFromPosition() {
    if (_fromIsCurrent || _selectedFrom == null) {
      final p = widget.userLocation.coordinates;
      return mbx.Position(p.lng, p.lat);
    }
    return mbx.Position(_selectedFrom!.longitude, _selectedFrom!.latitude);
  }

  /// Mostra o diálogo de filtros de rota (modos de transporte, transitTypes,
  /// distância máxima a pé).
  ///
  /// Cria localmente um estado interno (via [StatefulBuilder]) que controla:
  /// - Conjunto de modos selecionados.
  /// - Tipos de transporte público (quando TRANSIT está ativo).
  /// - Campo de texto para distância máxima a pé (em km).
  ///
  /// No final:
  /// - Se o utilizador clicar em "Aplicar", devolve [RouteFilters] (ou null se vazio).
  /// - Se clicar em "Limpar", o resultado é null e o estado local é limpo.
  Future<void> _showFilterDialog(BuildContext context) async {
    // Modos de transporte disponíveis no OTP
    final availableModes = [
      {'value': 'WALK', 'label': 'Caminhar', 'icon': Icons.directions_walk},
      {'value': 'BICYCLE', 'label': 'Bicicleta', 'icon': Icons.directions_bike},
      {
        'value': 'TRANSIT',
        'label': 'Transporte público',
        'icon': Icons.directions_transit,
      },
      {'value': 'CAR', 'label': 'Carro', 'icon': Icons.directions_car},
    ];

    // Tipos de transporte público granulares (usados quando TRANSIT está selecionado)
    final transitTypes = [
      {'value': 'BUS', 'label': 'Autocarro', 'icon': Icons.directions_bus},
      {'value': 'RAIL', 'label': 'Comboio', 'icon': Icons.train},
      {'value': 'METRO', 'label': 'Metro', 'icon': Icons.subway},
      {'value': 'TRAM', 'label': 'Elétrico', 'icon': Icons.tram},
      {
        'value': 'BICYCLE_SHARE',
        'label': 'Bicicleta partilhada (Gira)',
        'icon': Icons.pedal_bike,
      },
      {
        'value': 'SCOOTER_SHARE',
        'label': 'Scooter partilhado',
        'icon': Icons.electric_scooter,
      },
    ];

    // Estado inicial baseado nos filtros atualmente ativos
    Set<String> selectedModes = Set.from(_activeFilters?.modes ?? []);
    Set<String> selectedTransitTypes = Set.from(
      _activeFilters?.transitTypes ?? [],
    );
    int? maxWalk = _activeFilters?.maxWalkDistanceMeters;

    // Controlador para o campo de distância máxima a pé (km)
    final TextEditingController walkController = TextEditingController(
      text: maxWalk != null ? (maxWalk / 1000).toStringAsFixed(1) : '',
    );

    final result = await showDialog<RouteFilters?>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Recalcular dinamicamente se TRANSIT está selecionado
            final isTransitSelected = selectedModes.contains('TRANSIT');

            return AlertDialog(
              title: const Text('Filtros de rota'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Seleciona os modos de transporte:',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Podes selecionar múltiplos modos',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 8),

                    // Lista de modos de transporte principais
                    ...availableModes.map((mode) {
                      final isSelected = selectedModes.contains(
                        mode['value'] as String,
                      );
                      return CheckboxListTile(
                        title: Row(
                          children: [
                            Icon(
                              mode['icon'] as IconData,
                              size: 20,
                              color: isSelected ? _ecoMint : null,
                            ),
                            const SizedBox(width: 8),
                            Text(mode['label'] as String),
                          ],
                        ),
                        value: isSelected,
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selectedModes.add(mode['value'] as String);
                            } else {
                              selectedModes.remove(mode['value'] as String);
                              // Se desligarmos TRANSIT, limpamos tipos de transit
                              if (mode['value'] == 'TRANSIT') {
                                selectedTransitTypes.clear();
                              }
                            }
                          });
                        },
                        dense: true,
                        activeColor: _ecoMint,
                      );
                    }).toList(),

                    // Tipos de transporte público detalhados
                    if (isTransitSelected) ...[
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text(
                        'Tipos de transporte público:',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Seleciona tipos específicos (deixa vazio para todos)',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      ...transitTypes.map((type) {
                        final isSelected = selectedTransitTypes.contains(
                          type['value'] as String,
                        );
                        return CheckboxListTile(
                          title: Row(
                            children: [
                              Icon(
                                type['icon'] as IconData,
                                size: 18,
                                color: isSelected ? _ecoMint : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  type['label'] as String,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          value: isSelected,
                          onChanged: (checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selectedTransitTypes.add(
                                  type['value'] as String,
                                );
                              } else {
                                selectedTransitTypes.remove(
                                  type['value'] as String,
                                );
                              }
                            });
                          },
                          dense: true,
                          activeColor: _ecoMint,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                        );
                      }).toList(),
                    ],

                    const SizedBox(height: 16),
                    const Text(
                      'Distância máxima a pé (km):',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: walkController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        hintText: 'Ex: 2.5 (deixar vazio para sem limite)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                // Limpa filtros e fecha com null
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Limpar'),
                ),
                // Aplica filtros escolhidos
                TextButton(
                  onPressed: () {
                    final filters = RouteFilters(
                      modes: selectedModes.isEmpty
                          ? null
                          : selectedModes.toList(),
                      transitTypes: selectedTransitTypes.isEmpty
                          ? null
                          : selectedTransitTypes.toList(),
                      maxWalkDistanceMeters: walkController.text.isNotEmpty
                          ? (double.tryParse(walkController.text) ?? 0.0)
                                    .toInt() *
                                1000
                          : null,
                    );
                    Navigator.of(
                      context,
                    ).pop(filters.hasActiveFilters ? filters : null);
                  },
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    // Resultado do diálogo: actualiza `_activeFilters` com o que vier
    if (result != null) {
      setState(() {
        _activeFilters = result;
      });
    } else if (result == null && _activeFilters != null) {
      // Utilizador clicou "Limpar" – remove filtros ativos
      setState(() {
        _activeFilters = null;
      });
    }
  }

  /// Handler do botão "Confirmar".
  ///
  /// Verifica se existe destino selecionado e:
  /// - Remove a polyline de pré-visualização (se existir).
  /// - Determina lugar de origem (Localização atual vs. origem selecionada).
  /// - Chama [onConfirmOptions] com [RouteOptionsArgs], para abrir o
  ///   ecrã de opções de rota/navegação.
  void _onConfirm() async {
    if (_selectedTo == null) return;

    try {
      if (_lineMgr != null && _routeLine != null) {
        await _lineMgr!.delete(_routeLine!);
        _routeLine = null;
      }
    } catch (_) {}

    final fromPos = _effectiveFromPosition()!;
    final fromPlace = _fromIsCurrent || _selectedFrom == null
        ? SearchboxPlace(
            id: 'current',
            name: 'Localização atual',
            placeName: _fromController.text.isNotEmpty
                ? _fromController.text
                : 'Localização atual',
            longitude: fromPos.lng.toDouble(),
            latitude: fromPos.lat.toDouble(),
            featureType: 'place',
            category: null,
            distanceMeters: 0,
          )
        : _selectedFrom!;

    widget.onConfirmOptions(
      RouteOptionsArgs(
        mapboxMap: widget.mapboxMap,
        from: fromPlace,
        to: _selectedTo!,
        filters: _activeFilters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isDark = t.brightness == Brightness.dark;
    final panelColor = isDark ? t.colorScheme.surface : _offWhiteSand;

    final media = MediaQuery.of(context);
    final bottomInset = media.padding.bottom;

    final showingResults = _sbSuggestions.isNotEmpty;

    // Layout principal do overlay – o pai (bottom sheet route) controla a altura
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: panelColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26000000),
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset + 12),
        child: Column(
          children: [
            const SizedBox(height: 40),

            // ===== Inputs "De" / "Para" =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? t.colorScheme.surfaceVariant.withOpacity(.4)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x14000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _LocationRow(
                      label: 'De',
                      controller: _fromController,
                      icon: Icons.my_location,
                      readOnly: false,
                      badgeText: _fromIsCurrent ? 'Atual' : null,
                      hintText: 'Origem',
                      focusNode: _fromFocus,
                      onChanged: _onChangedActive,
                      onTap: () => _fromFocus.requestFocus(),
                    ),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    _LocationRow(
                      label: 'Para',
                      controller: _toController,
                      icon: Icons.place_outlined,
                      hintText: 'Para onde?',
                      readOnly: false,
                      focusNode: _toFocus,
                      onChanged: _onChangedActive,
                      onTap: () => _toFocus.requestFocus(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ===== Chip de Filtros =====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 16,
                          color: _activeFilters != null
                              ? _ecoMint
                              : t.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _activeFilters != null &&
                                  _activeFilters!.hasActiveFilters
                              ? 'Filtros ativos'
                              : 'Filtros',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                _activeFilters != null &&
                                    _activeFilters!.hasActiveFilters
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color:
                                _activeFilters != null &&
                                    _activeFilters!.hasActiveFilters
                                ? _ecoMint
                                : t.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                    selected:
                        _activeFilters != null &&
                        _activeFilters!.hasActiveFilters,
                    onSelected: (_) => _showFilterDialog(context),
                    backgroundColor:
                        _activeFilters != null &&
                            _activeFilters!.hasActiveFilters
                        ? _ecoMint.withOpacity(0.1)
                        : t.colorScheme.surfaceVariant.withOpacity(0.5),
                    selectedColor: _ecoMint.withOpacity(0.15),
                    side: BorderSide(
                      color:
                          _activeFilters != null &&
                              _activeFilters!.hasActiveFilters
                          ? _ecoMint
                          : t.colorScheme.onSurface.withOpacity(0.2),
                    ),
                  ),
                  if (_activeFilters != null &&
                      _activeFilters!.hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _activeFilters = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: t.colorScheme.error.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: t.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ===== Lista de resultados / nearby + botões de ação =====
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isSearching)
                      const LinearProgressIndicator(minHeight: 2)
                    else
                      Text(
                        showingResults
                            ? 'Resultados'
                            : (_isLoadingNearby
                                  ? 'A carregar sugestões...'
                                  : 'Sugestões perto de ti'),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: t.colorScheme.onBackground,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: showingResults
                          // Lista de resultados da pesquisa
                          ? ListView.builder(
                              itemCount: _sbSuggestions.length,
                              itemBuilder: (context, i) {
                                final s = _sbSuggestions[i];

                                String featLabel;
                                switch ((s.featureType ?? '').toLowerCase()) {
                                  case 'poi':
                                    featLabel = 'POI';
                                    break;
                                  case 'street':
                                    featLabel = 'Rua';
                                    break;
                                  case 'address':
                                    featLabel = 'Morada';
                                    break;
                                  default:
                                    featLabel = (s.featureType ?? 'Lugar');
                                }
                                final subtitleBits = <String>[
                                  featLabel,
                                  if (s.category != null &&
                                      s.category!.trim().isNotEmpty)
                                    s.category!,
                                ];
                                final cached = _sbCache[s.mapboxId];
                                final trailing = cached?.distanceMeters != null
                                    ? _formatDistance(cached!.distanceMeters!)
                                    : null;

                                return _ResultTile(
                                  title: s.name,
                                  subtitle:
                                      '${s.placeName} • ${subtitleBits.join(' • ')}',
                                  trailing: trailing,
                                  onTap: () => _applySuggestion(s),
                                );
                              },
                            )
                          // Lista de nearby / loading / vazio
                          : (_isLoadingNearby
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : (_nearby.isEmpty
                                      ? Center(
                                          child: Text(
                                            _emptyMsg ??
                                                'Nada por perto encontrado.',
                                          ),
                                        )
                                      : ListView.builder(
                                          itemCount: _nearby.length,
                                          itemBuilder: (context, i) {
                                            final p = _nearby[i];
                                            return _ResultTile(
                                              title: p.name,
                                              subtitle: _formatSubtitleSB(p),
                                              trailing: _formatDistance(
                                                p.distanceMeters,
                                              ),
                                              onTap: () => _applySelection(p),
                                            );
                                          },
                                        ))),
                    ),
                    const SizedBox(height: 8),

                    // Preview de distância/duração da rota
                    if (_distance != null && _duration != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Distância: ${(_distance! / 1000).toStringAsFixed(1)} km • '
                          'Duração: ${(_duration! / 60).round()} min',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            color: t.colorScheme.onBackground.withOpacity(.7),
                          ),
                        ),
                      ),

                    // Botões "Cancelar" / "Confirmar"
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ecoMint,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: widget.onClose,
                            child: const Text(
                              'Cancelar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _ecoMint,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26),
                              ),
                            ),
                            onPressed: _selectedTo == null ? null : _onConfirm,
                            child: const Text(
                              'Confirmar',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o subtítulo de um [SearchboxPlace] para apresentação na lista.
  ///
  /// Junta:
  /// - Place name.
  /// - Tipo de feature (POI / Rua / Morada / outro).
  /// - Categoria, se existir.
  String _formatSubtitleSB(SearchboxPlace p) {
    final bits = <String>[];
    switch ((p.featureType ?? '').toLowerCase()) {
      case 'poi':
        bits.add('POI');
        break;
      case 'street':
        bits.add('Rua');
        break;
      case 'address':
        bits.add('Morada');
        break;
      default:
        if ((p.featureType ?? '').isNotEmpty) bits.add(p.featureType!);
    }
    if (p.category != null && p.category!.isNotEmpty) bits.add(p.category!);
    final meta = bits.join(' • ');
    return meta.isEmpty ? p.placeName : '${p.placeName} • $meta';
  }

  /// Formata uma distância em metros [d] para uma string legível (m ou km).
  String? _formatDistance(double? d) {
    if (d == null) return null;
    if (d < 1000) return '${d.round()} m';
    return '${(d / 1000).toStringAsFixed(1)} km';
  }
}

/// Linha reutilizável para os inputs de localização ("De" / "Para").
///
/// Contém:
/// - Ícone à esquerda.
/// - Label pequeno (De/Para).
/// - TextField principal.
/// - Badge opcional (ex.: "Atual").
class _LocationRow extends StatelessWidget {
  /// Label pequeno sobre o campo (ex.: "De", "Para").
  final String label;

  /// Controller do campo de texto.
  final TextEditingController controller;

  /// Ícone principal à esquerda.
  final IconData icon;

  /// Texto de placeholder/hint.
  final String? hintText;

  /// Texto do badge à direita (ex.: "Atual").
  final String? badgeText;

  /// Indica se o campo é apenas leitura.
  final bool readOnly;

  /// FocusNode opcional para controlar foco a partir do exterior.
  final FocusNode? focusNode;

  /// Callback opcional ao tocar no campo.
  final VoidCallback? onTap;

  /// Callback opcional para mudanças no texto.
  final ValueChanged<String>? onChanged;

  const _LocationRow({
    required this.label,
    required this.controller,
    required this.icon,
    this.hintText,
    this.badgeText,
    this.readOnly = false,
    this.focusNode,
    this.onTap,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 22, color: t.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Label pequeno (De/Para)
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: t.colorScheme.onSurface.withOpacity(.6),
                ),
              ),
              // Campo de texto principal
              TextField(
                controller: controller,
                focusNode: focusNode,
                readOnly: readOnly,
                onTap: onTap,
                onChanged: onChanged,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hintText,
                  hintStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    color: t.colorScheme.onSurface.withOpacity(.5),
                  ),
                ),
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (badgeText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF3CD4A0),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              badgeText!,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tile genérico para cada sugestão / resultado exibido na lista.
///
/// Mostra:
/// - Título (nome do POI/rua).
/// - Subtítulo (morada + meta).
/// - Distância opcional à direita.
/// - Ícone de localização à esquerda.
class _ResultTile extends StatelessWidget {
  /// Título principal da linha (nome do lugar).
  final String title;

  /// Subtítulo (placeName + tipo, categoria, etc.).
  final String subtitle;

  /// Texto de distância (ex.: "300 m", "2.1 km"), opcional.
  final String? trailing;

  /// Callback acionado ao tocar na tile.
  final VoidCallback onTap;

  const _ResultTile({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: t.cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(Icons.place_outlined, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Título (nome do local)
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      // Subtítulo (placeName + meta)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: t.colorScheme.onSurface.withOpacity(.7),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 12,
                      color: t.colorScheme.onSurface.withOpacity(.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
