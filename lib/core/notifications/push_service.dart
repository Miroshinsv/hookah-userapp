import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:meta/meta.dart';
import '../utils/logger.dart';
import 'notification_service.dart';
import 'order_push_payload.dart';

// FCM-токен гостя: получение, обновление, показ foreground-уведомлений и
// обработка тапа по push (фон/terminated — через onMessageOpenedApp и
// getInitialMessage()). Отдельный background handler не нужен: пока
// приложение свёрнуто/закрыто, системное уведомление показывает сама ОС по
// notification.title/body из payload.
class PushService {
  static const _tag = 'Push';

  static String? _token;
  static bool _initialized = false;

  // Вызывается при первом получении токена и при каждом onTokenRefresh —
  // AuthState подписывается сюда, чтобы повторно вызвать registerDevice.
  static void Function(String token)? onToken;

  // Вызывается при тапе по push (foreground onMessageOpenedApp, а также
  // запуск из terminated-состояния через getInitialMessage). PushService
  // сам не занимается навигацией/GraphQL — это подключает main.dart.
  static void Function(OrderPushPayload payload)? onOrderTap;

  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      AppLogger.w(_tag, 'notification permission denied');
    }

    try {
      final token = await messaging.getToken();
      if (token != null) {
        _token = token;
        AppLogger.d(_tag, 'token obtained ${_redact(token)}');
        onToken?.call(token);
      }
    } catch (e, stack) {
      AppLogger.w(_tag, 'getToken failed', e, stack);
    }

    messaging.onTokenRefresh.listen((token) {
      _token = token;
      AppLogger.d(_tag, 'token refreshed ${_redact(token)}');
      onToken?.call(token);
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Приложение могло быть запущено тапом по push из terminated-состояния —
    // getInitialMessage() возвращает то сообщение, если оно и было причиной запуска.
    try {
      final initial = await messaging.getInitialMessage();
      if (initial != null) {
        AppLogger.d(_tag, 'getInitialMessage found a launch message');
        _handleNotificationTap(initial);
      }
    } catch (e, stack) {
      AppLogger.w(_tag, 'getInitialMessage failed', e, stack);
    }
  }

  static String? get token => _token;

  // Тестовый хук: Firebase недоступен в модульных тестах, поэтому только так
  // можно проэмулировать наличие FCM-токена для AuthState.
  @visibleForTesting
  static void debugSetToken(String? token) => _token = token;

  static void _handleForegroundMessage(RemoteMessage message) {
    final payload = OrderPushPayload.tryParse(message.data);
    if (payload == null) {
      AppLogger.w(_tag, 'foreground push ignored — unparseable data ${message.data}');
      return;
    }
    AppLogger.d(_tag, 'foreground push parsed orderId=${payload.orderId} status=${payload.status}');
    // FCM не показывает системное уведомление сам, пока приложение активно —
    // показываем его локально готовым title/body из payload (сервер уже
    // прислал локализованный текст, на клиенте не переформулируем).
    NotificationService.showOrderStatusPush(
      orderId: payload.orderId,
      title: message.notification?.title ?? 'Обновление заказа',
      body: message.notification?.body ?? 'Статус изменён',
    );
  }

  static void _handleNotificationTap(RemoteMessage message) {
    final payload = OrderPushPayload.tryParse(message.data);
    if (payload == null) {
      AppLogger.w(_tag, 'tap ignored — unparseable data ${message.data}');
      return;
    }
    AppLogger.i(_tag, 'notification tap orderId=${payload.orderId} status=${payload.status}');
    onOrderTap?.call(payload);
  }

  static String _redact(String token) {
    if (token.length <= 6) return '***';
    return '${token.length} chars, ...${token.substring(token.length - 6)}';
  }
}
