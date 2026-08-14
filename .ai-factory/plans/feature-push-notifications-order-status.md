# Push-уведомления о смене статуса заказа

**Branch:** `feature/push-notifications-order-status`
**Создан:** 2026-08-14

## Original Request

Промт для Flutter-разработчика/AI-агента: push-уведомления при смене статуса заказа

КОНТЕКСТ
На бэкенде (Go, монорепо hookah_backend) при смене СТАТУСА ЗАКАЗА (не отдельных позиций/строк заказа — меню или кальянов) пользователю теперь отправляется push-уведомление через Firebase Cloud Messaging (FCM). Изменение статуса отдельной позиции заказа (например, отмена одной строки меню) push НЕ вызывает и не должно вызывать — не ожидай и не обрабатывай такие уведомления как "смену заказа".

Push отправляется в двух местах на бэкенде:
1. При явной смене статуса заказа (order.UpdateStatus) — например new -> in_progress, in_progress -> canceled_by_staff и т.д.
2. При завершении оплаты заказа (order.SubmitPayment), которое переводит статус в completed.

РЕГИСТРАЦИЯ УСТРОЙСТВА (уже реализовано на бэкенде, нужно вызывать из Flutter)
GraphQL-мутации на gateway:
- registerDevice(userId: String!, role: String!, loungeId: String, fcmToken: String!) — вызывать после получения FCM-токена: при логине пользователя и при каждом обновлении токена (FirebaseMessaging.instance.onTokenRefresh).
- unregisterDevice(fcmToken: String!) — вызывать при логауте пользователя, чтобы устройство перестало получать push после выхода из аккаунта.

Обязательно:
- Инициализировать firebase_messaging, запросить разрешение на уведомления (iOS обязательно; Android 13+ через permission_handler или встроенный запрос плагина).
- После инициализации получить текущий токен (FirebaseMessaging.instance.getToken()) и вызвать registerDevice.
- Подписаться на onTokenRefresh и повторно вызывать registerDevice при каждом новом токене.

ФОРМА PUSH-СООБЩЕНИЯ
Push приходит с полями notification.title / notification.body (уже готовый, локализованный на русском текст для показа пользователю) и data — map строк:
- eventType: "order_status_updated"
- orderId: строковое числовое ID заказа
- loungeId: строковое числовое ID заведения
- status: одно из new | in_progress | calculation | completed | canceled | canceled_by_user | canceled_by_staff

Тексты title/body по статусам (для справки, не нужно их переопределять на клиенте — используй присланные title/body как есть):
- in_progress: "Заказ принят" / "Ваш заказ принят и готовится"
- calculation: "Пора рассчитаться" / "Ваш заказ готов к оплате"
- completed: "Заказ завершён" / "Спасибо! Заказ выполнен"
- canceled / canceled_by_user / canceled_by_staff: "Заказ отменён" / "К сожалению, ваш заказ был отменён"
- new и любой нераспознанный статус: "Обновление заказа" / "Статус изменён: <status>"

ЧТО НУЖНО РЕАЛИЗОВАТЬ НА FLUTTER
1. Foreground-обработка: FirebaseMessaging.onMessage — FCM не показывает системное уведомление автоматически, пока приложение активно, поэтому нужно самостоятельно показать локальное уведомление (пакет flutter_local_notifications) с полученными title/body.
2. Обработка тапа по уведомлению (приложение в фоне или закрыто): FirebaseMessaging.onMessageOpenedApp и FirebaseMessaging.instance.getInitialMessage() — прочитать data['orderId'] и открыть экран деталей этого заказа (deep link).
3. После открытия/обработки push обязательно обновить данные заказа с сервера (GraphQL refetch/invalidate по orderId) — push является лишь сигналом о событии, а не источником истины о текущем состоянии заказа; поле status в data можно использовать для мгновенного локального обновления UI, но финальное состояние всегда должно подтягиваться с сервера.
4. Клиент не должен падать или показывать пустой текст на неизвестное значение status — на этот случай сервер уже присылает осмысленный fallback-текст ("Обновление заказа"), просто отображай title/body как есть.
5. Не показывай и не ожидай push при изменении статуса отдельных позиций заказа (меню/кальяны) — такие события намеренно не уведомляют пользователя.

## Settings

- **Тесты:** да, писать тесты
- **Логирование:** verbose (подробные DEBUG-логи)
- **Документация:** да — обязательный чек-поинт документации после реализации (`/aif-docs`)

## Контекст / находки разведки кода

Push-инфраструктура в проекте уже частично реализована, это не работа с нуля:

- `firebase_messaging`, `flutter_local_notifications`, `firebase_core` уже подключены в `pubspec.yaml`.
- `lib/core/notifications/push_service.dart` — уже делает `requestPermission()`, `getToken()`, слушает `onTokenRefresh`, экспортирует `onToken`-колбэк.
- `lib/core/auth/auth_state.dart` — уже вызывает `registerDevice`/`unregisterDevice` на login/logout/restart через `_registerDeviceBestEffort()`/`_unregisterDeviceBestEffort()`.
- `lib/core/graphql/mutations.dart` — `GQLMutations.registerDevice` уже существует, но **не соответствует контракту бэкенда**: отправляет только `fcmToken`/`loungeId`, без обязательных `userId`/`role`.
- `lib/core/graphql/queries.dart` — запрос `me` уже возвращает `id`, `userId`, `roles`, но `AuthState.fetchMe()` использует только `id`, отбрасывая `userId`/`roles` — то есть данные для `registerDevice` уже приходят с сервера, их просто не используют.
- `_role` в `AuthState` заполняется только в `login()` и **не восстанавливается** в `init()` при рестарте приложения с валидным токеном — после перезапуска `role` будет `null`.
- `PushService._handleForegroundMessage` сейчас **ничего не показывает** — только логирует; сделано это осознанно, чтобы не дублировать уведомление, которое сейчас показывается через WS-подписку `orderStatusChanged` в `orders_screen.dart` (`NotificationService.showStatusChanged`). Это противоречит новому требованию — использовать готовый `title`/`body` из push как единственный источник текста уведомления.
- Нет `onMessageOpenedApp`/`getInitialMessage()` — тап по уведомлению вообще не обрабатывается.
- Нет `navigatorKey`/способа навигации вне дерева виджетов.
- `OrderDetailScreen` принимает не `orderId`, а готовый объект `Order` через `route arguments`; запроса "заказ по id" на клиенте нет — есть только список `GQLQueries.orders` (лимит 50). Deep link на тап должен получить заказ свежим запросом и найти нужный по id.

## Tasks

### Фаза 1 — контракт registerDevice (userId/role)

1. [x] **Расширить мутацию `registerDevice` (userId/role)**
   Файлы: `lib/core/graphql/mutations.dart`, `test/core/graphql/device_mutations_test.dart`
   Привести `GQLMutations.registerDevice` к контракту бэкенда: `registerDevice(userId: String!, role: String!, loungeId: String, fcmToken: String!)` — добавить обязательные `userId` и `role`. Обновить тест мутации.

2. [x] **Забирать `userId`/`roles` из ответа `me` в `AuthState`**
   Файл: `lib/core/auth/auth_state.dart`
   Запрос `me` уже возвращает `userId` и `roles`, но `fetchMe()` их не читает. Добавить поле `_userId`/геттер, заполнять из `me['userId']`. Сохранять `roles`, использовать как fallback для `_role`, когда `login()` не задал его (актуально при восстановлении сессии в `init()`, где `_role` сейчас теряется).
   Логи (verbose): `AppLogger.i(_tag, 'fetchMe ok userId=$_userId role=$_role')`; `AppLogger.w(_tag, 'fetchMe response missing userId')`, если поле пустое.

3. [x] **Передавать userId/role в вызовы registerDevice, защититься от их отсутствия**
   Файлы: `lib/core/auth/auth_state.dart`, `test/core/auth/auth_state_push_test.dart`
   Блокируется: 1, 2.
   В `_registerDeviceBestEffort()` передавать `userId`/`role` в мутацию. Так как оба поля обязательны на бэкенде — если хотя бы одно отсутствует, логировать WARN и не отправлять мутацию (сохранить принцип best-effort/никогда не бросать исключение). Дополнить тесты: userId/role попадают в вызов; вызов пропускается при их отсутствии.
   Логи (verbose): `AppLogger.d` перед вызовом с userId/role/loungeId; `AppLogger.w`, если пропущено из-за отсутствующих данных.

**Коммит-чекпоинт 1:** `fix(auth): send userId/role in registerDevice per backend contract`

### Фаза 2 — показ push и обработка тапа

4. [x] **Парсер `OrderPushPayload` для data-payload FCM**
   Файлы: `lib/core/notifications/order_push_payload.dart` (новый), `test/core/notifications/order_push_payload_test.dart` (новый)
   Чистый класс с фабрикой `OrderPushPayload? tryParse(Map<String, dynamic> data)`: `null`, если `eventType != "order_status_updated"` или `orderId` пуст/отсутствует (неизвестные/будущие eventType игнорируются молча, без падений); иначе — заполненный объект (`orderId`, `loungeId`, `status`). Общий код для foreground- и tap-обработчиков, тестируется без мока Firebase.
   Тесты: валидный payload; неверный/отсутствующий `eventType`; отсутствующий `orderId`; отсутствующие необязательные `loungeId`/`status`.

5. [x] **Глобальный `navigatorKey` / `NavigationService`**
   Файлы: `lib/core/navigation/navigation_service.dart` (новый), `lib/main.dart`
   `static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();`, подключить в `MaterialApp(navigatorKey: ...)`. Нужен, чтобы обработчики тапа по push (не имеющие `BuildContext`) могли получить контекст через `navigatorKey.currentContext` и вызвать навигацию.

