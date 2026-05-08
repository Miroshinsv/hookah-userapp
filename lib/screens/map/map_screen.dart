import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/lounge.dart';
import '../../core/utils/schedule_parser.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _showList = false;
  final MapController _mapController = MapController();
  LatLng? _userLocation;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  Future<void> _locateUser() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _userLocation = loc);
      _mapController.move(loc, 14);
    } catch (_) {
      // геолокация недоступна — остаёмся на дефолтном центре
    }
  }

  void _showLoungeSheet(Lounge lounge) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LoungeBottomSheet(lounge: lounge),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Query(
      options: QueryOptions(
        document: gql(GQLQueries.lounges),
        fetchPolicy: FetchPolicy.cacheAndNetwork,
      ),
      builder: (result, {fetchMore, refetch}) {
        List<Lounge> lounges = [];
        if (result.data != null) {
          final raw = result.data!['lounges'] as List<dynamic>? ?? [];
          lounges = raw
              .map((e) => Lounge.fromJson(e as Map<String, dynamic>))
              .toList();
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Hookah Order'),
            actions: [
              if (result.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          body: _showList ? _buildList(lounges) : _buildMap(lounges),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_showList && _userLocation != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: FloatingActionButton.small(
                    heroTag: 'locate',
                    onPressed: () => _mapController.move(_userLocation!, 14),
                    child: const Icon(Icons.my_location),
                  ),
                ),
              FloatingActionButton.extended(
                heroTag: 'toggle',
                onPressed: () => setState(() => _showList = !_showList),
                icon: Icon(_showList ? Icons.map : Icons.list),
                label: Text(_showList ? 'Карта' : 'Список'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMap(List<Lounge> lounges) {
    final valid =
        lounges.where((l) => l.latitude != 0 || l.longitude != 0).toList();
    final center = valid.isNotEmpty
        ? LatLng(valid.first.latitude, valid.first.longitude)
        : const LatLng(55.7558, 37.6173);

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: center, initialZoom: 12),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'ru.hookahorder.app',
        ),
        MarkerLayer(
          markers: [
            // маркеры кальянных
            ...valid.map((l) => Marker(
                  point: LatLng(l.latitude, l.longitude),
                  width: 50,
                  height: 50,
                  rotate: true,
                  child: GestureDetector(
                    onTap: () => _showLoungeSheet(l),
                    child: Image.asset('assets/marker.png',
                        width: 50, height: 50),
                  ),
                )),
            // маркер пользователя
            if (_userLocation != null)
              Marker(
                point: _userLocation!,
                width: 48,
                height: 48,
                child: _UserMarker(),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildList(List<Lounge> lounges) {
    if (lounges.isEmpty) {
      return const Center(
          child: Text('Кальянные не найдены',
              style: TextStyle(color: Colors.grey)));
    }
    return ListView.separated(
      itemCount: lounges.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final l = lounges[i];
        return ListTile(
          leading: const CircleAvatar(
            backgroundColor: Colors.brown,
            child: Icon(Icons.smoking_rooms, color: Colors.white, size: 20),
          ),
          title: Text(l.name),
          subtitle: Text(l.shortAddress ?? ''),
          trailing: l.rating != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 2),
                    Text(l.rating!.toStringAsFixed(1)),
                  ],
                )
              : null,
          onTap: () => _showLoungeSheet(l),
        );
      },
    );
  }
}

// ─── User location marker ────────────────────────────────────────────────────

class _UserMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // внешнее свечение
        const SizedBox(
          width: 48,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0x220080FF),
            ),
          ),
        ),
        // синяя точка с белой обводкой
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1A73E8),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [
              BoxShadow(
                color: Color(0x441A73E8),
                blurRadius: 6,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bottom sheet ────────────────────────────────────────────────────────────

class _LoungeBottomSheet extends StatelessWidget {
  final Lounge lounge;

  const _LoungeBottomSheet({required this.lounge});

  @override
  Widget build(BuildContext context) {
    final isOpen = ScheduleParser.isOpenNow(lounge.schedule);
    final todayHours = ScheduleParser.todayHours(lounge.schedule);
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Название + рейтинг
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  lounge.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              if (lounge.rating != null) ...[
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 3),
                    Text(
                      lounge.rating!.toStringAsFixed(1),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Статус: открыто / закрыто
          _StatusChip(isOpen: isOpen),
          const SizedBox(height: 10),

          // Адрес
          if (lounge.shortAddress != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    lounge.shortAddress!,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            ),

          // Часы сегодня
          if (todayHours != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  'Сегодня: $todayHours',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],

          const SizedBox(height: 20),

          // Кнопки
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/lounge', arguments: lounge);
                  },
                  child: const Text('Подробнее'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isLoggedIn
                      ? () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/order/new',
                              arguments: lounge);
                        }
                      : () => _promptLogin(context),
                  child: const Text('Сделать заказ'),
                ),
              ),
            ],
          ),

          // Подсказка если не авторизован
          if (!isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Для заказа необходима авторизация',
                    style:
                        TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _promptLogin(BuildContext context) {
    final nav = Navigator.of(context); // захватываем до закрытия bottom sheet
    nav.pop();
    showDialog(
      context: nav.context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Необходима авторизация'),
        content:
            const Text('Войдите или зарегистрируйтесь, чтобы сделать заказ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              nav.pushNamed('/auth');
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOpen;

  const _StatusChip({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.red.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen
              ? Colors.green.withValues(alpha: 0.5)
              : Colors.red.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 14,
            color: isOpen ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Открыто' : 'Закрыто',
            style: TextStyle(
              color: isOpen ? Colors.green : Colors.red,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
