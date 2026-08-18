# Implementation Plan: Добавление позиций меню в активный заказ

Branch: feature/order-menu-items
Created: 2026-08-18

## Original Request
/home/msv/GolandProjects/hookah_backend/order.txt
промт на добавление позиций из меню.

Добавить позицию в меню можно
1) На экране заказа. над кнопкой "заказать" добавить кнопку "+ меню), с раскрывающимся списком меню
2) На экране заказа (где чат с кальянной). Добавить кнопку "меню" с раскрывающимся списком меню

## Settings
- Testing: yes
- Logging: verbose
- Docs: yes (mandatory documentation checkpoint at completion, via `/aif-docs`)

## Backend Contract Reference
Source: `/home/msv/GolandProjects/hookah_backend/order.txt` (внешний ТЗ от бэкенда, не `.ai-factory/RESEARCH.md`).

Ключевые факты из документа, определяющие объём фичи:
- Backend уже полностью реализован и задеплоен. Мутация `addOrderItems(orderId, loungeId, menuItems, hookahItems)` контракт менять нельзя.
- Позиции **только добавляются**, никогда не удаляются/не заменяются. У роли `user` нет прав на удаление/отмену позиций — в UI такие элементы управления добавлять нельзя.
- Кнопка добавления видна только пока `order.status` в `{new, in_progress, calculation}`. Для `completed`/`canceled*` backend отклонит вызов.
- После успешной мутации экран обновляется **из ответа мутации** (`menuItems`, `hookahItems`, `subtotal`, `finalTotal`) — push/WS-уведомления о собственном добавлении не будет, это ожидаемое поведение.
- Единственный явный пользовательский сценарий в ТЗ — дозаказ **в уже существующий заказ** (не на экране создания заказа). Экран создания заказа (`new_order_screen.dart`, кнопка «Оформить заказ») к этой фиче не относится: до создания заказа ещё нет `orderId`, а `addOrderItems` требует существующий заказ. См. раздел «Допущение по размещению кнопок» ниже.
- Цена/лояльность для дозаказанных позиций не пересчитываются — поля скидок/баллов на этом экране не показываем.

## Допущение по размещению кнопок (важно — проверить перед реализацией)
В проекте нет отдельного экрана «заказ» с кнопкой «заказать» и отдельного экрана «чат с кальянной» — оба требования пользователя описывают **один и тот же** `lib/screens/order/order_detail_screen.dart` (уже совмещает блок информации о заказе сверху и чат с заведением снизу; единственная кнопка с похожим смыслом — «Оформить заказ» — находится на экране *создания* заказа `new_order_screen.dart`, где `orderId` ещё не существует, поэтому `addOrderItems` там технически невозможен).

Поэтому в плане обе точки входа реализуются на `order_detail_screen.dart`:
1. Кнопка **«+ Меню»** — в блоке информации о заказе (`_buildOrderInfo()`), рядом с текущими позициями/итогом.
2. Кнопка **«Меню»** — в панели ввода чата (`_buildInput()`), рядом с полем сообщения.

Обе кнопки открывают один и тот же список меню и вызывают один и тот же обработчик. Если это расходится с ожиданиями — скорректировать на этапе `/aif-improve` до начала `/aif-implement`.

## Commit Plan
- **Commit 1** (после задач 1-3): "feat(order): extend Order model and GraphQL contract for order menu items"
- **Commit 2** (после задач 4-7): "feat(order): add menu-item picker entry points to order detail screen"
- **Commit 3** (после задач 8-10): "test(order): cover order menu-item model, mutation and screen behavior"

## Tasks

### Phase 1: Модель данных и GraphQL-контракт

