// lib/ui/gbfs_availability_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../data/gbfs_api.dart';

class GbfsAvailabilityPage extends StatefulWidget {
  const GbfsAvailabilityPage({super.key});

  static const _gbfsGreen = Color(0xFF3CD4A0);

  @override
  State<GbfsAvailabilityPage> createState() =>
      _GbfsAvailabilityPageState();
}

class _GbfsAvailabilityPageState
    extends State<GbfsAvailabilityPage> {
  final GbfsApiClient _api = const GbfsApiClient();
  final TextEditingController _searchController =
      TextEditingController();

  bool _loadingSystems = false;
  bool _loadingAvailability = false;
  String? _error;

  List<GbfsSystem> _systems = [];
  GbfsSystem? _selectedSystem;

  /// listas “cruas” vindas do backend
  List<GbfsStationAvailability> _allStations = [];
  List<GbfsFreeBike> _allFreeBikes = [];

  /// listas filtradas (search + filtros de qualidade)
  List<GbfsStationAvailability> _visibleStations = [];
  List<GbfsFreeBike> _visibleFreeBikes = [];

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSystems();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSystems() async {
    setState(() {
      _loadingSystems = true;
      _error = null;
    });

    try {
      final systems = await _api.listSystems();

      systems.sort(
        (a, b) => a.name.toLowerCase().compareTo(
              b.name.toLowerCase(),
            ),
      );

      GbfsSystem? selected =
          systems.isNotEmpty ? systems.first : null;

      setState(() {
        _systems = systems;
        _selectedSystem = selected;
      });

      if (selected != null) {
        await _loadAvailability(selected.systemId);
      }
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GBFS PAGE] error loading systems: $e\n$st');
      }
      setState(() {
        _error =
            'Não foi possível carregar os sistemas de partilha.';
      });
    } finally {
      setState(() {
        _loadingSystems = false;
      });
    }
  }

  List<GbfsStationAvailability> _baseFilterStations(
    List<GbfsStationAvailability> stations,
  ) {
    return stations.where((s) {
      final name = s.name.trim();

      // precisa de ter nome minimamente decente
      if (name.isEmpty || name.length < 3) return false;

      // precisa de ter alguma info de ocupação
      if (s.freeVehicles == null && s.totalDocks == null) {
        return false;
      }

      // se tiver address, óptimo; se não, pode ser que o nome seja a rua
      return true;
    }).toList();
  }

  void _applyFilters() {
    final q = _searchQuery.trim().toLowerCase();

    // 1) primeiro filtramos por qualidade de dados
    var stations = _baseFilterStations(_allStations);

    // 2) depois aplicamos o search
    if (q.isNotEmpty) {
      stations = stations.where((s) {
        final name = s.name.toLowerCase();
        final address = (s.address ?? '').toLowerCase();
        return name.contains(q) || address.contains(q);
      }).toList();
    }

    // free bikes
    var bikes = List<GbfsFreeBike>.from(_allFreeBikes);
    if (q.isNotEmpty) {
      bikes = bikes.where((b) {
        final id = b.id.toLowerCase();
        final type = (b.vehicleTypeId ?? '').toLowerCase();
        return id.contains(q) || type.contains(q);
      }).toList();
    }

    stations.sort(
      (a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    bikes.sort(
      (a, b) => a.id.toLowerCase().compareTo(b.id.toLowerCase()),
    );

    setState(() {
      _visibleStations = stations;
      _visibleFreeBikes = bikes;
    });
  }

  Future<void> _loadAvailability(String systemId) async {
    setState(() {
      _loadingAvailability = true;
      _error = null;
      _allStations = [];
      _allFreeBikes = [];
      _visibleStations = [];
      _visibleFreeBikes = [];
    });

    try {
      final resp =
          await _api.getAvailability(systemId, lang: 'pt');

      setState(() {
        _allStations = resp.stations;
        _allFreeBikes = resp.freeBikes;
      });

      _applyFilters();
    } catch (e, st) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[GBFS PAGE] error loading availability: $e\n$st');
      }
      setState(() {
        _error =
            'Não foi possível carregar a disponibilidade deste sistema.';
      });
    } finally {
      setState(() {
        _loadingAvailability = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: GbfsAvailabilityPage._gbfsGreen,
        foregroundColor: Colors.black,
        title: const Text('Disponibilidade GBFS'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_selectedSystem != null) {
            await _loadAvailability(_selectedSystem!.systemId);
          } else {
            await _loadSystems();
          }
        },
        child: _buildBody(t),
      ),
    );
  }

  Widget _buildBody(ThemeData t) {
    if (_loadingSystems && _systems.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            _error!,
            style: t.textTheme.bodyMedium?.copyWith(
              color: t.colorScheme.error,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _loadSystems,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }

    if (_systems.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Nenhum sistema GBFS configurado.',
            style: t.textTheme.bodyMedium,
          ),
        ],
      );
    }

    final hasStations = _visibleStations.isNotEmpty;
    final hasFreeBikes = _visibleFreeBikes.isNotEmpty;

    final hasRawStations = _allStations.isNotEmpty;
    final hasRawFreeBikes = _allFreeBikes.isNotEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Text(
          'Partilha de bicicletas / trotinetes',
          style: t.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Escolhe o sistema (cidade/operador) e pesquisa por estação ou veículo.',
          style: t.textTheme.bodyMedium?.copyWith(
            color: t.textTheme.bodyMedium?.color?.withOpacity(0.75),
          ),
        ),
        const SizedBox(height: 16),
        _buildSystemSelector(t),
        const SizedBox(height: 12),
        _buildSearchField(t),
        const SizedBox(height: 12),
        if (_loadingAvailability)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          )
        else ...[
          if (!hasStations && !hasFreeBikes) ...[
            const SizedBox(height: 16),
            if (_searchQuery.isNotEmpty &&
                (hasRawStations || hasRawFreeBikes))
              Text(
                'Nenhum resultado para "$_searchQuery".',
                style: t.textTheme.bodyMedium,
              )
            else
              Text(
                'Nenhuma estação ou veículo disponível para este sistema neste momento.',
                style: t.textTheme.bodyMedium,
              ),
          ],
          if (hasStations) ...[
            const SizedBox(height: 8),
            Text(
              'Estações',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._visibleStations.map(
              (s) => _GbfsStationCard(
                station: s,
                accentColor: GbfsAvailabilityPage._gbfsGreen,
              ),
            ),
          ],
          if (hasFreeBikes) ...[
            const SizedBox(height: 24),
            Text(
              'Veículos soltos',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            ..._visibleFreeBikes.map(
              (b) => _GbfsFreeBikeCard(
                bike: b,
                accentColor: GbfsAvailabilityPage._gbfsGreen,
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildSystemSelector(ThemeData t) {
    return DropdownButtonFormField<GbfsSystem>(
      value: _selectedSystem,
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _selectedSystem = value;
        });
        _loadAvailability(value.systemId);
      },
      decoration: const InputDecoration(
        labelText: 'Sistema',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
      ),
      items: _systems.map((s) {
        final locationSuffix =
            s.location != null && s.location!.isNotEmpty
                ? ' — ${s.location}'
                : '';
        return DropdownMenuItem(
          value: s,
          child: Text('${s.name}$locationSuffix'),
        );
      }).toList(),
    );
  }

  Widget _buildSearchField(ThemeData t) {
    return TextField(
      controller: _searchController,
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
        _applyFilters();
      },
      decoration: InputDecoration(
        labelText: 'Pesquisar estação ou veículo',
        hintText: 'Ex: Mercado, Estação, Bike 123...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                  });
                  _applyFilters();
                },
              )
            : null,
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(999)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
      ),
    );
  }
}

