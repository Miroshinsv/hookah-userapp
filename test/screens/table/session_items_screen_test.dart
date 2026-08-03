import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:user_app/screens/table/session_items_screen.dart';

// Regression test: the screen used to read its route arguments (sessionId,
// loungeId, tableLabel) inside an addPostFrameCallback and cache them into
// `late` fields — but build() reads _tableLabel synchronously on the very
// first frame, which runs *before* any post-frame callback fires. That threw
// LateInitializationError on every navigation into this screen. Fixed by
// resolving arguments in didChangeDependencies(), which runs before the
// first build().
void main() {
  testWidgets('builds on first frame without throwing and shows the table label', (tester) async {
    final client = GraphQLClient(
      link: HttpLink('https://example.invalid/graphql'),
      cache: GraphQLCache(),
    );

    await tester.pumpWidget(
      GraphQLProvider(
        client: ValueNotifier(client),
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                settings: const RouteSettings(
                  arguments: {'sessionId': '1', 'loungeId': '2', 'tableLabel': 'Table A'},
                ),
                builder: (_) => const SessionItemsScreen(),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('Table A'), findsOneWidget);
  });
}
