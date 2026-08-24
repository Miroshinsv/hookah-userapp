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
    registerFallbackValue(MutationOptions(document: gql('mutation { noop }')));
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

  // Тот же сценарий открытия экрана, что и pumpOrderScreen выше, но с
  // MockGraphQLClient вместо реального клиента — нужен там, где тест сам
  // управляет ответами query()/subscribe() (мок GraphQL-сети, тот же
  // паттерн, что и в test/screens/table/menu_item_picker_test.dart).
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
    // событие в поток подписки — см. общий pumpWithClient(...) выше.

    testWidgets(
        'a staff message on the order subscription triggers an orders refetch',
        (tester) async {
      final client = MockGraphQLClient();
      final msgController = StreamController<QueryResult<Object?>>();
      addTearDown(msgController.close);

      // Первый subscribe() — newMessage (из _subscribeMessages); второй —
      // orderStatusChanged (из виджета Subscription в _buildOrderInfo).
      // Порядок фиксирован жизненным циклом State (didChangeDependencies
      // выполняется раньше build).
      var subscribeCallIndex = 0;
      when(() => client.subscribe(any())).thenAnswer((_) {
        final isMessageSub = subscribeCallIndex == 0;
        subscribeCallIndex++;
        return isMessageSub
            ? msgController.stream
            : const Stream<QueryResult<Object?>>.empty();
      });

      // Вызовы query() по порядку: (0) GQLQueries.messages при открытии
      // экрана — пустой чат; (1) GQLQueries.messages, вызванный
      // _subscribeMessages() через _fetchMessages() после события подписки —
      // возвращает настоящее сообщение с реальным id (подписка сама id не
      // содержит); (2) GQLQueries.orders, вызванный _reloadOrderState() из
      // _fetchMessages(), т.к. среди новых сообщений есть от персонала.
      var queryCallIndex = 0;
      when(() => client.query(any())).thenAnswer((invocation) async {
        final opts = invocation.positionalArguments[0] as QueryOptions;
        final callIndex = queryCallIndex;
        queryCallIndex++;
        if (callIndex == 0) {
          return opts.createResult(
              source: QueryResultSource.network, data: {'messages': []});
        }
        if (callIndex == 1) {
          return opts.createResult(source: QueryResultSource.network, data: {
            'messages': [
              {
                'id': 'msg1',
                'senderId': 'staff-1',
                'senderRole': 'staff',
                'text': 'Из вашего заказа отменили\nКола х2',
                'createdAt': '2026-08-20T12:00:00Z',
              },
            ],
          });
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

      // Персонал отменил позицию — приходит realtime-событие newMessage для
      // текущего заказа. Payload не содержит id/createdAt — это триггер,
      // не готовое сообщение (см. Backend Contract Reference в плане фичи).
      msgController.add(QueryResult(
        source: QueryResultSource.network,
        options: SubscriptionOptions(document: gql('subscription { noop }')),
        data: {
          'newMessage': {
            'orderId': '1',
            'senderId': 'staff-1',
            'senderRole': 'staff',
            'text': 'Из вашего заказа отменили\nКола х2',
          },
        },
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      // _reloadOrderState() подтянул обновлённый заказ из мока orders —
      // позиция теперь отменена и Итого пересчитан.
      expect(find.text('Отменено'), findsOneWidget);
      expect(find.textContaining('Итого: 0'), findsOneWidget);
    });

    testWidgets(
        'a newMessage event for a different order does not trigger a refetch',
        (tester) async {
      final client = MockGraphQLClient();
      final msgController = StreamController<QueryResult<Object?>>();
      addTearDown(msgController.close);

      var subscribeCallIndex = 0;
      when(() => client.subscribe(any())).thenAnswer((_) {
        final isMessageSub = subscribeCallIndex == 0;
        subscribeCallIndex++;
        return isMessageSub
            ? msgController.stream
            : const Stream<QueryResult<Object?>>.empty();
      });

      var queryCallCount = 0;
      when(() => client.query(any())).thenAnswer((invocation) async {
        queryCallCount++;
        final opts = invocation.positionalArguments[0] as QueryOptions;
        return opts.createResult(
            source: QueryResultSource.network, data: {'messages': []});
      });

      const order = Order(id: '1', loungeId: '2', status: 'in_progress');

      await pumpWithClient(tester, client, order);
      expect(tester.takeException(), isNull);
      final callsAfterOpen = queryCallCount;

      // Событие относится к другому заказу того же гостя — экран заказа #1
      // не должен на него реагировать (клиентский фильтр по orderId).
      msgController.add(QueryResult(
        source: QueryResultSource.network,
        options: SubscriptionOptions(document: gql('subscription { noop }')),
        data: {
          'newMessage': {
            'orderId': '999',
            'senderId': 'staff-1',
            'senderRole': 'staff',
            'text': 'Другой заказ',
          },
        },
      ));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));

      expect(queryCallCount, callsAfterOpen);
    });
  });

  group('sendMessage error handling', () {
    testWidgets(
        'shows a SnackBar and keeps the draft text when sendMessage fails',
        (tester) async {
      final client = MockGraphQLClient();

      when(() => client.subscribe(any()))
          .thenAnswer((_) => const Stream<QueryResult<Object?>>.empty());
      when(() => client.query(any())).thenAnswer((invocation) async {
        final opts = invocation.positionalArguments[0] as QueryOptions;
        return opts.createResult(
            source: QueryResultSource.network, data: {'messages': []});
      });

      var mutateCallCount = 0;
      when(() => client.mutate(any())).thenAnswer((invocation) async {
        mutateCallCount++;
        final opts = invocation.positionalArguments[0] as MutationOptions;
        return opts.createResult(
          source: QueryResultSource.network,
          exception: OperationException(
            graphqlErrors: const [GraphQLError(message: 'forbidden')],
          ),
        );
      });

      const order = Order(id: '1', loungeId: '2', status: 'in_progress');
      await pumpWithClient(tester, client, order);

      await tester.enterText(find.byType(TextField), 'Добавьте лёд');
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('forbidden'), findsOneWidget);
      expect(find.text('Добавьте лёд'), findsOneWidget);
      expect(mutateCallCount, 1);
    });
  });
}
