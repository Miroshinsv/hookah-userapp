import 'dart:convert';

class GQLMutations {
  static String registerUser(
    String phone,
    String password, {
    String? firstName,
    String? lastName,
  }) => '''
    mutation {
      registerUser(
        phone: ${jsonEncode(phone)}
        password: ${jsonEncode(password)}
        ${firstName != null && firstName.isNotEmpty ? 'firstName: ${jsonEncode(firstName)}' : ''}
        ${lastName != null && lastName.isNotEmpty ? 'lastName: ${jsonEncode(lastName)}' : ''}
      ) {
        token
        role
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
    String? firstName,
    String? lastName,
    required String arrivalAt,
  }) => '''
    mutation {
      createOrder(
        loungeId: ${jsonEncode(loungeId)}
        flavor: ${jsonEncode(flavor)}
        ${comment != null ? 'comment: ${jsonEncode(comment)}' : ''}
        phone: ${jsonEncode(phone)}
        ${firstName != null && firstName.isNotEmpty ? 'firstName: ${jsonEncode(firstName)}' : ''}
        ${lastName != null && lastName.isNotEmpty ? 'lastName: ${jsonEncode(lastName)}' : ''}
        arrivalAt: ${jsonEncode(arrivalAt)}
      ) {
        id
        status
      }
    }
  ''';

  static String updateUser({
    required String staffId,
    String? firstName,
    String? lastName,
  }) => '''
    mutation {
      updateStaff(
        staffId: ${jsonEncode(staffId)}
        ${firstName != null ? 'firstName: ${jsonEncode(firstName)}' : ''}
        ${lastName != null ? 'lastName: ${jsonEncode(lastName)}' : ''}
      ) {
        firstName
        lastName
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

  static String sendLoungeChatMessage(String loungeId, String text) => '''
    mutation {
      sendLoungeChatMessage(loungeId: ${jsonEncode(loungeId)}, text: ${jsonEncode(text)}) {
        messageId
        createdAt
      }
    }
  ''';

  static String rateLounge(String loungeId, int score) => '''
    mutation {
      rateLounge(loungeId: ${jsonEncode(loungeId)}, score: $score) {
        ratingId
        avgRating
        count
      }
    }
  ''';

  static String rateStaff(String staffId, int score) => '''
    mutation {
      rateStaff(staffId: ${jsonEncode(staffId)}, score: $score) {
        ratingId
        avgRating
        count
      }
    }
  ''';

  static String createComment(
          String entityType, String entityId, String text) =>
      '''
    mutation {
      createComment(
        entityType: ${jsonEncode(entityType)}
        entityId: ${jsonEncode(entityId)}
        text: ${jsonEncode(text)}
      ) {
        commentId
        status
      }
    }
  ''';

  static String submitFeedback({
    required String orderId,
    required String loungeId,
    required int score,
    String? comment,
    String? firstName,
    String? lastName,
  }) => '''
    mutation {
      submitFeedback(
        orderId: ${jsonEncode(orderId)}
        loungeId: ${jsonEncode(loungeId)}
        score: $score
        ${comment != null ? 'comment: ${jsonEncode(comment)}' : ''}
        ${firstName != null && firstName.isNotEmpty ? 'firstName: ${jsonEncode(firstName)}' : ''}
        ${lastName != null && lastName.isNotEmpty ? 'lastName: ${jsonEncode(lastName)}' : ''}
      ) {
        feedbackId
      }
    }
  ''';

  static String cancelFeedbackRequest(String orderId) => '''
    mutation {
      cancelFeedbackRequest(orderId: ${jsonEncode(orderId)})
    }
  ''';

  static String registerDevice({required String fcmToken, String? loungeId}) => '''
    mutation {
      registerDevice(
        fcmToken: ${jsonEncode(fcmToken)}
        ${loungeId != null ? 'loungeId: ${jsonEncode(loungeId)}' : ''}
      )
    }
  ''';

  static String unregisterDevice(String fcmToken) => '''
    mutation {
      unregisterDevice(fcmToken: ${jsonEncode(fcmToken)})
    }
  ''';

  static String addSessionItem({
    required String sessionId,
    required String loungeId,
    required String menuItemId,
    int quantity = 1,
  }) => '''
    mutation {
      addSessionItem(
        sessionId: ${jsonEncode(sessionId)}
        loungeId: ${jsonEncode(loungeId)}
        menuItemId: ${jsonEncode(menuItemId)}
        quantity: $quantity
      ) {
        itemId
        sessionId
        loungeId
        menuItemId
        name
        price
        quantity
        status
        createdAt
      }
    }
  ''';
}
