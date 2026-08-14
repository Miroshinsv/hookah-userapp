import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../auth/auth_state.dart';
import '../graphql/queries.dart';
import '../models/order.dart';
import '../navigation/navigation_service.dart';
import '../utils/logger.dart';
import 'order_push_payload.dart';

const _tag = 'PushNav';

// Чистая функция — тестируется без Firebase/виджетов.
Order? findOrderById(List<Order> orders, String orderId) {
  for (final order in orders) {
    if (order.id == orderId) return order;
  }
  return null;
}

// Реакция на тап по push/локальному уведомлению о смене статуса заказа:
// дождаться готовности навигатора, выполнить свежий запрос заказов с сервера
// (push — лишь сигнал, не источник истины) и открыть OrderDetailScreen.
Future<void> handleOrderPushTap(OrderPushPayload payload) async {
  final context = await _waitForNavigatorContext();
  if (context == null) {
    AppLogger.w(_tag, 'navigator context unavailable — dropping tap for orderId=${payload.orderId}');
    return;
  }

  // context — постоянный контекст корневого Navigator (через navigatorKey),
  // а не контекст конкретного экрана, поэтому он не "размонтируется" между
  // await — актуален, пока живо приложение.
  // ignore: use_build_context_synchronously
  final auth = context.read<AuthState>();
  if (!auth.isLoggedIn) {
    AppLogger.w(_tag, 'tap ignored — not authenticated, orderId=${payload.orderId}');
    return;
  }

  AppLogger.d(_tag, 'fetching orders to resolve tap orderId=${payload.orderId}');
  final client = auth.gqlClient.value;
  final result = await client.query(QueryOptions(
    document: gql(GQLQueries.orders),
    fetchPolicy: FetchPolicy.networkOnly,
  ));
  if (result.hasException) {
    AppLogger.w(_tag, 'orders fetch failed for tap orderId=${payload.orderId}', result.exception);
    return;
  }

  final raw = (result.data?['orders'] as List?) ?? const [];
  final orders = raw.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  final order = findOrderById(orders, payload.orderId);
  if (order == null) {
    AppLogger.w(_tag, 'order not found for tap orderId=${payload.orderId}');
    return;
  }

  final navigator = NavigationService.navigatorKey.currentState;
  if (navigator == null) {
    AppLogger.w(_tag, 'navigator state gone before navigate, orderId=${payload.orderId}');
    return;
  }
  AppLogger.i(_tag, 'navigating to order detail orderId=${payload.orderId}');
  navigator.pushNamed('/order', arguments: {'order': order});
}

// getInitialMessage() может сработать до построения дерева виджетов —
// ждём появления navigatorKey.currentContext ограниченное время вместо
// однократной проверки.
Future<BuildContext?> _waitForNavigatorContext({
  int maxAttempts = 20,
  Duration interval = const Duration(milliseconds: 200),
}) async {
  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    final context = NavigationService.navigatorKey.currentContext;
    if (context != null) return context;
    await Future.delayed(interval);
  }
  return NavigationService.navigatorKey.currentContext;
}
