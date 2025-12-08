import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../data/gira_api.dart';

/// Página de listagem de estações GIRA.
///
/// Funcionalidades:
/// - Paginação server-side (50 registos por página).
/// - Filtro local por texto (nome/rua da estação).
/// - Apresentação de ocupação aproximada (dock vs. bicicletas).
class GiraStationsPage extends StatefulWidget {
  const GiraStationsPage({super.key});

  /// Cor verde associada à marca GIRA.
  static const giraGreen = Color(0xFF8CC63F);

  @override
  State<GiraStationsPage> createState() => _GiraStationsPageState();
}

class _GiraStationsPageState extends State<GiraStationsPage> {
  /// Cliente de API responsável por obter dados de estações GIRA.
  final GiraApiClient _api = GiraApiClient();

  /// Campo usado para filtrar localmente as estações da página actual.
  final TextEditingController _searchController = TextEditingController();

  /// Indica se está a decorrer um carregamento (página remota).
  bool _loading = false;

  /// Mensagem de erro, se alguma operação falhou.
  String? _error;

  /// Página actual vinda da API (máx. 50 registos).
  List<GiraStationRecord> _pageStations = [];

  /// Lista filtrada localmente com base em [_searchController].
  List<GiraStationRecord> _visibleStations = [];

  /// Número total de registos (todas as estações).
  int _total = 0;

  /// Limite de registos por página, conforme definido pela API.
  int _limit = 50;

  /// Número da página actual (1-based).
  int _currentPage = 1;

