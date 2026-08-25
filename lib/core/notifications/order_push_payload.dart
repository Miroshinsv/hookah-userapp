// Разбор data-payload push-уведомления о заказе (FCM). Бэкенд шлёт
// eventType/orderId/loungeId/status строками для двух типов событий:
// смена статуса заказа (order_status_updated) и новое сообщение персонала
// в чате заказа (new_message — текста в data нет, он только в
// notification.title/body). Сюда не должны попадать события смены статуса
// отдельных позиций заказа — сервер их не отправляет как push, но на всякий
// случай неизвестные eventType молча игнорируются, а не приводят к ошибке.
class OrderPushPayload {
  static const _orderStatusUpdatedEvent = 'order_status_updated';
  static const _newMessageEvent = 'new_message';

  final String orderId;
  final String? loungeId;
  final String? status;
  final bool isChatMessage;

  const OrderPushPayload({
    required this.orderId,
    this.loungeId,
    this.status,
    this.isChatMessage = false,
  });

  static OrderPushPayload? tryParse(Map<String, dynamic> data) {
    final eventType = data['eventType'];
    if (eventType != _orderStatusUpdatedEvent && eventType != _newMessageEvent) {
      return null;
    }

    final orderId = data['orderId'] as String?;
    if (orderId == null || orderId.isEmpty) return null;

    return OrderPushPayload(
      orderId: orderId,
      loungeId: data['loungeId'] as String?,
      status: data['status'] as String?,
      isChatMessage: eventType == _newMessageEvent,
    );
  }
}
