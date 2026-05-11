import 'dart:convert';

class GQLQueries {
  static const me = r'''
    query {
      me {
        id
        userId
        firstName
        lastName
        roles
      }
    }
  ''';

  static const lounges = r'''
    query {
      lounges {
        id
        name
        description
        schedule
        rating
        shortAddress
        phone
        latitude
        longitude
        staff {
          id
          firstName
          lastName
          roles
        }
      }
    }
  ''';

  // limit hardcoded — переменные не нужны
  static const orders = r'''
    query {
      orders(limit: 50) {
        id
        loungeId
        flavor
        comment
        phone
        firstName
        lastName
        arrivalAt
        status
        createdAt
      }
    }
  ''';

  static String messages(String orderId) => '''
    query {
      messages(orderId: ${jsonEncode(orderId)}) {
        id
        senderId
        senderRole
        text
        createdAt
      }
    }
  ''';
}