- [x] Task 1: Расширить `lib/core/models/order.dart`
  - Добавить классы `OrderMenuItem` (`id`, `menuItemId`, `name`, `quantity`, `unitPrice`, `status`) и `OrderHookahItem` (`id`, `name`, `flavor`, `quantity`, `unitPrice`, `status`) с `fromJson` в стиле существующего `SessionItem` (`lib/core/models/session_item.dart`) — дефолты через `as T? ?? fallback`, без исключений на отсутствующих полях.
  - В `Order` добавить поля: `menuItems` (`List<OrderMenuItem>`, default `const []`), `hookahItems` (`List<OrderHookahItem>`, default `const []`), `subtotal` (`double?`), `finalTotal` (`double?`).
  - Добавить геттер `bool get isEditable => const {'new', 'in_progress', 'calculation'}.contains(status);` — единый источник правды для видимости кнопок добавления на экране (пункт 4 чек-листа ТЗ бэкенда).
  - Обновить `Order.fromJson` — парсить новые поля тем же defensive-стилем.
  - Расширить `Order.copyWith` — добавить опциональные параметры `menuItems`, `hookahItems`, `subtotal`, `finalTotal` (в дополнение к уже существующему `status`), чтобы можно было мёрджить ответ `addOrderItems` (который не содержит `loungeId`/`flavor`/`comment`/`phone`/`arrivalAt`/`createdAt`) поверх текущего `_order` без потери остальных полей.
  - Логирование: не требуется — чистый data-класс без I/O, как остальные модели проекта.
  - Файлы: `lib/core/models/order.dart`

- [x] Task 2: Расширить `GQLQueries.orders` в `lib/core/graphql/queries.dart` (строки ~88-101)
  - Добавить в selection set: `menuItems { id menuItemId name quantity unitPrice status }`, `hookahItems { id name flavor quantity unitPrice status }`, `subtotal`, `finalTotal` — точно по составу полей из `order.txt` раздела 2/3.
  - Аргументы запроса (`limit: 50`) не менять — фильтрация по статусу уже делается на клиенте (`orders_screen.dart`); менять контракт вызова не нужно.
  - Это одновременно чинит `orders_screen.dart` (список) и `push_navigation.dart` (deep-link по тапу на push) — оба используют `GQLQueries.orders`, оба получат новые поля бесплатно.
  - Логирование: не требуется — статическая GraphQL-строка, как остальные методы `GQLQueries`.
  - Файлы: `lib/core/graphql/queries.dart`

- [x] Task 3: Добавить `GQLMutations.addOrderItems` в `lib/core/graphql/mutations.dart`
  - Сигнатура по образцу уже существующего `addSessionItem` (строки 152-176): `addOrderItems({required String orderId, required String loungeId, required String menuItemId, int quantity = 1})`.
  - Тело мутации — `menuItems: [{ menuItemId: <jsonEncode>, quantity: <int> }]` (один элемент списка на один вызов — соответствует однопозиционному UX `showMenuItemPicker`); `hookahItems` не передавать (вне объёма этой фичи — см. «Допущение» выше).
  - Селекшн ответа — как в разделе 3 `order.txt`: `id status menuItems { id menuItemId name quantity unitPrice status } hookahItems { id name flavor quantity unitPrice status } subtotal finalTotal`.
  - Логирование: не требуется на уровне метода (чистая строка-конструктор, как остальные методы `GQLMutations`) — логирование самого вызова мутации делается на экране (Task 5).
  - Файлы: `lib/core/graphql/mutations.dart`

<!-- Commit checkpoint: tasks 1-3 -->

### Phase 2: Экран заказа — отображение и добавление позиций

- [x] Task 4: Блок «Позиции заказа» в `_buildOrderInfo()` (`lib/screens/order/order_detail_screen.dart`)
  - После текущей строки «Статус: …» добавить список уже добавленных позиций: `_order.menuItems` и `_order.hookahItems`, каждая строка — `'${item.name} × ${item.quantity}'` + `'${item.unitPrice.toStringAsFixed(0)} ₽'` (стиль как в `session_items_screen.dart` `_buildBody()`), без каких-либо кнопок удаления/отмены (см. ограничение ТЗ раздел 4).
  - Показать `Итого: ${_order.finalTotal?.toStringAsFixed(0) ?? '—'} ₽` под списком; при пустых `menuItems`/`hookahItems` список не показывать вовсе (не показывать пустой заголовок).
  - НЕ показывать поля скидок/баллов лояльности (явное требование ТЗ раздел 3).
  - Логирование: не требуется — чистый рендеринг уже загруженного состояния `_order`, без сетевых вызовов.
  - Файлы: `lib/screens/order/order_detail_screen.dart`

