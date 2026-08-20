# Implementation Plan: Реакция клиента на отмену/удаление позиций персоналом + новые системные сообщения в чате заказа

Branch: feature/staff-order-cancel-chat-messages
Created: 2026-08-20

## Original Request
/home/msv/GolandProjects/hookah_backend/order.txt

## Settings
- Testing: yes
- Logging: verbose
- Docs: yes (mandatory documentation checkpoint at completion, via `/aif-docs`)

## Backend Contract Reference
Source: `/home/msv/GolandProjects/hookah_backend/order.txt` (внешний ТЗ от бэкенда, не `.ai-factory/RESEARCH.md`).

Ключевые факты из документа, определяющие объём фичи:
- Backend уже полностью реализован. Персонал (`staff`/`admin`/`owner`/`deputy` — у всех одинаковые права на управление заказом) без действия гостя может: (a) отменить весь заказ (`status: "canceled_by_staff"`), (b) обратимо отменить одну/несколько позиций (позиция остаётся в `menuItems`/`hookahItems`, но получает `status: "canceled"` и перестаёт учитываться в `subtotal`/`finalTotal`; позже может быть восстановлена — `status: "new"`), (c) безвозвратно удалить позицию (только `admin`) — тогда позиция полностью пропадает из массива.
- Каждое из этих действий, а также подтверждение заказа персоналом (`in_progress`), теперь **автоматически порождает системное сообщение** в чате заказа (`senderRole` — один из `staff`/`admin`/`owner`/`deputy`, то есть **не** `"user"`). Никакой специальной обработки по типу сообщения на клиенте не требуется — это обычное сообщение чата, доставляется тем же механизмом, что уже используется (`messages` query / `messageCreatedForOrder` subscription) и тем же push-каналом ("Новое сообщение"), без нового API/типа push.
- Если у заказа на момент подтверждения нет ни одной активной позиции — сообщение о подтверждении не отправляется вовсе; во всех остальных случаях (включая отмену всего заказа) сообщение отправляется всегда.
- **Раздел 3 ТЗ, явная рекомендация клиенту**: при получении нового сообщения в чате заказа клиенту стоит перезапросить актуальное состояние заказа (`orders` query), а не полагаться только на локально закэшированный список позиций — иначе экран может показывать позиции, которых уже нет, или устаревшую сумму к оплате.
- Раздел 4 ТЗ, явно: кнопок/элементов управления удалением или отменой позиций **гостем** по-прежнему нет и не будет — это ограничение уже реализовано (см. `feature/order-menu-items`, `Order.isEditable`) и в объём этой фичи не входит.
- Раздел 4 ТЗ, явно: отдельного push-типа «позиция отменена персоналом» не существует и не появится — вся информация приходит только через уже существующий канал чата заказа.

## Что уже готово в кодовой базе (после мержа feature/order-menu-items в master)
- `OrderMenuItem`/`OrderHookahItem` (`lib/core/models/order.dart`) уже несут поле `status` (default `'new'`), но `order_detail_screen.dart` его нигде не читает — позиция со статусом `"canceled"` отрисовывается как обычная активная позиция. Это и есть основной пробел, который закрывает эта фича.
- `StatusHelper` (`lib/core/utils/status_helper.dart`) уже локализует `canceled_by_staff` — новых статусов заказа вводить не нужно.
- Чат (`messages` query, `messageCreatedForOrder`/`messageCreated` subscriptions, `ChatMessage` модель) уже полностью реализован и не требует изменений контракта — только поведенческие доработки на экране.
- Обнаруженный при исследовании баг: `orders_screen.dart:125` триггерит бейджик непрочитанного/push только при `senderRole == 'staff'` — сообщения от `admin`/`owner`/`deputy` (ровно те роли, что явно перечислены в разделе 1 ТЗ) сейчас **не** покажут пуш/бейджик, если гость не находится в этом чате. Это прямая регрессия относительно требований раздела 1-2 ТЗ и чинится в рамках этой фичи.
- Обнаруженный при исследовании баг: `NotificationService.showChatMessage()` (`lib/core/notifications/notification_service.dart`) не передаёt `payload`, поэтому тап по уже показанному локальному push-уведомлению чата ничего не делает (в отличие от `showOrderStatusPush`, где `payload: orderId` уже используется для `handleOrderPushTap`). Пока эти сообщения были простыми репликами чата, это было малозаметно; теперь, когда через этот канал приходят важные уведомления об отмене/удалении позиций персоналом, тап должен открывать заказ — чиним в рамках этой фичи, переиспользуя уже готовый `handleOrderPushTap`.

