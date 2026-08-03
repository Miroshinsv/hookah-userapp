import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:meta/meta.dart';
import '../utils/logger.dart';

// FCM-токен гостя: получение, обновление и обработка foreground-сообщений.
// Фоновые/закрытые состояния приложения показываются системой автоматически
// по payload уведомления — отдельный background handler здесь не нужен.
class PushService {
  static const _tag = 'Push';

  static String? _token;
  static bool _initialized = false;

  // Вызывается при первом получении токена и при каждом onTokenRefresh —
  // AuthState подписывается сюда, чтобы повторно вызвать registerDevice.
  static void Function(String token)? onToken;

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
  }

  static String? get token => _token;

  // Тестовый хук: Firebase недоступен в модульных тестах, поэтому только так
  // можно проэмулировать наличие FCM-токена для AuthState.
  @visibleForTesting
  static void debugSetToken(String? token) => _token = token;

  static void _handleForegroundMessage(RemoteMessage message) {
    AppLogger.i(
      _tag,
      'foreground message type=${message.data['type']} orderId=${message.data['orderId']}',
    );
    // Статус заказа и чат уже приходят и отображаются через существующие
    // WebSocket-подписки (orderStatusChanged) пока приложение открыто — не
    // показываем локальное уведомление здесь повторно, иначе получится дубль.
    // Push — дублирующий канал именно для свёрнутого/закрытого приложения.
  }

  static String _redact(String token) {
    if (token.length <= 6) return '***';
    return '${token.length} chars, ...${token.substring(token.length - 6)}';
  }
}
