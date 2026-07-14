import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/lounge.dart';
import '../../core/utils/camera_move_debouncer.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/schedule_parser.dart';

const _kDefaultCenter = Point(latitude: 55.7558, longitude: 37.6173);
const _kTag = 'MapScreen';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  bool _showList = false;
  YandexMapController? _mapController;
  Point? _userLocation;

  final _debouncer = CameraMoveDebouncer();
  Point? _cameraTarget;
  double _cameraZoom = 12;

  List<LoungeMapItem> _lounges = [];
  bool _loading = false;
  String? _error;

  Map<String, Lounge>? _fullLoungeCache;
  bool _resolvingLounge = false;

  @override
  void initState() {
    super.initState();
    _locateUser();
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _locateUser() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        AppLogger.i(_kTag, 'location permission not granted — using default center');
        _cameraTarget = _kDefaultCenter;
        _cameraZoom = 12;
        _reloadLounges();
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      final loc = Point(latitude: pos.latitude, longitude: pos.longitude);
      AppLogger.i(_kTag, 'user location resolved: ${loc.latitude},${loc.longitude}');
      setState(() => _userLocation = loc);
      _mapController?.moveCamera(
        CameraUpdate.newCameraPosition(CameraPosition(target: loc, zoom: 14)),
        animation: const MapAnimation(type: MapAnimationType.smooth, duration: 0.5),
      );
      _cameraTarget = loc;
      _cameraZoom = 14;
      _reloadLounges();
    } catch (e) {
      AppLogger.w(_kTag, 'failed to resolve user location — using default center', e);
      _cameraTarget = _kDefaultCenter;
      _cameraZoom = 12;
      _reloadLounges();
    }
  }

  void _onCameraPositionChanged(
    CameraPosition position,
    CameraUpdateReason reason,
    bool finished,
  ) {
    _cameraTarget = position.target;
    _cameraZoom = position.zoom;
    if (!finished) return;
    AppLogger.d(
      _kTag,
      'camera settled at ${position.target.latitude},${position.target.longitude} '
      'zoom=${position.zoom} reason=$reason',
    );
    _debouncer.schedule(_reloadLounges);
  }

  Future<void> _reloadLounges() async {
    final target = _cameraTarget;
    if (target == null || !mounted) return;

    final zoom = _cameraZoom.round();
    AppLogger.d(
      _kTag,
      'reloading lounges for lat=${target.latitude} lng=${target.longitude} zoom=$zoom',
    );
    setState(() => _loading = true);
    try {
      final client = context.read<AuthState>().gqlClient.value;
      final result = await client.query(QueryOptions(
        document: gql(GQLQueries.loungesPage(
          latitude: target.latitude,
          longitude: target.longitude,
          zoom: zoom,
        )),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (!mounted) return;

      if (result.hasException) {
        AppLogger.w(_kTag, 'loungesPage query failed', result.exception);
        setState(() {
          _loading = false;
          _error = 'Не удалось обновить список заведений';
        });
        return;
      }

      final page = LoungesPageResult.fromJson(
        result.data?['loungesPage'] as Map<String, dynamic>? ?? const {},
      );
      if (page.total > page.items.length) {
        AppLogger.w(
          _kTag,
          'loungesPage returned ${page.items.length}/${page.total} — pagination not implemented for map pins',
        );
      }
      AppLogger.i(_kTag, 'loaded ${page.items.length} lounges (total=${page.total})');
      setState(() {
        _lounges = page.items;
        _loading = false;
        _error = null;
      });
    } catch (e, st) {
      AppLogger.e(_kTag, 'unexpected error reloading lounges', e, st);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Не удалось обновить список заведений';
      });
    }
  }

  Future<Lounge?> _resolveFullLounge(String loungeId) async {
    if (_fullLoungeCache == null) {
      AppLogger.d(_kTag, 'full-lounge cache miss — fetching lounges list');
      final client = context.read<AuthState>().gqlClient.value;
      final result = await client.query(QueryOptions(
        document: gql(GQLQueries.lounges),
        fetchPolicy: FetchPolicy.cacheFirst,
      ));
      if (result.hasException) {
        AppLogger.w(_kTag, 'failed to fetch full lounges list', result.exception);
        return null;
      }
      final raw = result.data?['lounges'] as List<dynamic>? ?? [];
      _fullLoungeCache = {
        for (final e in raw)
          (e as Map<String, dynamic>)['id'] as String: Lounge.fromJson(e),
      };
      AppLogger.d(_kTag, 'full-lounge cache populated with ${_fullLoungeCache!.length} entries');
    }
    final lounge = _fullLoungeCache![loungeId];
    if (lounge == null) {
      AppLogger.w(_kTag, 'lounge $loungeId not found in full-lounge cache');
    }
    return lounge;
  }

  Future<void> _onLoungeTapped(LoungeMapItem item) async {
    if (_resolvingLounge) return;
    setState(() => _resolvingLounge = true);
    final lounge = await _resolveFullLounge(item.id);
    if (!mounted) return;
    setState(() => _resolvingLounge = false);
    if (lounge == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заведение недоступно')),
      );
      return;
    }
    _showLoungeSheet(lounge);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hookah Order'),
        actions: [
          if (_loading || _resolvingLounge)
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
      body: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              color: Colors.red.withValues(alpha: 0.1),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(child: _showList ? _buildList(_lounges) : _buildMap(_lounges)),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_showList && _userLocation != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FloatingActionButton.small(
                heroTag: 'locate',
                onPressed: () => _mapController?.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _userLocation!, zoom: 14),
                  ),
                  animation: const MapAnimation(
                      type: MapAnimationType.smooth, duration: 0.5),
                ),
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
  }

  Widget _buildMap(List<LoungeMapItem> lounges) {
    final valid =
        lounges.where((l) => l.latitude != 0 || l.longitude != 0).toList();
    final initialCenter = _userLocation ?? _kDefaultCenter;

    final mapObjects = <MapObject>[
      // маркеры кальянных
      ...valid.map(
        (l) => PlacemarkMapObject(
          opacity: l.status == 'closed' ? 0.6 : 1.0,
          mapId: MapObjectId('lounge_${l.id}'),
          point: Point(latitude: l.latitude, longitude: l.longitude),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/marker.png'),
              scale: 0.15,
            ),
          ),
          onTap: (_, __) => _onLoungeTapped(l),
        ),
      ),
      // маркер пользователя
      if (_userLocation != null)
        PlacemarkMapObject(
          mapId: const MapObjectId('user_location'),
          point: _userLocation!,
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromAssetImage('assets/marker_user.png'),
              scale: 0.5,
            ),
          ),
        ),
    ];

    return YandexMap(
      onMapCreated: (controller) {
        _mapController = controller;
        controller.moveCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: initialCenter, zoom: 12),
          ),
        );
      },
      onCameraPositionChanged: _onCameraPositionChanged,
      mapObjects: mapObjects,
    );
  }

  Widget _buildList(List<LoungeMapItem> lounges) {
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
          onTap: () => _onLoungeTapped(l),
        );
      },
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
    final hasOwner =
        lounge.ownerUserId != null && lounge.ownerUserId!.isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(lounge.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (lounge.rating != null) ...[
                const SizedBox(width: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 3),
                    Text(lounge.rating!.toStringAsFixed(1),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          _StatusChip(isOpen: isOpen),
          const SizedBox(height: 10),
          if (lounge.shortAddress != null)
            Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(lounge.shortAddress!,
                      style: const TextStyle(color: Colors.grey)),
                ),
              ],
            ),
          if (todayHours != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text('Сегодня: $todayHours',
                    style: const TextStyle(color: Colors.grey)),
              ],
            ),
          ],
          const SizedBox(height: 20),
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
                  onPressed: hasOwner
                      ? isLoggedIn
                          ? () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/order/new',
                                  arguments: lounge);
                            }
                          : () => _promptLogin(context)
                      : null,
                  child: const Text('Сделать заказ'),
                ),
              ),
            ],
          ),
          if (!hasOwner)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Заведение не подключено',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            )
          else if (!isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline, size: 13, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text('Для заказа необходима авторизация',
                      style: TextStyle(
                          fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _promptLogin(BuildContext context) {
    final nav = Navigator.of(context);
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
