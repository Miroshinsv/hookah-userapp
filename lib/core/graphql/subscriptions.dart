class GQLSubscriptions {
  static const orderStatusChanged = r'''
    subscription {
      orderStatusChanged {
        id
        status
      }
    }
  ''';
}
