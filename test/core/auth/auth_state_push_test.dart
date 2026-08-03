import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/core/auth/auth_state.dart';
import 'package:user_app/core/notifications/push_service.dart';

class MockGraphQLClient extends Mock implements GraphQLClient {}

// login()/init() rebuild a fresh real GraphQLClient before calling
// registerDevice, so they can't be exercised against a mock without
// refactoring AuthState's client construction (out of scope here). logout()
// does not rebuild the client before calling unregisterDevice, so it is the
// one push-wiring path that's cleanly testable against a mock — and it
// shares the exact same try/catch/early-return shape as the register path.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(MutationOptions(document: gql('mutation { noop }')));

    // logout() clears stored auth state via flutter_secure_storage, which has
    // no platform implementation in a plain unit test — stub its channel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
      (call) async => null,
    );
  });

  tearDown(() {
    PushService.debugSetToken(null);
  });

  test('logout() completes and clears session even when unregisterDevice fails', () async {
    PushService.debugSetToken('fake-fcm-token');

    final authState = AuthState();
    final mockClient = MockGraphQLClient();
    final options = MutationOptions(document: gql('mutation { unregisterDevice }'));
    when(() => mockClient.mutate(any())).thenAnswer(
      (_) async => options.createResult(
        source: QueryResultSource.network,
        exception: OperationException(
          graphqlErrors: [const GraphQLError(message: 'network error')],
        ),
      ),
    );
    authState.gqlClient.value = mockClient;

    await authState.logout();

    verify(() => mockClient.mutate(any())).called(1);
    expect(authState.isLoggedIn, isFalse);
    expect(authState.token, isNull);
  });

  test('logout() completes when no FCM token is available (nothing to unregister)', () async {
    final authState = AuthState();

    await authState.logout();

    expect(authState.isLoggedIn, isFalse);
  });
}
