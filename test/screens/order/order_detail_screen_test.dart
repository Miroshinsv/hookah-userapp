import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:user_app/core/auth/auth_state.dart';
import 'package:user_app/core/chat/unread_state.dart';
import 'package:user_app/core/models/order.dart';
import 'package:user_app/screens/order/order_detail_screen.dart';

// Regression-style tests (no network mocking, same pattern as
// test/screens/table/session_items_screen_test.dart): the "+ Меню" / "Меню"
// entry points must only appear while Order.isEditable is true (order.txt
// раздел 4 — backend отклоняет addOrderItems после completed/canceled*).
void main() {
  Future<void> pumpOrderScreen(WidgetTester tester, Order order) async {
    final client = GraphQLClient(
      link: HttpLink('https://example.invalid/graphql'),
      cache: GraphQLCache(),
    );

    await tester.pumpWidget(
      GraphQLProvider(
        client: ValueNotifier(client),
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider<UnreadState>(create: (_) => UnreadState()),
            ChangeNotifierProvider<AuthState>(create: (_) => AuthState()),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  settings: RouteSettings(arguments: {'order': order}),
                  builder: (_) => const OrderDetailScreen(),
                )),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
  }

  testWidgets('shows menu entry points and items for an editable order', (tester) async {
    const order = Order(
      id: '1',
      loungeId: '2',
      status: 'in_progress',
      menuItems: [
        OrderMenuItem(
          id: 'mi1',
          menuItemId: 'm1',
          name: 'Кола',
          quantity: 2,
          unitPrice: 150.0,
          status: 'new',
        ),
      ],
      finalTotal: 300.0,
    );

    await pumpOrderScreen(tester, order);

    expect(tester.takeException(), isNull);
    expect(find.text('+ Меню'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    expect(find.textContaining('Кола'), findsOneWidget);
    expect(find.textContaining('Итого: 300'), findsOneWidget);
  });

  testWidgets('hides menu entry points for a completed order', (tester) async {
    const order = Order(id: '1', loungeId: '2', status: 'completed');

    await pumpOrderScreen(tester, order);

    expect(tester.takeException(), isNull);
    expect(find.text('+ Меню'), findsNothing);
    expect(find.byIcon(Icons.restaurant_menu), findsNothing);
  });

  testWidgets('does not show an items header when the order has no items', (tester) async {
    const order = Order(id: '1', loungeId: '2', status: 'new');

    await pumpOrderScreen(tester, order);

    expect(tester.takeException(), isNull);
    expect(find.text('Позиции заказа'), findsNothing);
  });
}
