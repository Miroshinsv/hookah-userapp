import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../graphql/logging_link.dart';
import '../graphql/mutations.dart';
import '../graphql/queries.dart';
import '../notifications/push_service.dart';
import '../storage/storage.dart';
import '../utils/jwt_helper.dart';
import '../utils/logger.dart';

class AuthState extends ChangeNotifier {
  final AppStorage _storage = AppStorage();
  late final ValueNotifier<GraphQLClient> gqlClient;

  String? _token;
  String? _phone;
  String? _role;
  String? _loungeId;
  String? _staffId;
  String? _firstName;
  String? _lastName;

  AuthState() {
    gqlClient = ValueNotifier(_buildClient(null));
    // Токен может обновиться, пока гость уже залогинен — перерегистрируем
    // устройство на бэкенде с новым токеном.
    PushService.onToken = (_) => _registerDeviceBestEffort();
  }

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get phone => _phone;
  String? get role => _role;
  String? get loungeId => _loungeId;
  String? get staffId => _staffId;
  String? get firstName => _firstName;
  String? get lastName => _lastName;

  static const _tag = 'Auth';

  Future<void> init() async {
    final token = await _storage.readToken();
    if (token != null && !JwtHelper.isExpired(token)) {
      _token     = token;
      _phone     = JwtHelper.getPhone(token);
      _staffId   = await _storage.readStaffId();
      _firstName = await _storage.readFirstName();
      _lastName  = await _storage.readLastName();
      gqlClient.value = _buildClient(token, onUnauthenticated: _handleUnauthenticated);
      AppLogger.i(_tag, 'restored session phone=$_phone');
      notifyListeners();
      await fetchMe();
      await _registerDeviceBestEffort();
    } else {
      if (token != null) {
        AppLogger.w(_tag, 'stored token is expired — clearing');
        await _storage.deleteToken();
      } else {
        AppLogger.i(_tag, 'no valid token');
      }
    }
  }

  Future<void> login(
    String token, {
    String? role,
    String? loungeId,
    String? staffId,
    String? firstName,
    String? lastName,
  }) async {
    await _storage.writeToken(token);
    _token    = token;
    _phone    = JwtHelper.getPhone(token);
    _role     = role;
    _loungeId = loungeId;
    if (staffId != null) {
      _staffId = staffId;
      await _storage.writeStaffId(staffId);
    }
    if (firstName != null) {
      _firstName = firstName.isEmpty ? null : firstName;
      await _storage.writeFirstName(firstName);
    }
    if (lastName != null) {
      _lastName = lastName.isEmpty ? null : lastName;
      await _storage.writeLastName(lastName);
    }
    gqlClient.value = _buildClient(token, onUnauthenticated: _handleUnauthenticated);
    AppLogger.i(_tag, 'login phone=$_phone role=$_role');
    notifyListeners();
    await fetchMe();
    await _registerDeviceBestEffort();
  }

  // Best-effort: регистрация FCM-токена гостя на бэкенде. Никогда не должна
  // блокировать или ронять login()/init() — ошибки только логируются.
  Future<void> _registerDeviceBestEffort() async {
    if (!isLoggedIn) return;
    final fcmToken = PushService.token;
    if (fcmToken == null) return;
    try {
      final result = await gqlClient.value.mutate(MutationOptions(
        document: gql(GQLMutations.registerDevice(fcmToken: fcmToken, loungeId: _loungeId)),
      ));
      if (result.hasException) {
        AppLogger.w(_tag, 'registerDevice failed', result.exception);
        return;
      }
      AppLogger.i(_tag, 'registerDevice ok loungeId=$_loungeId');
    } catch (e, stack) {
      AppLogger.w(_tag, 'registerDevice failed', e, stack);
    }
  }

