import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:user_app/screens/table/menu_item_picker.dart';

class MockGraphQLClient extends Mock implements GraphQLClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(QueryOptions(document: gql('query { noop }')));
  });

  Future<void> pumpPicker(WidgetTester tester, MockGraphQLClient client) async {
    await tester.pumpWidget(
      GraphQLProvider(
        client: ValueNotifier(client),
        child: MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showMenuItemPicker(context, loungeId: 'L'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // menuItems and menuCategories are queried in a fixed order inside
  // Future.wait — both calls are issued synchronously before either awaits,
  // so mocktail records call #0 as menuItems and call #1 as menuCategories.
  void stubMenuAndCategories(MockGraphQLClient client) {
    var callIndex = 0;
    when(() => client.query(any())).thenAnswer((invocation) async {
      final opts = invocation.positionalArguments[0] as QueryOptions;
      final isFirstCall = callIndex == 0;
      callIndex++;
      if (isFirstCall) {
        return opts.createResult(source: QueryResultSource.network, data: {
          'menuItems': [
            {
              'itemId': '1',
              'loungeId': 'L',
              'categoryId': 'cat-tea',
              'name': 'Чай зелёный',
              'price': 200.0,
              'stopped': false,
              'available': true,
            },
            {
              'itemId': '2',
              'loungeId': 'L',
              'categoryId': 'cat-cold',
              'name': 'Лимонад',
              'price': 150.0,
              'stopped': false,
              'available': true,
            },
            {
              'itemId': '3',
              'loungeId': 'L',
              'categoryId': 'cat-tea',
              'name': 'Чай чёрный',
              'price': 180.0,
              'stopped': false,
              'available': true,
            },
          ],
        });
      }
      return opts.createResult(source: QueryResultSource.network, data: {
        'menuCategories': [
          {'categoryId': 'cat-cold', 'loungeId': 'L', 'name': 'Холодные напитки', 'sortOrder': 2},
          {'categoryId': 'cat-tea', 'loungeId': 'L', 'name': 'Чай', 'sortOrder': 1},
        ],
      });
    });
  }

  testWidgets('shows a category filter and all items by default', (tester) async {
    final client = MockGraphQLClient();
    stubMenuAndCategories(client);

    await pumpPicker(tester, client);

    expect(tester.takeException(), isNull);
    expect(find.text('Все'), findsOneWidget);
    // Chips are sorted by sortOrder — Чай (1) before Холодные напитки (2).
    expect(find.text('Чай'), findsOneWidget);
    expect(find.text('Холодные напитки'), findsOneWidget);
    expect(find.text('Чай зелёный'), findsOneWidget);
    expect(find.text('Чай чёрный'), findsOneWidget);
    expect(find.text('Лимонад'), findsOneWidget);
  });

  testWidgets('filters items by category and back to all', (tester) async {
    final client = MockGraphQLClient();
    stubMenuAndCategories(client);

    await pumpPicker(tester, client);

    await tester.tap(find.text('Чай'));
    await tester.pumpAndSettle();

    expect(find.text('Чай зелёный'), findsOneWidget);
    expect(find.text('Чай чёрный'), findsOneWidget);
    expect(find.text('Лимонад'), findsNothing);

    await tester.tap(find.text('Все'));
    await tester.pumpAndSettle();

    expect(find.text('Лимонад'), findsOneWidget);
  });

  testWidgets('hides the filter row when fewer than two categories have items', (tester) async {
    final client = MockGraphQLClient();
    var callIndex = 0;
    when(() => client.query(any())).thenAnswer((invocation) async {
      final opts = invocation.positionalArguments[0] as QueryOptions;
      final isFirstCall = callIndex == 0;
      callIndex++;
      if (isFirstCall) {
        return opts.createResult(source: QueryResultSource.network, data: {
          'menuItems': [
            {
              'itemId': '1',
              'loungeId': 'L',
              'categoryId': 'cat-tea',
              'name': 'Чай зелёный',
              'price': 200.0,
              'stopped': false,
              'available': true,
            },
          ],
        });
      }
      return opts.createResult(source: QueryResultSource.network, data: {
        'menuCategories': [
          {'categoryId': 'cat-tea', 'loungeId': 'L', 'name': 'Чай', 'sortOrder': 1},
        ],
      });
    });

    await pumpPicker(tester, client);

    expect(tester.takeException(), isNull);
    expect(find.text('Все'), findsNothing);
    expect(find.text('Чай зелёный'), findsOneWidget);
  });
}
