import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/core/auth/auth_state.dart';

// Regression test for: registration (and any other GraphQL request) can show
// "TimeoutException ... No stream event" to the user even though the mutation
// actually succeeded on the backend. The `graphql` package applies a default
// GraphQLClient(queryRequestTimeout: Duration(seconds: 5)) to every
// query/mutation unless overridden — 5s is too tight for a mobile network
// round trip through the gateway to the staff gRPC service, so slow (but
// successful) requests get reported to the user as failures.
void main() {
  test('gqlClient request timeout is generous enough for real network/backend latency', () {
    final authState = AuthState();
    final timeout = authState.gqlClient.value.queryManager.requestTimeout;

    // null means "no timeout"; anything shorter than 15s reproduces the bug.
    expect(
      timeout == null || timeout >= const Duration(seconds: 15),
      isTrue,
      reason: 'gqlClient request timeout is $timeout — too short for mobile '
          'network + backend latency, causes spurious "No stream event" '
          'errors on operations (e.g. registerUser) that actually succeed',
    );
  });
}
