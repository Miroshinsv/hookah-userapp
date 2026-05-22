import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_state.dart';
import '../core/chat/unread_state.dart';
import '../core/update/update_dialog.dart';
import '../core/update/update_service.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    final release = await UpdateService.checkForUpdate();
    if (release != null && mounted) {
      await showUpdateDialog(context, release);
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
      body: Column(
        children: [
          if (auth.isOffline)
            Container(
              color: const Color(0xFF8B1A1A),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi_off, size: 14, color: Colors.white70),
                  SizedBox(width: 6),
                  Text(
                    'Нет подключения к сети',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
          Expanded(child: IndexedStack(index: _index, children: tabs)),
        ],
      ),
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
