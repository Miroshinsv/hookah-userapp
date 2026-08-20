import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:user_app/core/auth/auth_state.dart';
import 'package:user_app/core/chat/unread_state.dart';
import 'package:user_app/core/models/order.dart';
import 'package:user_app/screens/order/order_detail_screen.dart';

class MockGraphQLClient extends Mock implements GraphQLClient {}

// Regression-style tests (no network mocking, same pattern as
// test/screens/table/session_items_screen_test.dart): the "+ Меню" / "Меню"
// entry points must only appear while Order.isEditable is true (order.txt
// раздел 4 — backend отклоняет addOrderItems после completed/canceled*).
void main() {
  setUpAll(() {
    registerFallbackValue(QueryOptions(document: gql('query { noop }')));
    registerFallbackValue(
        SubscriptionOptions(document: gql('subscription { noop }')));
  });

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

  testWidgets(
      'marks a staff-cancelled item with strikethrough and "Отменено" without hiding it',
      (tester) async {
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
          status: 'canceled',
        ),
        OrderMenuItem(
          id: 'mi2',
          menuItemId: 'm2',
          name: 'Чай ассам',
          quantity: 1,
          unitPrice: 200.0,
          status: 'new',
        ),
      ],
      finalTotal: 200.0,
    );

    await pumpOrderScreen(tester, order);

    expect(tester.takeException(), isNull);
    // Обе позиции остаются в списке — отменённая не скрывается (order.txt
    // раздел 1.b).
    expect(find.textContaining('Кола'), findsOneWidget);
    expect(find.textContaining('Чай ассам'), findsOneWidget);
    // Только у отменённой позиции есть метка "Отменено".
    expect(find.text('Отменено'), findsOneWidget);

    final canceledText = tester.widget<Text>(find.textContaining('Кола'));
    expect(canceledText.style?.decoration, TextDecoration.lineThrough);

    final activeText = tester.widget<Text>(find.textContaining('Чай ассам'));
    expect(activeText.style?.decoration, isNot(TextDecoration.lineThrough));
  });

  testWidgets(
      'does not show an items header but still shows "+ Меню" when the order has no items yet',
      (tester) async {
    const order = Order(id: '1', loungeId: '2', status: 'new');

    await pumpOrderScreen(tester, order);

    expect(tester.takeException(), isNull);
    expect(find.text('+ Меню'), findsOneWidget);
    expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    expect(find.text('Позиции заказа'), findsNothing);
  });

  group('reload on staff chat message', () {
    // Проверяет order.txt раздел 3: системное сообщение персонала должно
    // триггерить перезапрос актуального состояния заказа, а не просто
    // добавляться в чат. Единственный способ это реально проверить —
    // подставить MockGraphQLClient (тот же паттерн, что и в
    // test/screens/table/menu_item_picker_test.dart) и самим протолкнуть
    // событие в поток подписки.
    Future<void> pumpWithClient(
        WidgetTester tester, MockGraphQLClient client, Order order) async {
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

    testWidgets(
        'a staff message on the order subscription triggers an orders refetch',
        (tester) async {
      final client = MockGraphQLClient();
      final msgController = StreamController<QueryResult<Object?>>();
      addTearDown(msgController.close);

      // Первый subscribe() — messageCreatedForOrder (из _subscribeMessages);
      // второй — orderStatusChanged (из виджета Subscription в
      // _buildOrderInfo). Порядок фиксирован жизненным циклом State
      // (didChangeDependencies выполняется раньше build).
      var subscribeCallIndex = 0;
      when(() => client.subscribe(any())).thenAnswer((_) {
        final isMessageSub = subscribeCallIndex == 0;
        subscribeCallIndex++;
        return isMessageSub
            ? msgController.stream
            : const Stream<QueryResult<Object?>>.empty();
      });

      // Первый query() — GQLQueries.messages (пустой чат при открытии);
      // любой следующий — GQLQueries.orders, вызванный _reloadOrderState()
      // после того, как в поток подписки придёт сообщение от персонала.
      var queryCallIndex = 0;
      when(() => client.query(any())).thenAnswer((invocation) async {
        final opts = invocation.positionalArguments[0] as QueryOptions;
        final isFirstCall = queryCallIndex == 0;
        queryCallIndex++;
        if (isFirstCall) {
          return opts.createResult(
              source: QueryResultSource.network, data: {'messages': []});
        }
        return opts.createResult(source: QueryResultSource.network, data: {
          'orders': [
            {
              'id': '1',
              'loungeId': '2',
              'status': 'in_progress',
              'menuItems': [
                {
                  'id': 'mi1',
                  'menuItemId': 'm1',
                  'name': 'Кола',
                  'quantity': 2,
                  'unitPrice': 150.0,
                  'status': 'canceled',
                },
              ],
              'hookahItems': <Map<String, dynamic>>[],
              'subtotal': 0.0,
              'finalTotal': 0.0,
            },
          ],
        });
      });

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

      await pumpWithClient(tester, client, order);
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Итого: 300'), findsOneWidget);
      expect(find.text('Отменено'), findsNothing);

      // Персонал отменил позицию — приходит системное сообщение в чат.
      msgController.add(QueryResult(
        source: QueryResultSource.network,
        options: SubscriptionOptions(document: gql('subscription { noop }')),
        data: {
          'messageCreated': {
            'id': 'msg1',
            'senderId': 'staff-1',
            'senderRole': 'staff',
            'text': 'Из вашего заказа отменили\nКола х2',
            'createdAt': '2026-08-20T12:00:00Z',
          },
        },
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // _reloadOrderState() подтянул обновлённый заказ из мока orders —
      // позиция теперь отменена и Итого пересчитан.
      expect(find.text('Отменено'), findsOneWidget);
      expect(find.textContaining('Итого: 0'), findsOneWidget);
    });
  });
}
