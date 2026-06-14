import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_state.dart';
import '../core/chat/unread_state.dart';
import '../core/graphql/queries.dart';
import '../core/models/lounge.dart';
import '../core/models/order.dart';
import '../core/update/update_dialog.dart';
import '../core/update/update_service.dart';
import '../widgets/feedback_sheet.dart';
import 'auth/auth_screen.dart';
import 'map/map_screen.dart';
import 'orders/orders_screen.dart';
import 'profile/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;
  final _ordersKey = GlobalKey<OrdersScreenState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _checkUpdate();
      await _checkPendingFeedback();
    });
  }

  Future<void> _checkUpdate() async {
    final release = await UpdateService.checkForUpdate();
    if (release != null && mounted) {
      await showUpdateDialog(context, release);
    }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}'
          ' ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  // При запуске приложения показывает запросы отзыва (status == 'new'),
  // оставшиеся неотвеченными с прошлых сессий.
  Future<void> _checkPendingFeedback() async {
    final auth = context.read<AuthState>();
    if (!auth.isLoggedIn) return;
    final client = auth.gqlClient.value;

    final reqResult = await client.query(QueryOptions(
      document: gql(GQLQueries.pendingFeedbackRequests),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted || reqResult.hasException) return;
    final requests = (reqResult.data?['pendingFeedbackRequests'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>()
        .where((r) => r['status'] == 'new')
        .toList();
    if (requests.isEmpty) return;

    final loungesResult = await client.query(QueryOptions(
      document: gql(GQLQueries.lounges),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    final lounges = {
      for (final e in loungesResult.data?['lounges'] as List<dynamic>? ?? [])
        (e as Map<String, dynamic>)['id'] as String: Lounge.fromJson(e),
    };

    final ordersResult = await client.query(QueryOptions(
      document: gql(GQLQueries.orders),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    final orders = {
      for (final e in ordersResult.data?['orders'] as List<dynamic>? ?? [])
        (e as Map<String, dynamic>)['id'] as String: Order.fromJson(e),
    };

    for (final req in requests) {
      if (!mounted) return;
      final loungeId = req['loungeId'] as String? ?? '';
      final orderId = req['orderId'] as String? ?? '';
      final lounge = lounges[loungeId];
      if (lounge == null) continue;
      final order = orders[orderId];
      final orderTime =
          order?.arrivalAt != null ? _formatDateTime(order!.arrivalAt!) : null;

      await showFeedbackSheet(
        context,
        client: client,
        title: req['message'] as String? ?? 'Заказ завершён',
        loungeName: lounge.name,
        loungeId: lounge.id,
        orderId: orderId,
        orderTime: orderTime,
        firstName: auth.firstName,
        lastName: auth.lastName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();
    final totalUnread = context.watch<UnreadState>().totalUnread;

    final tabs = <Widget>[
      const MapScreen(),
      OrdersScreen(key: _ordersKey),
      auth.isLoggedIn
          ? const ProfileScreen()
          : const AuthScreen(embedded: true),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) {
          if (i == 1) _ordersKey.currentState?.refresh();
          setState(() => _index = i);
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Карта',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: totalUnread > 0,
              label: Text('$totalUnread'),
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: totalUnread > 0,
              label: Text('$totalUnread'),
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Заказы',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
