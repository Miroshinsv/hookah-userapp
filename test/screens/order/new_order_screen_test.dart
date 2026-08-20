import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:user_app/core/models/lounge.dart';
import 'package:user_app/screens/order/new_order_screen.dart';

// Regression test: the "+ Меню" button must always render on the order
// creation screen so a guest can add menu items before submitting — it must
// not depend on any items already being picked (see order_detail_screen's
// analogous bug, fixed after /aif-review).
void main() {
  testWidgets('shows the "+ Меню" button with no items picked yet', (tester) async {
    final client = GraphQLClient(
      link: HttpLink('https://example.invalid/graphql'),
      cache: GraphQLCache(),
    );
    const lounge = Lounge(
      id: '1',
      name: 'Test Lounge',
      latitude: 0,
      longitude: 0,
      ownerUserId: 'owner-1',
    );

    await tester.pumpWidget(
      GraphQLProvider(
        client: ValueNotifier(client),
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                settings: const RouteSettings(arguments: lounge),
                builder: (_) => const NewOrderScreen(),
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
    expect(find.text('+ Меню'), findsOneWidget);
    expect(find.text('Позиции меню'), findsNothing);
  });
}
