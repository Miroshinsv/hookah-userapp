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

  // Реальное поле схемы бэкенда — глобальное, без аргумента orderId
  // (фильтрация по получателю — на уровне WS-соединения на сервере, не
  // GraphQL-аргументом; orderId приходит в самом payload). Только триггер:
  // сервер не заполняет id/createdAt в этом событии — настоящие значения
  // берутся только из messages()/sendMessage().
  static const newMessage = r'''
    subscription {
      newMessage {
        orderId
        senderId
        senderRole
        text
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
