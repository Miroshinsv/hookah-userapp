import 'package:flutter/material.dart';

// Глобальный доступ к Navigator/BuildContext вне дерева виджетов — нужен,
// чтобы обработчики тапа по push-уведомлению (FirebaseMessaging.onMessageOpenedApp,
// getInitialMessage(), локальные уведомления) могли выполнить навигацию и
// получить BuildContext для чтения AuthState/GraphQLProvider.
class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}