6. [x] **Показ push-текста как есть + обработка тапа по локальному уведомлению** (заодно создан `lib/core/notifications/push_navigation.dart` из задачи 8 — понадобился раньше по зависимостям)
   Файл: `lib/core/notifications/notification_service.dart`
   Блокируется: 5.
   Добавить `showOrderStatusPush({required orderId, required title, required body})` — показывает переданные `title`/`body` без изменений (не переформулировать на клиенте, сервер уже прислал готовый локализованный текст) на канале `order_status`, с `payload: orderId` в `_plugin.show(...)`. Зарегистрировать `onDidReceiveNotificationResponse` в `_plugin.initialize(...)`: читает `response.payload` (orderId) и переиспользует общий helper навигации из задачи 8 (не дублировать логику поиска/перехода).
   Логи (verbose): `AppLogger.d` перед показом с orderId; `AppLogger.i` в колбэке тапа с orderId; сохранить существующий `AppLogger.w` при ошибке показа.

7. [x] **Foreground-сообщения и фон/terminated-тапы в `PushService`**
   Файл: `lib/core/notifications/push_service.dart`
   Блокируется: 4, 6.
   - `_handleForegroundMessage`: парсить `message.data` через `OrderPushPayload.tryParse`; если не `null` — вызвать `NotificationService.showOrderStatusPush(orderId: ..., title: message.notification?.title ?? 'Обновление заказа', body: message.notification?.body ?? 'Статус изменён')` (fallback — чисто защитный, сервер всегда шлёт notification.title/body). Это заменяет текущее поведение "ничего не показывать, чтобы не дублировать WS-уведомление" — дубликат убирается в задаче 9.
   - Добавить `static void Function(OrderPushPayload payload)? onOrderTap;` — PushService остаётся только про FCM-плпамбинг, саму навигацию подключает `main.dart` (задача 8).
   - В `init()`: `FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap)`; после инициализации — `final initial = await messaging.getInitialMessage(); if (initial != null) _handleNotificationTap(initial);` (случай запуска приложения тапом по push из terminated-состояния).
   - `_handleNotificationTap(RemoteMessage)`: парсинг через `OrderPushPayload.tryParse`, вызов `onOrderTap?.call(payload)` при успехе.
   Логи (verbose): `AppLogger.d`/`AppLogger.w` для foreground-парсинга; `AppLogger.i`/`AppLogger.w` для тап-обработки.

8. [x] **Deep link тапа по уведомлению на `OrderDetailScreen` со свежим запросом заказа**
   Файлы: `lib/core/notifications/push_navigation.dart` (новый), `lib/main.dart`, `test/core/notifications/push_navigation_test.dart` (новый)
   Блокируется: 4, 5, 7.
   Чистая функция `Order? findOrderById(List<Order> orders, String orderId)` — тестируется без Firebase/виджетов. В `lib/main.dart` подключить `PushService.onOrderTap = (payload) => handleOrderPushTap(payload)`:
   1. Дождаться доступности `NavigationService.navigatorKey.currentContext` (через `WidgetsBinding.instance.addPostFrameCallback`/повтор) — актуально для `getInitialMessage()`, который может сработать до построения дерева виджетов.
   2. Получить `AuthState` через контекст; если пользователь не залогинен — WARN и не переходить.
   3. Выполнить свежий сетевой запрос `GQLQueries.orders` через `AuthState.gqlClient.value` (именно свежий запрос с сервера — push лишь сигнал, а не источник истины) и найти заказ через `findOrderById`.
   4. Если найден — `Navigator.pushNamed(context, '/order', arguments: {'order': order})`. Если нет (например, заказ вне окна первых 50 или уже недоступен) — WARN, без падения и без пустого экрана.
   Тот же helper подключить в колбэке `onDidReceiveNotificationResponse` из задачи 6, чтобы тап по локальному и по системному push-уведомлению вели себя одинаково.
   Логи (verbose): `AppLogger.d` перед запросом с orderId; `AppLogger.i` при успешной навигации; `AppLogger.w` при отсутствии авторизации/заказа.

**Коммит-чекпоинт 2:** `feat(push): show order-status push notifications and deep-link taps to order details`

### Фаза 3 — очистка дублирования и проверка

9. **Убрать дублирующее WS-уведомление о статусе заказа**
   Файлы: `lib/screens/orders/orders_screen.dart`, `lib/core/notifications/notification_service.dart` (при необходимости)
   Блокируется: 7.
   Теперь push показывает готовый серверный текст для смены статуса — вызов `NotificationService.showStatusChanged(orderId: id, newStatus: status)` в обработчике WS-подписки `orderStatusChanged` (`orders_screen.dart`, около строки 112) создавал бы второе, по-другому сформулированное уведомление на то же событие. Убрать этот вызов, подписку оставить (она по-прежнему обновляет список заказов в памяти). Если `showStatusChanged` (и константы канала `_statusChannelId`/`_statusChannelName`) после этого нигде не используются — удалить метод; `StatusHelper` не трогать (используется в `widgets/status_badge.dart`).

10. **Прогнать `flutter analyze` и `flutter test`**
    Блокируется: 1–9.
    Прогнать `flutter analyze` и `flutter test` (минимум: новые/изменённые тесты из задач 1, 3, 4, 8, плюс полный набор) и исправить возникшие проблемы перед завершением.

**Коммит-чекпоинт 3:** `fix(push): drop duplicate WS-driven order-status notification now that push owns it`