  /// Número total de páginas, calculado a partir de [_total] e [_limit].
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadPage(1);
    _searchController.addListener(_applyLocalFilter);
  }

  @override
  void dispose() {
    _api.dispose();
    _searchController.removeListener(_applyLocalFilter);
    _searchController.dispose();
    super.dispose();
  }

  // ==================== LOAD PAGE (50 EM 50) ====================

  /// Carrega uma página de estações GIRA a partir do backend.
  ///
  /// A paginação é feita via:
  /// - [limit]: máximo de registos por página.
  /// - [offset]: deslocamento calculado a partir do número da página.
  Future<void> _loadPage(int page) async {
    if (page < 1) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final targetOffset = (page - 1) * _limit;

    try {
      final slice =
          await _api.getStations(limit: _limit, offset: targetOffset);

      final total = slice.total;
      final limit = slice.limit;
      final totalPages = limit > 0 ? ((total + limit - 1) ~/ limit) : 1;

      _pageStations = slice.records;
      _limit = limit;
      _total = total;
      _currentPage = page;
      _totalPages = totalPages == 0 ? 1 : totalPages;

      // Actualiza a lista visível aplicando o filtro de texto actual.
      _applyLocalFilter();

      debugPrint(
        '[GIRA PAGE] página $_currentPage carregada: ${_pageStations.length} registos (total=$_total, totalPages=$_totalPages)',
      );
    } catch (e) {
      debugPrint('[GIRA PAGE] _loadPage ERROR: $e');
      setState(() {
        _error = e.toString();
        _pageStations = [];
        _visibleStations = [];
      });
    } finally {
      // MUITO IMPORTANTE: limpar sempre o loading
      setState(() {
        _loading = false;
      });
    }
  }

  /// Vai para a página anterior, se existir.
  void _goToPreviousPage() {
    if (_currentPage <= 1 || _loading) return;
    _loadPage(_currentPage - 1);
  }

  /// Vai para a próxima página, se existir.
  void _goToNextPage() {
    if (_currentPage >= _totalPages || _loading) return;
    _loadPage(_currentPage + 1);
  }

  // ==================== SEARCH LOCAL (POR RUA / NOME) ====================

  /// Aplica o filtro local sobre [_pageStations] com base no texto actual.
  ///
  /// Neste momento o filtro apenas usa:
  /// - [GiraStationRecord.desigComercial]
  void _applyLocalFilter() {
    final q = _searchController.text.trim().toLowerCase();

    setState(() {
      if (q.isEmpty) {
        _visibleStations = List.from(_pageStations);
      } else {
        _visibleStations = _pageStations.where((st) {
          final name = (st.desigComercial ?? '').toLowerCase();
          // aqui podes juntar mais campos se quiseres (ex.: rua, freguesia, etc.)
          return name.contains(q);
        }).toList();
      }
    });
  }

  // ============================ UI ============================

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GiraStationsPage.giraGreen,
        foregroundColor: Colors.white,
        title: const Text('Estações GIRA'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),

            // ==== SEARCH POR RUA / NOME (LOCAL) ====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Filtrar por rua / estação GIRA...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _applyLocalFilter();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor:
                      t.colorScheme.surfaceVariant.withOpacity(0.25),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ==== BARRA DE PAGINAÇÃO COM SETAS ====
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      t.colorScheme.surfaceVariant.withOpacity(0.35),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new),
                      iconSize: 18,
                      onPressed:
                          (_currentPage > 1 && !_loading)
                              ? _goToPreviousPage
                              : null,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Página $_currentPage / $_totalPages',
                            style: t.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios),
                      iconSize: 18,
                      onPressed:
                          (_currentPage < _totalPages && !_loading)
                              ? _goToNextPage
                              : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Corpo dinâmico (lista / erro / loading)
            Expanded(
              child: _buildBody(context),
            ),
          ],
        ),
      ),
    );
  }

  /// Constrói o corpo consoante o estado actual:
  /// - Loading inicial.
  /// - Erro sem dados.
  /// - Lista vazia (sem estações ou sem match do filtro).
  /// - Lista de estações com barra de ocupação.
  Widget _buildBody(BuildContext context) {
    final t = Theme.of(context);

    // primeira página a carregar
    if (_loading && _pageStations.isEmpty && _error == null) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor:
              AlwaysStoppedAnimation<Color>(GiraStationsPage.giraGreen),
        ),
      );
    }

    // erro (sem dados carregados)
    if (_error != null && _pageStations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium?.copyWith(
              color: Colors.redAccent,
            ),
          ),
        ),
      );
    }

    // Sem resultados visíveis (ou porque não há dados ou pelo filtro)
    if (_visibleStations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          child: Text(
            _pageStations.isEmpty
                ? 'Não foram encontradas estações GIRA.'
                : 'Nenhuma estação nesta página corresponde ao filtro.',
            textAlign: TextAlign.center,
            style: t.textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: _visibleStations.length,
          itemBuilder: (context, index) {
            final st = _visibleStations[index];

            final subtitleParts = <String>[];

            if (st.estado != null) {
              subtitleParts.add('Estado: ${st.estado}');
            }
            if (st.numDocas != null) {
              subtitleParts.add('Docas: ${st.numDocas}');
            }
            if (st.numBicicletas != null) {
              subtitleParts.add('Bicicletas: ${st.numBicicletas}');
            }

            final used = (st.numDocas ?? 0) - (st.numBicicletas ?? 0);
            final occupancy = (st.numDocas == null || st.numDocas == 0)
                ? 0
                : (used / st.numDocas!.toDouble() * 100).round();

            if (st.lat != null && st.lon != null) {
              subtitleParts.add(
                '(${st.lat!.toStringAsFixed(5)}, ${st.lon!.toStringAsFixed(5)})',
              );
            }

            final subtitle =
                subtitleParts.isEmpty ? null : subtitleParts.join(' · ');

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: [
                    GiraStationsPage.giraGreen.withOpacity(0.16),
                    t.colorScheme.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // título
                  Text(
                    st.desigComercial ?? 'Estação sem nome',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: t.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),

                  if (subtitle != null) ...[
                    Text(
                      subtitle,
                      style: t.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // barra de ocupação estilo GBFS
                  if (st.numDocas != null && st.numDocas! > 0) ...[
                    LinearProgressIndicator(
                      value: st.numDocas == 0
                          ? 0
                          : used.clamp(0, st.numDocas!).toDouble() /
                              st.numDocas!.toDouble(),
                      color: GiraStationsPage.giraGreen,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ocupação aproximada: $occupancy%',
                      style: t.textTheme.bodySmall?.copyWith(
                        color: t.hintColor,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),

        // spinner pequeno quando mudas de página mas já tens dados
        if (_loading && _pageStations.isNotEmpty)
          const Positioned(
            right: 16,
            top: 12,
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  GiraStationsPage.giraGreen,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
