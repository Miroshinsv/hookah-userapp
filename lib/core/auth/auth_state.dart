import 'package:flutter/foundation.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../storage/storage.dart';
import '../utils/jwt_helper.dart';

class _LoggingLink extends Link {
  @override
  Stream<Response> request(Request request, [NextLink? forward]) {
    final op = request.operation.operationName ?? 'anonymous';
    final vars = request.variables;
    debugPrint('[GQL ▶] $op vars=$vars');

    return forward!(request).map((response) {
      if (response.errors != null && response.errors!.isNotEmpty) {
        debugPrint('[GQL ✗] $op errors=${response.errors}');
      } else {
        debugPrint('[GQL ◀] $op data=${response.data}');
      }
      return response;
    });
  }
}

class AuthState extends ChangeNotifier {
  final AppStorage _storage = AppStorage();
  late final ValueNotifier<GraphQLClient> gqlClient;

  String? _token;
  String? _phone;
  String? _role;
  String? _loungeId;

  AuthState() {
    gqlClient = ValueNotifier(_buildClient(null));
  }

  bool get isLoggedIn => _token != null;
  String? get token => _token;
  String? get phone => _phone;
  String? get role => _role;
  String? get loungeId => _loungeId;

  Future<void> init() async {
    final token = await _storage.readToken();
    if (token != null && !JwtHelper.isExpired(token)) {
      _token = token;
      _phone = JwtHelper.getPhone(token);
      gqlClient.value = _buildClient(token);
      notifyListeners();
    }
  }

  Future<void> login(String token, {String? role, String? loungeId}) async {
    await _storage.writeToken(token);
    _token = token;
    _phone = JwtHelper.getPhone(token);
    _role = role;
    _loungeId = loungeId;
    gqlClient.value = _buildClient(token);
    notifyListeners();
  }

  Future<void> logout() async {
    await _storage.deleteToken();
    _token = null;
    _phone = null;
    _role = null;
    _loungeId = null;
    gqlClient.value = _buildClient(null);
    notifyListeners();
  }

  static GraphQLClient _buildClient(String? token) {
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
      _LoggingLink().concat(authLink.concat(httpLink)),
    );
    return GraphQLClient(
      link: link,
      cache: GraphQLCache(store: InMemoryStore()),
    );
  }
}
