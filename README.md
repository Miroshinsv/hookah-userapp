# user_app

> Guest-facing Flutter app for ordering at hookah lounges.

Hookah Order User App — lets guests browse lounges, place orders, join an open table session to add items themselves, check a lounge's tobacco catalog, and chat with lounge staff, all backed by a GraphQL gateway.

## Quick Start

```bash
flutter pub get
flutter run
```

## Key Features

- **Lounges** — browse nearby lounges on a map, view details, ratings, and staff
- **Orders** — place an order, track its status live, and add menu items to it while it's still open
- **Table sessions** — join an already-open table session and add menu items yourself, without flagging down staff
- **Tobacco catalog** — browse a lounge's available tobaccos
- **Chat** — message lounge staff or a specific staff member directly
- **Push notifications** — get notified of order status changes even when the app is backgrounded

## Documentation

| Guide | Description |
|-------|-------------|
| [Guest Table Sessions, Tobacco Catalog & Push](docs/guest-table-sessions.md) | Joining a table session, adding items, tobacco catalog, FCM push registration & order-status alerts |
| [Order Menu Items](docs/order-menu-items.md) | Adding menu items to an already-open order, item/total display, error handling, and reacting to staff-side confirm/cancel/delete actions via chat |

## Getting Started (Flutter)

This project is a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
