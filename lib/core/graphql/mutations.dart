import 'dart:convert';
import '../models/hookah_template.dart';

class GQLMutations {
  // Бэкенд больше не принимает номер телефона в открытом виде для этих
  // мутаций — phoneHash/phoneLast4/phoneMock вычисляются на клиенте через
  // core/utils/phone_hash.dart (PhoneHash), сервер сам домешивает секретный
  // pepper при выводе identity-ключа.
  static String registerUser({
    required String phoneHash,
    required String phoneLast4,
    required String phoneMock,
    required String password,
  }) => '''
    mutation {
      registerUser(
        phoneHash: ${jsonEncode(phoneHash)}
        phoneLast4: ${jsonEncode(phoneLast4)}
        phoneMock: ${jsonEncode(phoneMock)}
        password: ${jsonEncode(password)}
      ) {
        token
        role
      }
    }
  ''';

  static String loginUser({required String phoneHash, required String password}) => '''
    mutation {
      loginUser(phoneHash: ${jsonEncode(phoneHash)}, password: ${jsonEncode(password)}) {
        token
        role
        loungeId
      }
    }
  ''';

  static String createOrder({
    required String loungeId,
    List<HookahItemInput> hookahItems = const [],
    String? comment,
    required String phoneLast4,
    required String phoneMock,
    required String arrivalAt,
    String? tableId,
    int? guestCount,
  }) => '''
    mutation {
      createOrder(
        loungeId: ${jsonEncode(loungeId)}
        ${hookahItems.isNotEmpty ? 'hookahItems: [${hookahItems.map((h) => h.toGraphQL()).join(', ')}]' : ''}
        ${comment != null ? 'comment: ${jsonEncode(comment)}' : ''}
        phoneLast4: ${jsonEncode(phoneLast4)}
        phoneMock: ${jsonEncode(phoneMock)}
        arrivalAt: ${jsonEncode(arrivalAt)}
        ${tableId != null ? 'tableId: ${jsonEncode(tableId)}' : ''}
        ${tableId != null && guestCount != null ? 'guestCount: $guestCount' : ''}
      ) {
        id
        status
        tableId
        tableLabel
        tableSeatConflict
        hookahItems { id name flavor source templateId strength comment quantity unitPrice status }
        subtotal
        finalTotal
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
  }) => '''
    mutation {
      submitFeedback(
        orderId: ${jsonEncode(orderId)}
        loungeId: ${jsonEncode(loungeId)}
        score: $score
        ${comment != null ? 'comment: ${jsonEncode(comment)}' : ''}
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

  // Выбор/повторный выбор стола гостем для уже созданного заказа
  // (sitplace.txt). `failIfOccupied` захардкожен в `true` и никогда не
  // выставляется вызывающим кодом — это обязательное условие безопасного
  // гостевого флоу ("не отбирать место у другого гостя"), ослаблять нельзя.
  static String openTableSession({
    required String tableId,
    required String loungeId,
    required String orderId,
    required int guestCount,
  }) => '''
    mutation {
      openTableSession(
        tableId: ${jsonEncode(tableId)}
        loungeId: ${jsonEncode(loungeId)}
        orderId: ${jsonEncode(orderId)}
        guestCount: $guestCount
        failIfOccupied: true
      ) {
        sessionId
        tableId
        status
      }
    }
  ''';

  // Дозаказ позиций меню и/или кальяна в уже существующий заказ (order.txt
  // раздел 3, hook.txt). Один элемент menuItems на вызов — соответствует
  // однопозиционному UX showMenuItemPicker (тот же паттерн, что и
  // addSessionItem); hookahItems — от showHookahItemPicker, тоже один
  // элемент на вызов.
  static String addOrderItems({
    required String orderId,
    required String loungeId,
    String? menuItemId,
    int quantity = 1,
    List<HookahItemInput> hookahItems = const [],
  }) => '''
    mutation {
      addOrderItems(
        orderId: ${jsonEncode(orderId)}
        loungeId: ${jsonEncode(loungeId)}
        ${menuItemId != null ? 'menuItems: [{ menuItemId: ${jsonEncode(menuItemId)}, quantity: $quantity }]' : ''}
        ${hookahItems.isNotEmpty ? 'hookahItems: [${hookahItems.map((h) => h.toGraphQL()).join(', ')}]' : ''}
      ) {
        id
        status
        menuItems { id menuItemId name quantity unitPrice status }
        hookahItems { id name flavor source templateId strength comment quantity unitPrice status }
        subtotal
        finalTotal
      }
    }
  ''';

  // flavor здесь обязателен на бэкенде (String!, без default) несмотря на
  // то что пример в hook.txt его не передаёт — реальная схема (проверено
  // интроспекцией) требует аргумент. Это top-level поле превью-цены, не
  // связано с HookahItemOrderInput.flavor и не влияет на саму позицию —
  // шлём пустую строку.
  static String priceCustomHookah({
    required String loungeId,
    required int strength,
    String? fillingPropertyId,
    List<TobaccoLineInput> tobaccos = const [],
    List<String> additionalPropertyIds = const [],
  }) => '''
    mutation {
      priceCustomHookah(
        loungeId: ${jsonEncode(loungeId)}
        strength: $strength
        flavor: ""
        ${fillingPropertyId != null ? 'fillingPropertyId: ${jsonEncode(fillingPropertyId)}' : ''}
        ${tobaccos.isNotEmpty ? 'tobaccos: [${tobaccos.map((t) => t.toGraphQL()).join(', ')}]' : ''}
        ${additionalPropertyIds.isNotEmpty ? 'additionalPropertyIds: [${additionalPropertyIds.map(jsonEncode).join(', ')}]' : ''}
      ) {
        totalPrice
        filling { name price }
        additionalProperties { name price }
      }
    }
  ''';
}
