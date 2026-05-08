import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_state.dart';
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
    final tabs = <Widget>[
      const MapScreen(),
      const OrdersScreen(),
      auth.isLoggedIn
          ? const ProfileScreen()
          : const AuthScreen(embedded: true),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Карта',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Заказы',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
