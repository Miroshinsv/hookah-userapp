[Back to README](../README.md)

# Guest Table Sessions, Tobacco Catalog & Push Notifications

Guests can join an already-open table session ("posadka") to order without flagging down staff, browse a lounge's tobacco catalog, and receive push notifications for order status changes.

## Joining a table session

A staff member opens a `TableSession` for a table when seating guests. Once open, a guest can:

1. Open **Мой стол** (My Table) from a lounge's detail screen (`lib/screens/table/my_table_screen.dart`).
2. See every table at that lounge, cross-referenced against currently active sessions (`tables` + `activeSessions` gateway queries).
3. Tap a table that already has an active session to join it.

**The guest app never opens or closes a session itself.** Calling the gateway's `openTableSession` mutation again for a table that already has an active session silently closes the existing one — so the app only ever reads `activeSessions` and joins what's already there. Opening/closing a session remains a staff-only action performed in the seating panel. A regression test (`test/screens/table/my_table_screen_guard_test.dart`) guards against this changing by accident.

Tables with no active session are shown disabled with a prompt to ask staff to open one.

## Adding items to a session

Once joined, **Мой заказ за столом** (`lib/screens/table/session_items_screen.dart`) shows every item the guest has added, with a status:

| Status | Meaning |
|---|---|
| `new` | Waiting for staff confirmation |
| `delivered` | Confirmed / served |
| `canceled` | Rejected by staff |

Guests can only add items and view status — confirming, rejecting, or removing an item is a staff-only action and isn't exposed here.

Adding an item requires picking a menu item first. Since the app had no menu-browsing UI before this feature, a minimal picker (`lib/screens/table/menu_item_picker.dart`) lists the lounge's menu (`menuCategories`/`menuItems` queries) and lets the guest choose a quantity before calling `addSessionItem`.

There's no backend subscription for session-item status changes, so the screen is poll-on-demand: pull-to-refresh, plus an automatic refetch right after adding an item.

## Tobacco catalog

**Каталог табаков** (`lib/screens/lounge/tobacco_catalog_screen.dart`), reachable from a lounge's detail screen, lists the lounge's tobaccos (name, strength, price) via the `tobaccos` query. It's read-only — there's no selection, cart, or pricing flow here. Building a full custom-hookah constructor (multiple tobaccos + `priceCustomHookah` pricing, integrated into order creation) is a separate, future piece of work.

## Push notifications (FCM device registration)

`lib/core/notifications/push_service.dart` requests notification permission, fetches the FCM token, and listens for token refreshes. `AuthState` (`lib/core/auth/auth_state.dart`) uses it to:

- Call `registerDevice` after a successful login or restored session, and again whenever the token refreshes while logged in.
- Call `unregisterDevice` on logout, for the current token — this mutation needs no auth, so it's safe to call even if the session is already invalid server-side.

Both calls are **best-effort**: a failure is logged but never blocks login, session restore, or logout.

Order-status push is a duplicate channel for when the app is backgrounded or closed — while the app is open, the existing WebSocket subscription (`orderStatusChanged`) already updates the UI live, so foreground push messages are logged but intentionally not shown as a second local notification.

**Known gap:** this project ships Android only today (the release CI has no iOS build job, and `ios/Runner` has no `GoogleService-Info.plist` or APNs entitlements configured). Push works on Android; iOS support would need that setup done separately.

## See Also

- Backend GraphQL contract: `gateway/internal/delivery/graphql/schema.go` in the `hookah_backend` repo (`tables`, `activeSessions`, `sessionItems`, `addSessionItem`, `tobaccos`, `registerDevice`, `unregisterDevice`).
- `lib/core/graphql/queries.dart` / `lib/core/graphql/mutations.dart` — where every GraphQL operation used by this feature is defined.