  Future<void> fetchMe() async {
    try {
      final result = await gqlClient.value.query(QueryOptions(
        document: gql(GQLQueries.me),
        fetchPolicy: FetchPolicy.networkOnly,
      ));
      if (result.hasException || result.data == null) {
        AppLogger.w(_tag, 'fetchMe error', result.exception);
        return;
      }
      final me = result.data!['me'] as Map<String, dynamic>?;
      if (me == null) return;

      final staffId   = me['id'] as String?;
      final firstName = me['firstName'] as String?;
      final lastName  = me['lastName'] as String?;

      if (staffId != null) {
        _staffId = staffId;
        await _storage.writeStaffId(staffId);
      }
      _firstName = (firstName?.isEmpty ?? true) ? null : firstName;
      _lastName  = (lastName?.isEmpty ?? true) ? null : lastName;
      await _storage.writeFirstName(_firstName ?? '');
      await _storage.writeLastName(_lastName ?? '');

      AppLogger.i(_tag, 'fetchMe ok firstName=$_firstName lastName=$_lastName');
      notifyListeners();
    } catch (e, stack) {
      AppLogger.w(_tag, 'fetchMe failed', e, stack);
    }
  }

  Future<void> updateProfile({String? firstName, String? lastName}) async {
    _firstName = firstName?.isEmpty == true ? null : firstName;
    _lastName  = lastName?.isEmpty == true ? null : lastName;
    await _storage.writeFirstName(_firstName ?? '');
    await _storage.writeLastName(_lastName ?? '');
    AppLogger.i(_tag, 'profile updated firstName=$_firstName lastName=$_lastName');
    notifyListeners();
  }

  Future<void> logout() async {
    AppLogger.i(_tag, 'logout phone=$_phone');
    await _unregisterDeviceBestEffort();
    await _storage.deleteToken();
    await _storage.deleteNames();
    _token     = null;
    _phone     = null;
    _role      = null;
    _loungeId  = null;
    _staffId   = null;
    _firstName = null;
    _lastName  = null;
    gqlClient.value = _buildClient(null);
    notifyListeners();
  }

  // Best-effort: unregisterDevice не требует авторизации, поэтому безопасно
  // вызывать даже если токен на сервере уже недействителен. Никогда не
  // должна блокировать logout() — ошибки только логируются.
  Future<void> _unregisterDeviceBestEffort() async {
    final fcmToken = PushService.token;
    if (fcmToken == null) return;
    try {
      final result = await gqlClient.value.mutate(MutationOptions(
        document: gql(GQLMutations.unregisterDevice(fcmToken)),
      ));
      if (result.hasException) {
        AppLogger.w(_tag, 'unregisterDevice failed', result.exception);
        return;
      }
      AppLogger.i(_tag, 'unregisterDevice ok');
    } catch (e, stack) {
      AppLogger.w(_tag, 'unregisterDevice failed', e, stack);
    }
  }

  void _handleUnauthenticated() {
    if (_token == null) return; // уже разлогинены
    AppLogger.w(_tag, 'server rejected token — forcing logout');
    logout();
  }

  static GraphQLClient _buildClient(String? token, {VoidCallback? onUnauthenticated}) {
    const httpUrl = 'https://api.hookahorder.ru/graphql';
    const wsUrl = 'wss://api.hookahorder.ru/graphql/subscribe';

    final httpLink = HttpLink(httpUrl);
    final authLink = AuthLink(
      getToken: () => token != null ? 'Bearer $token' : null,
    );
    final wsLink = WebSocketLink(
      wsUrl,
      config: SocketClientConfig(
        autoReconnect: true,
        initialPayload: token != null ? {'authorization': 'Bearer $token'} : null,
      ),
      subProtocol: GraphQLProtocol.graphqlTransportWs,
    );
    final link = Link.split(
      (request) => request.isSubscription,
      wsLink,
      LoggingLink(
        onUnauthenticated: onUnauthenticated,
        getToken: token != null ? () => token : null,
      ).concat(authLink.concat(httpLink)),
    );
    return GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    );
  }
}