## Commit Plan
- **Commit 1** (после задач 1-2): "fix(chat): recognize all staff-like sender roles for notifications and deep-linking"
- **Commit 2** (после задач 3-4): "feat(order): reflect staff item cancellation and refetch order state on chat messages"
- **Commit 3** (после задач 5-7): "test(order): cover sender-role helper, canceled items and staff-message refetch"

## Tasks

### Phase 1: Единый источник правды для роли отправителя + доставка уведомлений

- [x] Task 1: Общий helper `SenderRole.isStaff` — новый файл `lib/core/chat/sender_role.dart`
  - Класс `SenderRole` со статическим методом `static bool isStaff(String senderRole) => senderRole != 'user';` — по стилю уже существующего `StatusHelper` (`lib/core/utils/status_helper.dart`), единый источник правды вместо трёх независимых inline-проверок, найденных при исследовании (`orders_screen.dart:125` сравнивает на `== 'staff'`, `order_detail_screen.dart:108` — на `!= 'user'`, `order_detail_screen.dart:486` — на `== 'user'`).
  - Заменить все три места на использование `SenderRole.isStaff(...)`:
    - `lib/screens/orders/orders_screen.dart:125` — `if (senderRole == 'staff' && orderId.isNotEmpty)` → `if (SenderRole.isStaff(senderRole) && orderId.isNotEmpty)`. Это и есть исправление бага: теперь сообщения от `admin`/`owner`/`deputy` тоже показывают push/бейджик непрочитанного, как того требует раздел 1-2 `order.txt`.
    - `lib/screens/order/order_detail_screen.dart:108` (`_subscribeMessages`) — `final isStaff = msg.senderRole != 'user';` → `final isStaff = SenderRole.isStaff(msg.senderRole);`.
    - `lib/screens/order/order_detail_screen.dart:486` (`_buildChat`) — `final isMe = msg.senderRole == 'user' || (phone.isNotEmpty && msg.senderId == phone);` → `final isMe = !SenderRole.isStaff(msg.senderRole) || (phone.isNotEmpty && msg.senderId == phone);`.
  - Добавить импорт `../../core/chat/sender_role.dart` (или `../../../core/chat/sender_role.dart` — по фактической глубине файла) в оба экрана.
  - Логирование: не требуется — чистая predicate-функция без I/O, как `StatusHelper`.
  - Файлы: `lib/core/chat/sender_role.dart` (новый), `lib/screens/orders/orders_screen.dart`, `lib/screens/order/order_detail_screen.dart`

- [x] Task 2: Deep-link по тапу на push-уведомление чата (depends on: none)
  - В `NotificationService.showChatMessage()` (`lib/core/notifications/notification_service.dart:33-59`) добавить `payload: orderId` в вызов `_plugin.show(...)` — по образцу уже существующего `showOrderStatusPush()` (строка 88, `payload: orderId`).
  - После этого `_onNotificationTapped()` (уже существует, строки 95-100) отработает тап по чат-уведомлению так же, как и по статусному — вызовет `handleOrderPushTap(OrderPushPayload(orderId: orderId))`, никаких изменений в самом `_onNotificationTapped` не требуется.
  - Логирование: добавить `AppLogger.d(_tag, 'showChatMessage orderId=$orderId')` перед `_plugin.show(...)` — по аналогии с существующим логированием в `showOrderStatusPush`.
  - Файлы: `lib/core/notifications/notification_service.dart`