- [x] Task 5: Общий обработчик добавления позиции + кнопка «+ Меню» (depends on: 1, 3, 4)
  - Добавить `bool _addingMenuItem = false;` и `static const _tag = 'OrderDetail';` (если тега ещё нет в классе).
  - Метод `Future<void> _addMenuItem()`, по образцу `_addItem()` из `session_items_screen.dart`:
    - `showMenuItemPicker(context, loungeId: _order.loungeId)` → если `null`/юзер отменил — выйти.
    - `AppLogger.d(_tag, 'addOrderItems orderId=${_order.id} menuItemId=${picked.item.itemId} quantity=${picked.quantity}')` перед вызовом.
    - Вызвать `GQLMutations.addOrderItems(orderId: _order.id, loungeId: _order.loungeId, menuItemId: picked.item.itemId, quantity: picked.quantity)` через `_graphqlClient.mutate`.
    - При успехе — распарсить `result.data?['addOrderItems']`, обновить `_order` через `_order.copyWith(status:, menuItems:, hookahItems:, subtotal:, finalTotal:)` (см. Task 1), `AppLogger.i(_tag, 'addOrderItems ok orderId=${_order.id} items=${...length} finalTotal=${_order.finalTotal}')`.
    - При ошибке — делегировать в единый обработчик ошибок из Task 7.
    - В течение запроса — `setState(() => _addingMenuItem = true/false)`, отключать кнопки на время запроса (как `_adding` в `session_items_screen.dart`).
  - Кнопка «+ Меню» — в `_buildOrderInfo()`, сразу под блоком позиций/итога из Task 4; видима только если `_order.isEditable`; `onPressed: _addingMenuItem ? null : _addMenuItem`.
  - Логирование: DEBUG перед вызовом мутации (параметры), INFO при успехе (обновлённое состояние заказа), WARN при ошибке (см. Task 7) — формат `[OrderDetail.method] message {data}` по конвенции `AppLogger`.
  - Файлы: `lib/screens/order/order_detail_screen.dart`

- [x] Task 6: Кнопка «Меню» в панели ввода чата (depends on: 5)
  - В `_buildInput()` — рядом с `TextField` и кнопкой отправки, добавить `IconButton` (иконка `Icons.restaurant_menu` или `Icons.menu_book`) с тем же обработчиком `_addMenuItem` из Task 5 — никакой отдельной логики, только вторая точка входа к тому же экшену.
  - Видима только если `_order.isEditable` (та же проверка, что и в Task 5).
  - Логирование: отдельного логирования не требует — использует уже залогированный `_addMenuItem()` из Task 5.
  - Файлы: `lib/screens/order/order_detail_screen.dart`

