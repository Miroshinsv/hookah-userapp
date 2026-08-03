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
        ownerUserId
        chatEnabled
        mediaEnabled
        photos {
          id
          url
        }
        staff {
          id
          firstName
          lastName
          roles
          photoUrl
        }
      }
    }
  ''';

  static String loungesPage({
    required double latitude,
    required double longitude,
    required int zoom,
    String search = '',
    int page = 1,
    int pageSize = 200,
    bool openNow = false,
    bool is24HoursOnly = false,
    double? minRating,
    bool sortNearest = false,
  }) =>
      '''
    query {
      loungesPage(
        search: ${jsonEncode(search)},
        page: $page,
        pageSize: $pageSize,
        latitude: $latitude,
        longitude: $longitude,
        zoom: $zoom,
        openNow: $openNow,
        is24HoursOnly: $is24HoursOnly,
        minRating: ${minRating ?? 0},
        sortNearest: $sortNearest
      ) {
        items {
          id
          name
          shortAddress
          latitude
          longitude
          rating
          is24Hours
          status
          distanceKm
        }
        total
        page
        pageSize
        totalPages
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

  static String staffSchedule(String staffId) => '''
    query {
      staffSchedule(staffId: ${jsonEncode(staffId)}) {
        staffId
        loungeId
        schedule
      }
    }
  ''';

  static String loungeChatMessages(String loungeId, {int limit = 100}) => '''
    query {
      loungeChatMessages(loungeId: ${jsonEncode(loungeId)}, limit: $limit) {
        messageId
        loungeId
        senderId
        senderRole
        text
        createdAt
      }
    }
  ''';

  static String staffProfile(String staffId) => '''
    query {
      staffProfile(staffId: ${jsonEncode(staffId)}) {
        id
        userId
        firstName
        lastName
        bio
        photoUrl
        roles
        rating
        lounges {
          loungeId
          name
          shortAddress
          schedule
        }
      }
    }
  ''';

  static String hasRated(String targetType, String targetId) => '''
    query {
      hasRated(targetType: ${jsonEncode(targetType)}, targetId: ${jsonEncode(targetId)}) {
        rated
        score
      }
    }
  ''';

  static String ratingStats(String targetType, String targetId) => '''
    query {
      ratingStats(targetType: ${jsonEncode(targetType)}, targetId: ${jsonEncode(targetId)}) {
        avgRating
        count
      }
    }
  ''';

  static String feedbackRequest(String orderId) => '''
    query {
      feedbackRequest(orderId: ${jsonEncode(orderId)}) {
        requestId
        orderId
        loungeId
        message
        status
      }
    }
  ''';

  static const pendingFeedbackRequests = r'''
    query {
      pendingFeedbackRequests {
        requestId
        orderId
        loungeId
        message
        status
        createdAt
      }
    }
  ''';

  static String comments(String entityType, String entityId) => '''
    query {
      comments(entityType: ${jsonEncode(entityType)}, entityId: ${jsonEncode(entityId)}) {
        commentId
        entityType
        entityId
        userId
        text
        status
        createdAt
      }
    }
  ''';

  static String tables(String loungeId) => '''
    query {
      tables(loungeId: ${jsonEncode(loungeId)}) {
        tableId
        loungeId
        x
        y
        rotation
        seats
        label
        properties
      }
    }
  ''';

  static String activeSessions(String loungeId) => '''
    query {
      activeSessions(loungeId: ${jsonEncode(loungeId)}) {
        sessionId
        tableId
        orderId
        guestCount
        status
        openedAt
      }
    }
  ''';

  static String sessionItems({required String sessionId, required String loungeId}) => '''
    query {
      sessionItems(sessionId: ${jsonEncode(sessionId)}, loungeId: ${jsonEncode(loungeId)}) {
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

  static String menuCategories(String loungeId) => '''
    query {
      menuCategories(loungeId: ${jsonEncode(loungeId)}) {
        categoryId
        loungeId
        name
        sortOrder
      }
    }
  ''';

  static String menuItems({required String loungeId, String? categoryId}) => '''
    query {
      menuItems(loungeId: ${jsonEncode(loungeId)}${categoryId != null ? ', categoryId: ${jsonEncode(categoryId)}' : ''}) {
        itemId
        loungeId
        categoryId
        name
        price
        stopped
        available
      }
    }
  ''';

  static String tobaccos(String loungeId) => '''
    query {
      tobaccos(loungeId: ${jsonEncode(loungeId)}) {
        tobaccoId
        loungeId
        name
        strength
        price
        createdAt
        updatedAt
      }
    }
  ''';
}
