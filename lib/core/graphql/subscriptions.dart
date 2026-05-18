import 'dart:convert';

class GQLSubscriptions {
  static const orderStatusChanged = r'''
    subscription {
      orderStatusChanged {
        id
        status
      }
    }
  ''';

  // Все новые сообщения для заказов текущего пользователя (orderId в ответе)
  static const messageCreated = r'''
    subscription {
      messageCreated {
        id
        orderId
        senderId
        senderRole
        text
        createdAt
      }
    }
  ''';

  // Сообщения для конкретного заказа (без orderId в ответе)
  static String messageCreatedForOrder(String orderId) => '''
    subscription {
      messageCreated(orderId: ${jsonEncode(orderId)}) {
        id
        senderId
        senderRole
        text
        createdAt
      }
    }
  ''';

  static String newLoungeChatMessage(String loungeId) => '''
    subscription {
      newLoungeChatMessage(loungeId: ${jsonEncode(loungeId)}) {
        messageId
        loungeId
        senderId
        senderRole
        text
        createdAt
      }
    }
  ''';
}
