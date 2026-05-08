import 'dart:convert';

class GQLMutations {
  static String registerUser(String phone, String password) => '''
    mutation {
      registerUser(phone: ${jsonEncode(phone)}, password: ${jsonEncode(password)}) {
        token
      }
    }
  ''';

  static String loginUser(String phone, String password) => '''
    mutation {
      loginUser(phone: ${jsonEncode(phone)}, password: ${jsonEncode(password)}) {
        token
        role
        loungeId
      }
    }
  ''';

  static String createOrder({
    required String loungeId,
    required String flavor,
    String? comment,
    required String phone,
    required String arrivalAt,
  }) => '''
    mutation {
      createOrder(
        loungeId: ${jsonEncode(loungeId)}
        flavor: ${jsonEncode(flavor)}
        ${comment != null ? 'comment: ${jsonEncode(comment)}' : ''}
        phone: ${jsonEncode(phone)}
        arrivalAt: ${jsonEncode(arrivalAt)}
      ) {
        id
        status
      }
    }
  ''';

  static String sendMessage(String orderId, String text) => '''
    mutation {
      sendMessage(orderId: ${jsonEncode(orderId)}, text: ${jsonEncode(text)}) {
        id
        createdAt
      }
    }
  ''';
}
