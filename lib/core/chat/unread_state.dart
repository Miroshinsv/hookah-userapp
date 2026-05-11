import 'package:flutter/foundation.dart';

class UnreadState extends ChangeNotifier {
  // Какой orderId открыт прямо сейчас (null = чат не открыт)
  String? currentOrderId;

  final Map<String, int> _unread = {};

  int unreadFor(String orderId) => _unread[orderId] ?? 0;

  int get totalUnread => _unread.values.fold(0, (a, b) => a + b);

  // Вызывается когда пришло новое сообщение от сотрудника
  void onNewStaffMessage(String orderId) {
    if (orderId == currentOrderId) return; // пользователь уже в этом чате
    _unread[orderId] = (_unread[orderId] ?? 0) + 1;
    notifyListeners();
  }

  // Вызывается при открытии чата
  void markRead(String orderId) {
    if (_unread.containsKey(orderId)) {
      _unread.remove(orderId);
      notifyListeners();
    }
  }
}
