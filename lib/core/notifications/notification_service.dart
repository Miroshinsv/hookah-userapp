import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/logger.dart';
import '../utils/status_helper.dart';

class NotificationService {
  static const _tag = 'Notify';
  static const _channelId = 'chat_messages';
  static const _channelName = 'Сообщения в чате';
  static const _statusChannelId = 'order_status';
  static const _statusChannelName = 'Статус заказа';

  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    // Запрос разрешения на Android 13+
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
    AppLogger.i(_tag, 'initialized');
  }

  static Future<void> showChatMessage({
    required String orderId,
    required String text,
  }) async {
    if (!_initialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      await _plugin.show(
        orderId.hashCode,
        'Новое сообщение',
        text,
        details,
      );
    } catch (e) {
      AppLogger.w(_tag, 'show failed', e);
    }
  }

  static Future<void> showStatusChanged({
    required String orderId,
    required String newStatus,
  }) async {
    if (!_initialized) return;
    try {
      const androidDetails = AndroidNotificationDetails(
        _statusChannelId,
        _statusChannelName,
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );
      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );
      final label = StatusHelper.localize(newStatus);
      await _plugin.show(
        ('status_$orderId').hashCode,
        'Статус заказа изменён',
        'Заказ #$orderId: $label',
        details,
      );
    } catch (e) {
      AppLogger.w(_tag, 'showStatusChanged failed', e);
    }
  }
}
