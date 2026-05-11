import 'dart:async';
import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'core/auth/auth_state.dart';
import 'core/chat/unread_state.dart';
import 'core/notifications/notification_service.dart';
import 'core/utils/logger.dart';
import 'screens/splash_screen.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/main_screen.dart';
import 'screens/lounge/lounge_detail_screen.dart';
import 'screens/order/new_order_screen.dart';
import 'screens/order/order_detail_screen.dart';

// Цветовая палитра
const kBgDark   = Color(0xFF1A0E05);
const kBgCard   = Color(0xFF2A1A0A);
const kGold     = Color(0xFFC9A84C);
const kGoldLight = Color(0xFFE6C364);
const kCream    = Color(0xFFF5E6D0);

ThemeData _buildTheme() {
  const cs = ColorScheme(
    brightness: Brightness.dark,
    primary:    kGold,
    onPrimary:  kBgDark,
    secondary:  kGoldLight,
    onSecondary: kBgDark,
    surface:    kBgCard,
    onSurface:  kCream,
    error:      Color(0xFFCF6679),
    onError:    Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: kBgDark,
    appBarTheme: const AppBarTheme(
      backgroundColor: kBgDark,
      foregroundColor: kCream,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: kGold,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: kBgCard,
      indicatorColor: const Color.fromRGBO(201, 168, 76, 0.2),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: kGold);
        }
        return const IconThemeData(color: Color(0xFF8A7060));
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(color: kGold, fontSize: 12);
        }
        return const TextStyle(color: Color(0xFF8A7060), fontSize: 12);
      }),
    ),
    cardTheme: const CardThemeData(
      color: kBgCard,
      surfaceTintColor: Colors.transparent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: kGold,
        foregroundColor: kBgDark,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: kBgCard,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A3020)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF4A3020)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kGold, width: 1.5),
      ),
      labelStyle: const TextStyle(color: Color(0xFF8A7060)),
      prefixIconColor: kGold,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: kGold,
      unselectedLabelColor: Color(0xFF8A7060),
      indicatorColor: kGold,
    ),
    dividerTheme: const DividerThemeData(color: Color(0xFF3A2A18)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: kGold),
    chipTheme: const ChipThemeData(
      backgroundColor: kBgCard,
      labelStyle: TextStyle(color: kCream),
      side: BorderSide(color: Color(0xFF4A3020)),
    ),
    textTheme: const TextTheme(
      headlineMedium: TextStyle(color: kCream, fontWeight: FontWeight.bold),
      titleMedium:    TextStyle(color: kCream),
      bodyMedium:     TextStyle(color: kCream),
      bodySmall:      TextStyle(color: Color(0xFFAA9070)),
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.e('Flutter', details.exceptionAsString(), details.exception, details.stack);
  };

  runZonedGuarded(
    () async {
      await NotificationService.init();
      runApp(const App());
    },
    (error, stack) => AppLogger.e('Zone', error.toString(), error, stack),
  );
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final AuthState _authState = AuthState();
  final UnreadState _unreadState = UnreadState();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _authState),
        ChangeNotifierProvider.value(value: _unreadState),
      ],
      child: GraphQLProvider(
        client: _authState.gqlClient,
        child: MaterialApp(
          title: 'Hookah Order',
          debugShowCheckedModeBanner: false,
          theme: _buildTheme(),
          initialRoute: '/',
          routes: {
            '/': (_) => const SplashScreen(),
            '/auth': (_) => const AuthScreen(),
            '/main': (_) => const MainScreen(),
            '/lounge': (_) => const LoungeDetailScreen(),
            '/order/new': (_) => const NewOrderScreen(),
            '/order': (_) => const OrderDetailScreen(),
          },
        ),
      ),
    );
  }
}