<!-- Commit checkpoint: tasks 1-2 -->

### Phase 2: Экран заказа — отражение действий персонала

- [x] Task 3: Визуально отличать отменённые позиции в списке позиций заказа (depends on: none)
  - В `_buildOrderItemsSection()` (`lib/screens/order/order_detail_screen.dart`, метод строится вокруг `_order.menuItems`/`_order.hookahItems`) вынести общий рендер строки позиции в приватный метод `Widget _buildOrderItemRow(String label, int quantity, double unitPrice, String status)` вместо двух почти идентичных инлайн `Padding`/`Row` блоков.
  - Если `status == 'canceled'` — применить `TextDecoration.lineThrough` к тексту названия/цены (`Colors.grey` оставить) и добавить небольшую метку `"Отменено"` (`Colors.redAccent`, `fontSize: 11`, `fontWeight: FontWeight.w600`) рядом с названием. Позиция остаётся в списке (не скрывается) — так гость видит, что конкретно отменили, даже не читая чат (раздел 1.b ТЗ: "позиция остаётся в списке").
  - Для позиций без `status == 'canceled'` (т.е. `'new'` и любые другие нераспознанные значения) — рендер как раньше, без изменений внешнего вида.
  - Удалённые персоналом позиции (`admin`, безвозвратно) не требуют отдельной обработки — они просто отсутствуют в `menuItems`/`hookahItems`, которые приходит с бэкенда после рефетча (Task 4), список отрисуется без них естественным образом.
  - `Итого: ${_order.finalTotal...}` под списком не трогать — backend уже пересчитывает `finalTotal` без отменённых позиций.
  - Логирование: не требуется — чистый рендеринг уже загруженного состояния `_order`, без сетевых вызовов (как и было в этом методе ранее).
  - Файлы: `lib/screens/order/order_detail_screen.dart`

- [x] Task 4: Перезапрос состояния заказа при новом сообщении от персонала (depends on: 1)
  - В `_subscribeMessages()` (`lib/screens/order/order_detail_screen.dart:97-115`) — после `setState` с добавлением нового сообщения, если `isStaff` (уже вычисляется через `SenderRole.isStaff` из Task 1) — вызвать `_reloadOrderState()` (fire-and-forget, без `await`, по аналогии с уже существующим вызовом `_maybeShowFeedbackDialog()` в `_buildOrderInfo()`). Переиспользует уже готовый и протестированный `_reloadOrderState()` (строки 400-416) — без дублирования логики загрузки `orders`/поиска по id.
  - В `_fetchMessages()` (строки 117-131) — заменить нынешнюю грубую эвристику `hasNew = fetched.length > _messages.length` на точное вычисление новых сообщений по `id` (`final oldIds = _messages.map((m) => m.id).toSet(); final newOnes = fetched.where((m) => !oldIds.contains(m.id)).toList(); final hasNew = newOnes.isNotEmpty;`) — старая эвристика на основе одной только длины списка не различает "какие именно сообщения новые" и не позволяет проверить их отправителя. После `setState(() => _messages = fetched)` — если `newOnes.any((m) => SenderRole.isStaff(m.senderRole))`, вызвать `_reloadOrderState()`. Это подстраховка на случай, если подписка `messageCreatedForOrder` временно не доставила событие (реконнект WS и т.п.), а 4-секундный поллинг чата его всё равно подхватил.
  - Цель обоих изменений — реализовать явную рекомендацию раздела 3 `order.txt`: не полагаться на локально закэшированный список позиций после действия персонала, а перезапрашивать актуальное состояние заказа (позиции/статус/`subtotal`/`finalTotal`) сразу по приходу системного сообщения в чат.
  - Логирование: `AppLogger.d(_tag, 'staff message triggered order reload orderId=${_order.id}')` перед вызовом `_reloadOrderState()` в обоих местах — чтобы в логах было видно, что именно инициировало перезагрузку состояния заказа.
  - Файлы: `lib/screens/order/order_detail_screen.dart`

