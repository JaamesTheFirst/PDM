import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../services/search_history_service.dart';
import '../../../app/app_shell.dart';
import '../../map/pages/map_page.dart';
import '../../../app/app_router.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final _searchHistoryService = SearchHistoryService.instance;
  List<SearchDestination> _history = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final history = await _searchHistoryService.getHistory();
      setState(() {
        _history = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erro ao carregar histórico: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      if (diff.inHours == 0) {
        if (diff.inMinutes == 0) {
          return 'Agora';
        }
        return 'Há ${diff.inMinutes} min';
      }
      return 'Há ${diff.inHours} h';
    } else if (diff.inDays == 1) {
      return 'Ontem';
    } else if (diff.inDays < 7) {
      return 'Há ${diff.inDays} dias';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  Future<void> _repeatSearch(SearchDestination destination) async {
    // Mudar para o tab do mapa
    AppShell.navigateToTab.value = 0;

    // Pequeno delay para dar tempo ao MapPage montar
    await Future.delayed(const Duration(milliseconds: 300));

    // Enviar os dados para o MapPage via ValueNotifier
    // Note: We only have destination, so origin will be current location
    MapPage.pendingRouteSearch.value = {
      'toId': 'history_${destination.timestamp.millisecondsSinceEpoch}_to',
      'toName': destination.name,
      'toAddress': destination.address, // Include full address for placeName
      'toLat': destination.latitude,
      'toLon': destination.longitude,
    };

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('A carregar destino...'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    if (_isLoading) {
      return Container(
        color: t.scaffoldBackgroundColor,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Container(
        color: t.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar histórico',
                style: t.textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                _error!,
                style: t.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadHistory,
                child: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (_history.isEmpty) {
      return Container(
        color: t.scaffoldBackgroundColor,
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.history,
                size: 48,
                color: t.colorScheme.onSurface.withOpacity(.6),
              ),
              const SizedBox(height: 12),
              Text(
                'Ainda não há histórico',
                style: TextStyle(
                  fontSize: 16,
                  color: t.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Procura um destino no mapa para começares a registar.',
                style: TextStyle(
                  fontSize: 14,
                  color: t.colorScheme.onSurface.withOpacity(.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: t.scaffoldBackgroundColor,
      child: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _history.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _history[index];
            return _HistoryCard(
              destination: item,
              onTap: () => _repeatSearch(item),
              formatDate: _formatDate,
            );
          },
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  static const _ecoMint = Color(0xFF3CD4A0);

  final SearchDestination destination;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;

  const _HistoryCard({
    required this.destination,
    required this.onTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: t.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: t.brightness == Brightness.dark
                ? Colors.white10
                : const Color(0x143CD4A0),
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: _ecoMint.withOpacity(0.16),
              child: const Icon(Icons.place, color: _ecoMint, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    destination.name,
                    style: t.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    destination.address,
                    style: t.textTheme.bodySmall?.copyWith(
                      color: t.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Text(
              formatDate(destination.timestamp),
              style: TextStyle(
                fontSize: 12,
                color: t.colorScheme.onSurface.withOpacity(0.5),
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

