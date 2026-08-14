// Разбор data-payload push-уведомления о смене статуса заказа (FCM).
// Бэкенд шлёт eventType/orderId/loungeId/status строками; сюда не должны
// попадать события смены статуса отдельных позиций заказа — сервер их не
// отправляет как push, но на всякий случай неизвестные eventType молча
// игнорируются, а не приводят к ошибке.
class OrderPushPayload {
  static const _orderStatusUpdatedEvent = 'order_status_updated';

  final String orderId;
  final String? loungeId;
  final String? status;

  const OrderPushPayload({
    required this.orderId,
    this.loungeId,
    this.status,
  });

  static OrderPushPayload? tryParse(Map<String, dynamic> data) {
    if (data['eventType'] != _orderStatusUpdatedEvent) return null;

    final orderId = data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return null;

    return OrderPushPayload(
      orderId: orderId,
      loungeId: data['loungeId'] as String?,
      status: data['status'] as String?,
    );
  }
}