<!-- Commit checkpoint: tasks 3-4 -->

### Phase 3: Тесты

- [x] Task 5: Unit-тесты `SenderRole.isStaff` — новый файл `test/core/chat/sender_role_test.dart` (depends on: 1)
  - По образцу `test/core/utils/status_helper_test.dart` (если существует) или любого простого unit-теста моделей проекта: `isStaff('user') == false`; `isStaff('staff') == true`; `isStaff('admin') == true`; `isStaff('owner') == true`; `isStaff('deputy') == true`; `isStaff('') == true` (пустая строка — не `'user'`, значит по текущей семантике трактуется как персонал; зафиксировать это поведение тестом, а не оставлять неявным).
  - Логирование: не применимо — unit-тест чистой функции.
  - Файлы: `test/core/chat/sender_role_test.dart`

- [x] Task 6: Widget-тесты отображения отменённых позиций — расширить `test/screens/order/order_detail_screen_test.dart` (depends on: 3)
  - По уже существующему в этом файле паттерну `pumpOrderScreen` (лёгкий regression-стиль, `GraphQLClient` на невалидный URL, без сетевого мокинга — начальное состояние заказа передаётся напрямую через `RouteSettings.arguments`): новый тест с заказом, где один `OrderMenuItem` имеет `status: 'canceled'`, а другой — `status: 'new'`.
  - Проверить: оба названия позиций по-прежнему найдены в дереве виджетов (`find.textContaining(...)`, позиция не скрывается); у отменённой позиции найден текст `"Отменено"` (`findsOneWidget`); у активной позиции — `findsNothing` в её локальном окружении (тест на `finalTotal` не менять, значение приходит из уже готового поля `_order.finalTotal`).
  - Логирование: не применимо — widget-тест.
  - Файлы: `test/screens/order/order_detail_screen_test.dart`

- [x] Task 7: Widget-тест перезапроса заказа по сообщению персонала — новый тест-файл или группа в `test/screens/order/order_detail_screen_test.dart` (depends on: 4)
  - Единственный способ реалистично проверить Task 4 без сетевого мокинга — использовать уже установленный в проекте паттерн `mocktail` + `MockGraphQLClient extends Mock implements GraphQLClient {}` (см. `test/screens/table/menu_item_picker_test.dart:7`, `when(() => client.query(any()))...`, `registerFallbackValue(QueryOptions(...))` в `setUpAll`).
  - Стубы:
    - `client.query(any())` — различать по содержимому `QueryOptions.document` (проверка `opts.document.toString()`/исходную GraphQL-строку на вхождение `'messages('` вs `'orders('`, по аналогии с тем, как `stubMenuAndCategories` в `menu_item_picker_test.dart` различает вызовы по порядковому индексу): на `GQLQueries.messages(...)` вернуть пустой список (или соответствующий фейковый ответ), на `GQLQueries.orders` — заказ с обновлённым `finalTotal`/составом позиций (симулирует результат `_reloadOrderState()`).
    - `client.subscribe(any())` — различать по документу между `messageCreatedForOrder`/`orderStatusChanged`: для первой подписки вернуть `Stream` (например, через `StreamController`, чтобы тест мог позже вызвать `controller.add(...)`), для `orderStatusChanged` — `const Stream.empty()`.
  - Сценарий теста: запустить экран, затем эмитировать в поток `messageCreatedForOrder` сообщение с `senderRole: 'staff'` (`QueryResult` с `data: {'messageCreated': {...}}`), `pumpAndSettle`, и проверить, что `client.query(any())` был вызван с документом, содержащим `orders` (т.е. `_reloadOrderState()` реально сработал) — через `verify(() => client.query(any(that: ...))).called(greaterThanOrEqualTo(1))` либо проверкой обновившегося в дереве виджетов `finalTotal`/состава позиций из подставленного фейкового ответа `orders`.
  - Логирование: не применимо — widget-тест.
  - Файлы: `test/screens/order/order_detail_screen_test.dart`

<!-- Commit checkpoint: tasks 5-7 -->