class _GbfsStationCard extends StatelessWidget {
  final GbfsStationAvailability station;
  final Color accentColor;

  const _GbfsStationCard({
    super.key,
    required this.station,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final free = station.freeVehicles ?? 0;
    final total = station.totalDocks ?? 0;
    final used =
        total > 0 ? (total - free).clamp(0, total) : 0;
    final occupancy =
        total == 0 ? 0 : (used / total.toDouble() * 100).round();

    final address = station.address;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.18),
            t.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
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
          Text(
            station.name,
            style: t.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (address != null && address.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              address,
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.textTheme.bodyMedium?.color
                    ?.withOpacity(0.8),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            '$free veículos disponíveis'
            '${total > 0 ? ' de $total' : ''}',
            style: t.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total == 0
                ? 0
                : used / total.toDouble(),
            color: accentColor,
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
      ),
    );
  }
}

class _GbfsFreeBikeCard extends StatelessWidget {
  final GbfsFreeBike bike;
  final Color accentColor;

  const _GbfsFreeBikeCard({
    super.key,
    required this.bike,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    final hasCoords =
        bike.latitude != null && bike.longitude != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            accentColor.withOpacity(0.18),
            t.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
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
          Text(
            'Veículo ${bike.id}',
            style: t.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (hasCoords)
            Text(
              'Lat: ${bike.latitude!.toStringAsFixed(5)}, '
              'Lon: ${bike.longitude!.toStringAsFixed(5)}',
              style: t.textTheme.bodyMedium,
            )
          else
            Text(
              'Localização aproximada indisponível',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.textTheme.bodyMedium?.color
                    ?.withOpacity(0.8),
              ),
            ),
          if (bike.vehicleTypeId != null) ...[
            const SizedBox(height: 4),
            Text(
              'Tipo: ${bike.vehicleTypeId}',
              style: t.textTheme.bodySmall?.copyWith(
                color: t.textTheme.bodySmall?.color
                    ?.withOpacity(0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