- [x] Task 7: Обработка ошибок `addOrderItems` + перезагрузка состояния заказа (depends on: 5, 6)
  - Общий метод `_reloadOrderState()`: запрос `GQLQueries.orders` через `_graphqlClient`, парсинг `Order.fromJson` по списку, поиск по id — переиспользовать уже существующую чистую функцию `findOrderById` из `lib/core/notifications/push_navigation.dart` (импортировать, не дублировать логику). При успехе — `setState(() => _order = found)`; если заказ не найден в списке — оставить текущее состояние и залогировать WARN.
  - В `_addMenuItem()` на ошибке мутации — маппинг по тексту ошибки (`result.exception?.graphqlErrors.firstOrNull?.message`), см. `order.txt` раздел 5:
    - `unauthorized: login required to add items to an order` — специальной обработки не требуется: `AuthState._handleUnauthenticated()` (глобальный `onUnauthenticated` в `_buildClient`) уже форсирует logout при протухшем токене на уровне GraphQL-клиента; на экране достаточно не падать и показать общий тост.
    - `order can no longer be modified once it is completed or canceled` → `ScaffoldMessenger` тост `'Заказ уже закрыт, дозаказ недоступен'` + `_reloadOrderState()` (кнопки скроются сами через `_order.isEditable` после обновления статуса).
    - `forbidden: only the order owner can add items to this order`, `no valid items to add` → общий тост с текстом ошибки сервера + `_reloadOrderState()`.
    - `invalid orderId` / `invalid loungeId` → `AppLogger.e(_tag, 'addOrderItems client bug orderId=${_order.id} loungeId=${_order.loungeId}: $message')`, тост с общим текстом (НЕ показывать пользователю технический текст ошибки) + `_reloadOrderState()`.
    - Любая нераспознанная ошибка → общий тост с текстом ошибки сервера + `_reloadOrderState()` (правило по умолчанию из раздела 5 ТЗ).
  - Логирование: WARN на каждую ошибку мутации с `orderId` и текстом ошибки; ERROR отдельно для случая `invalid orderId`/`invalid loungeId` (баг клиента, не пользователя).
  - Файлы: `lib/screens/order/order_detail_screen.dart`

<!-- Commit checkpoint: tasks 4-7 -->

### Phase 3: Тесты

- [ ] Task 8: Unit-тесты модели — новый файл `test/core/models/order_test.dart`
  - По образцу `test/core/models/session_item_test.dart` / `test/core/models/menu_item_test.dart`: `Order.fromJson` парсит `menuItems`/`hookahItems`/`subtotal`/`finalTotal`, включая случай отсутствующих полей (defaults: пустые списки, `null` для сумм).
  - Тесты на `Order.isEditable` — `true` для `new`/`in_progress`/`calculation`, `false` для `completed`/`canceled`/`canceled_by_user`/`canceled_by_staff`.
  - Тест на `copyWith` — что `menuItems`/`hookahItems`/`subtotal`/`finalTotal` можно обновить, не потеряв `loungeId`/`flavor`/`comment`/`phone`/`arrivalAt`/`createdAt`.
  - Логирование: не применимо — unit-тесты чистых функций.
  - Файлы: `test/core/models/order_test.dart`

- [ ] Task 9: Unit-тест мутации — добавить группу в `test/core/graphql/device_mutations_test.dart`? Нет — создать новый файл `test/core/graphql/order_mutations_test.dart` (мутация не относится к device-теме)
  - По образцу существующих тестов `GQLMutations.registerDevice`/`unregisterDevice`: проверить, что `GQLMutations.addOrderItems(...)` интерполирует `orderId`, `loungeId`, `menuItemId`, `quantity` и корректно экранирует кавычки (`jsonEncode`), и что `hookahItems` в строке отсутствует (вне объёма фичи).
  - Логирование: не применимо — unit-тест строковой генерации.
  - Файлы: `test/core/graphql/order_mutations_test.dart`

- [ ] Task 10: Widget-тесты `order_detail_screen.dart` — новый файл `test/screens/order/order_detail_screen_test.dart` (depends on: 4, 5, 6, 7)
  - По образцу `test/screens/table/session_items_screen_test.dart` (лёгкий regression-стиль, `GraphQLClient` на невалидный URL, без сетевого мокинга): экран строится без исключений на первом кадре для заказа со статусом `in_progress`.
  - Кнопка «+ Меню» и кнопка «Меню» в чате видны для `_order.isEditable == true` (`new`/`in_progress`/`calculation`) и отсутствуют для `completed`/`canceled*`.
  - Блок позиций/итога рендерится при непустых `menuItems`, и не рендерится (нет пустого заголовка) при пустых.
  - Логирование: не применимо — widget-тест.
  - Файлы: `test/screens/order/order_detail_screen_test.dart`

<!-- Commit checkpoint: tasks 8-10 -->
