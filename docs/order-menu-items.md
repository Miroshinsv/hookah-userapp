[← Guest Table Sessions, Tobacco Catalog & Push](guest-table-sessions.md) · [Back to README](../README.md)

# Дозаказ позиций меню в активном заказе

Гость с уже открытым (не финальным) заказом может добавить в него позиции меню прямо из приложения, не подзывая персонал. Позиции только **добавляются** — удалить или отменить уже добавленную позицию гость не может: это осознанное ограничение backend (роль `user` не имеет прав ни на `removeOrderItems`, ни на `updateOrderItemsStatus`), отменить ошибочную позицию может только персонал через свою панель.

## Точки входа

Обе ведут к одному и тому же обработчику на `lib/screens/order/order_detail_screen.dart` (`_addMenuItem()`):

1. **«+ Меню»** — кнопка в блоке информации о заказе, под списком текущих позиций и итоговой суммой.
2. **«Меню»** (иконка) — в панели ввода чата с заведением, рядом с полем сообщения.

Обе кнопки видны только пока заказ ещё редактируемый — `Order.isEditable` (`lib/core/models/order.dart`) проверяет статус: `new`, `in_progress` или `calculation`. Для `completed`/`canceled*` кнопки скрыты — backend в любом случае отклонит `addOrderItems` для финального заказа.

Нажатие открывает уже существующий пикер меню (`showMenuItemPicker`, `lib/screens/table/menu_item_picker.dart` — тот же виджет, что и для дозаказа за столом), гость выбирает позицию и количество.

## Что показывает экран

Блок информации о заказе (`_buildOrderInfo()`) отображает текущие `menuItems` и `hookahItems` заказа (название × количество, цена за единицу) и `finalTotal`. Список не рендерится вовсе, если позиций ещё нет — пустой заголовок не показывается.

Цена и списание/начисление баллов лояльности для дозаказанных позиций **не пересчитываются** — скидки и баллы применяются только при создании заказа, поэтому эти поля на экране дозаказа не показаны.

## GraphQL-контракт

`GQLMutations.addOrderItems` (`lib/core/graphql/mutations.dart`) вызывает мутацию с одним элементом списка `menuItems` на вызов (по числу позиций, которые можно выбрать в пикере за раз) — `hookahItems` этой фичей сознательно не передаётся, дозаказ кальяна через UI не реализован:

```graphql
mutation {
  addOrderItems(
    orderId: "..."
    loungeId: "..."
    menuItems: [{ menuItemId: "...", quantity: 1 }]
  ) {
    id
    status
    menuItems { id menuItemId name quantity unitPrice status }
    hookahItems { id name flavor quantity unitPrice status }
    subtotal
    finalTotal
  }
}
```

После успешного ответа экран обновляет `_order` **напрямую из ответа мутации** — никакого push/WS-уведомления о собственном добавлении гостю не приходит (соответствующее серверное событие адресовано только персоналу), это ожидаемое поведение backend, а не баг. `GQLQueries.orders` (`lib/core/graphql/queries.dart`) расширен теми же полями (`menuItems`, `hookahItems`, `subtotal`, `finalTotal`), поэтому список заказов и push-навигация (`lib/core/notifications/push_navigation.dart`) тоже видят актуальные позиции при обычной загрузке.

## Права доступа

- Добавлять позиции может только владелец заказа (JWT соответствует `userId` заказа).
- Добавление возможно только пока статус заказа `new`, `in_progress` или `calculation`.
- Никаких элементов управления для удаления/отмены позиций на экране гостя нет и не будет — у роли `user` просто нет соответствующих прав на backend.

## Обработка ошибок

`_handleAddOrderItemsError()` (`order_detail_screen.dart`) реагирует на текст ошибки от `addOrderItems`:

| Ошибка backend | Реакция UI |
|---|---|
| `order can no longer be modified once it is completed or canceled` | Тост «Заказ уже закрыт, дозаказ недоступен» + перезагрузка состояния заказа (кнопки скрываются сами) |
| `invalid orderId` / `invalid loungeId` | Тост с общим текстом (без технических деталей), полная ошибка уходит в лог как `ERROR` — это баг клиента, не пользователя |
| `forbidden: only the order owner can add items to this order`, `no valid items to add`, любая нераспознанная ошибка | Тост с текстом ошибки сервера + перезагрузка состояния заказа |
| `unauthorized: login required to add items to an order` | Отдельно не обрабатывается — общий `GraphQLClient` (`AuthState._buildClient`) уже форсирует logout при протухшем токене, вне зависимости от того, какой запрос его спровоцировал |

Перезагрузка состояния заказа переиспользует уже существующую чистую функцию `findOrderById` (`lib/core/notifications/push_navigation.dart`) — запрашивает `GQLQueries.orders` и ищет заказ по id, вместо дублирования этой логики.

## See Also

- [Guest Table Sessions, Tobacco Catalog & Push](guest-table-sessions.md) — тот же `showMenuItemPicker`, используется и для дозаказа за столом, и здесь.
- `lib/core/graphql/mutations.dart` / `lib/core/graphql/queries.dart` — где определены `addOrderItems` и расширенный запрос `orders`.
- `lib/core/models/order.dart` — модели `Order`, `OrderMenuItem`, `OrderHookahItem` и геттер `isEditable`.
