# Guest App: Table Selection from Order Screen (Floor Plan)

Branch: `feature/guest-table-selection`
Created: 2026-08-26

## Original Request

/home/msv/GolandProjects/hookah_backend/sitplace.txt

При заказе под кнопкой Меню добавить кнопку "Место", который будет открывать карту заведения с возможностью выбрать стол.

## Settings

- Testing: yes
- Logging: verbose
- Docs: yes (mandatory checkpoint at completion, route through `/aif-docs`)
- Roadmap linkage: none (no ROADMAP.md exists in this project)

## Context / Findings

Source spec: `/home/msv/GolandProjects/hookah_backend/sitplace.txt` — full GraphQL contract for guest-facing table selection, already live on the gateway (no backend changes needed). Confirmed against codebase exploration below. Scope for this plan was explicitly narrowed with the user before task breakdown: the "Место" button lives **only** in `order_detail_screen.dart` (an already-created order), and table selection goes through `openTableSession(tableId, loungeId, orderId, guestCount, failIfOccupied: true)` — **not** `createOrder(tableId, guestCount)`. Wiring table selection into the order-creation flow (`new_order_screen.dart`) is explicitly out of scope for this plan.

**Existing table/session groundwork (from a prior plan, `feature-guest-table-session-tobacco-push.md`), reused here:**

- `lib/core/models/table.dart` — `TableItem` model: `tableId, loungeId, x, y, rotation, seats, label, properties` (properties is a JSON-encoded string list, already parsed via `_parseProperties`/`jsonDecode` with fallback to `[]`). Matches the spec's `tables(loungeId)` shape exactly — **reuse as-is**.
- `lib/core/models/table_session.dart` — `TableSession` model: `sessionId, tableId, orderId, guestCount, status, openedAt`. **Missing `bookedFor`** — must be added (spec's occupancy-classification rule depends on it).
- `lib/core/graphql/queries.dart` — `GQLQueries.tables(loungeId)` (line ~218, fields match spec exactly) and `GQLQueries.activeSessions(loungeId)` (line ~233, currently selects `sessionId tableId orderId guestCount status openedAt` — **missing `bookedFor`**, must be added to the query and the model).
- `lib/screens/table/my_table_screen.dart` — existing join-only table list screen. Renders `TableItem`/`TableSession` as a flat `ListView`, **does not use `x`/`y`/`rotation`** — no existing spatial/floor-plan rendering to reuse. Also: this screen is registered at `/table/my-table` in `main.dart` but is currently **never pushed from anywhere in the UI** — unrelated to this plan, not touched.
- `openTableSession` **does not exist** as a mutation builder anywhere in the app (only referenced in a code comment describing backend behavior) — must be added from scratch.
- `Order` model (`lib/core/models/order.dart`) has **no `tableId`/`tableLabel`/`tableSeatConflict` fields** — must be added (`fromJson`, `copyWith`).
- `Order.isEditable` (line ~88, checks `status` against `{'new', 'in_progress', 'calculation'}`) is the same gate already used for the "Меню" button (`_order.isEditable`, `order_detail_screen.dart:597`) — reuse this gate for "Место" too.

**No existing floor-plan/canvas rendering pattern in this codebase** (confirmed via repo-wide search): no `CustomPainter`/`CustomPaint`, no `InteractiveViewer`, no pan/zoom gesture handling anywhere in `lib/`. The closest analog (`map_screen.dart`) is built entirely on `yandex_mapkit`'s native widget, not Flutter canvas primitives — nothing to lift structurally. This plan introduces the pattern from scratch using only `dart:ui`/`package:flutter` primitives (`CustomPainter`, `Path`, `InteractiveViewer`) — no new package dependency needed. Decision: render walls/windows/doors/zones via a `CustomPainter` inside an `InteractiveViewer` (pan/zoom), and render table markers as `Positioned` widgets in a `Stack` over the painter (simpler and more reliable tap hit-testing than manual canvas hit-testing math, and idiomatic for this Flutter codebase).

**Screen/navigation convention** (confirmed via exploration): `order_detail_screen.dart` has no `Navigator.push`/`pushNamed` calls of its own — all auxiliary UI is done via awaited `showModalBottomSheet`-style helper functions returning a typed result (e.g. `showMenuItemPicker` in `lib/screens/table/menu_item_picker.dart`, used by the existing "Меню" button's `_addMenuItem`). Because the floor plan needs real screen space for pan/zoom (not a bottom sheet), this plan instead pushes a dedicated full-screen route via `Navigator.push(context, MaterialPageRoute(...))` (unregistered in `main.dart`, matching `my_table_screen.dart`'s own navigation style) that pops with a typed result on success — keeping the "awaited result object" shape consistent with the rest of the file.

**AppLogger convention** (`lib/core/utils/logger.dart`, `AppLogger.d/i/w/e`, private `_tag` per class, terse `key=value` messages) — follow exactly as used in `camera_move_debouncer.dart`/`menu_item_picker.dart`/`my_table_screen.dart`.

**Occupancy classification rule** (must match backend/web-admin exactly, per spec):
- No `activeSessions` record for `tableId` → **free**, selectable.
- Record exists, `bookedFor` empty/`"0"` OR `bookedFor` (unix seconds, string) is at most 30 minutes (1800s) after `openedAt` → **occupied now**, not selectable.
- Record exists, `bookedFor` is more than 1800s after `openedAt` → **future booking**, not selectable, shown with a distinct marker/label.
- Comparison is always against `openedAt`, never against device "now".

**Conflict/error handling required** (from spec): a race on `openTableSession` returns an error containing `"table occupied"` — not fatal, show "Это место только что заняли, выберите другое", refresh table/session state, let the guest pick again. Also handle (generic, non-fatal, friendly message): `"стол не найден"`, `"мест меньше, чем гостей"` (client should already prevent this by capping guest-count picker at `seats`, but still handle the server error), `"forbidden: order does not belong to you"` (shouldn't happen from this UI since the guest only ever opens their own order, but handled defensively), `"tables service is not running"` (maps 1:1 to `isTablesEnabled` already being `false` — button should already be hidden in this case, but handle defensively if the check races).

**`isTablesEnabled` gating**: checked once when `order_detail_screen.dart` loads (parallel with the order's own load), stored as `_tablesEnabled` bool, gates whether the "Место" `IconButton` is shown at all — mirrors the existing `_order.isEditable` gate pattern for "Меню" rather than a lazy check on every tap.

## Tasks

### Phase 1: GraphQL layer & models

- [x] **Task 1 — Add `isTablesEnabled` and `floorPlan` query builders**
  File: `lib/core/graphql/queries.dart`
  Add `GQLQueries.isTablesEnabled(String loungeId)` returning `query { isTablesEnabled(loungeId: ...) }`, and `GQLQueries.floorPlan(String loungeId)` returning `query { floorPlan(loungeId: ...) { walls updatedAt } }`, following the existing string-building convention in this file (`jsonEncode` for the loungeId string param, same as `tables`/`activeSessions`).
  Logging: none in this file (pure string builders); logging happens at call sites.
  Dependency: none.

- [x] **Task 2 — Add `FloorPlan` model with walls-blob parsing**
  File: `lib/core/models/floor_plan.dart` (new)
  Add `FloorPlanWall` (`points: List<Offset>`), `FloorPlanOpening` (`x1,y1,x2,y2` doubles — shared shape for windows/doors; doors additionally carry `swing: String?`), `FloorPlanZone` (`x,y,w,h: double, name: String, color: Color` — parse `color` hex string like `#3b82f6` into a `Color`), and `FloorPlan` (`walls: List<FloorPlanWall>, windows: List<FloorPlanOpening>, doors: List<FloorPlanOpening>, zones: List<FloorPlanZone>, updatedAt: String?`).
  `FloorPlan.fromJson(Map<String, dynamic> json)` reads `json['walls']` as a **string** and `jsonDecode`s it to get the nested blob (`{walls, windows, doors, zones}` — note the naming collision: the outer GraphQL field is also called `walls` and contains a string; the decoded blob has its own `walls` key for the wall list). On empty string / `"[]"` / decode failure, return an empty `FloorPlan` (no walls/windows/doors/zones) rather than throwing — log a WARN and continue.
  Logging: `AppLogger.w` on JSON decode failure or unexpected shape (with the raw exception); `AppLogger.d` on successful parse with counts (`walls=N windows=N doors=N zones=N`).
  Dependency: none.

- [x] **Task 3 — Add `bookedFor` to `activeSessions` query + `TableSession` model + occupancy classifier**
  Files: `lib/core/graphql/queries.dart`, `lib/core/models/table_session.dart`
  In `queries.dart`, add `bookedFor` to the `activeSessions` selection set (alongside the existing `tableId status openedAt` — note the spec's example omits `sessionId`/`orderId`/`guestCount` for this query, but keep requesting them too since `openTableSession`'s conflict-refresh flow and any future join-by-session-id logic still needs `sessionId`; adding one extra field is free).
  In `table_session.dart`, add `final String? bookedFor;` to `TableSession`, parsed in `fromJson` (nullable/empty-string safe, same null-safe style as other fields in this file).
  Add a top-level enum `TableOccupancyStatus { free, occupiedNow, futureBooking }` and a function `TableOccupancyStatus classifyTableOccupancy(TableSession? session)` implementing the exact rule from the spec: no session → `free`; session with `bookedFor` empty/`"0"` OR `(int.parse(bookedFor) - int.parse(openedAt)) <= 1800` → `occupiedNow`; otherwise → `futureBooking`. Guard `int.parse` failures (malformed timestamps) by falling back to `occupiedNow` (fail safe — never let a parse error make an occupied table look selectable) and log a WARN.
  Logging: `AppLogger.w` on malformed `bookedFor`/`openedAt` values during classification.
  Dependency: none.

- [x] **Task 4 — Add `openTableSession` mutation builder**
  File: `lib/core/graphql/mutations.dart`
  Add `GQLMutations.openTableSession({required String tableId, required String loungeId, required String orderId, required int guestCount})` returning the mutation from the spec with `failIfOccupied: true` **hardcoded** (never a parameter — the guest client must always pass it), selecting `sessionId tableId status`. Follow the existing string-building convention in this file (see `addOrderItems`/`createOrder` for interpolation style).
  Logging: none in this file (pure string builder).
  Dependency: none.

- [x] **Task 5 — Add `tableId`/`tableLabel`/`tableSeatConflict` to `Order` model**
  File: `lib/core/models/order.dart`
  Add `final String? tableId;`, `final String? tableLabel;`, `final bool tableSeatConflict;` (default `false`). Parse in `fromJson` (null-safe, `tableSeatConflict` defaults to `false` when absent). Add all three to `copyWith` following the existing parameter/field pattern in this class — note `tableId`/`tableLabel` must support being explicitly set back to `null` via `copyWith` (e.g. via a sentinel/`Object?` pattern if that's not already how `copyWith` here handles nullable fields — check the existing convention in this file and match it, don't introduce a new one).
  Logging: none (pure model).
  Dependency: none.

**Commit checkpoint 1**: `feat(table): add floor-plan model, openTableSession mutation, and order table fields`

### Phase 2: Floor plan canvas rendering

- [x] **Task 6 — `FloorPlanPainter` (CustomPainter)**
  File: `lib/widgets/floor_plan/floor_plan_painter.dart` (new)
  A `CustomPainter` taking a `FloorPlan` and painting, in order: `zones` (filled rects with `zone.color` at reduced opacity + a small text label via `TextPainter`), `walls` (each `FloorPlanWall.points` drawn as a continuous `Path` with a solid stroke), `windows`/`doors` (drawn as line segments between their two points, doors in a visually distinct style — dash or different color; ignore the `swing` field per spec, it's not critical for table selection). Canvas coordinate space matches the raw `x`/`y` units from the backend (same units as `TableItem.x/y`) — do not rescale internally; sizing/scaling is the caller's job via `InteractiveViewer`/a fixed-size `SizedBox`.
  `shouldRepaint` compares the `FloorPlan` reference (or an `updatedAt` string comparison) to avoid unnecessary repaints.
  Logging: `AppLogger.d` once per `paint()` call is too noisy — skip per-frame logging; log only in the widget that owns this painter (Task 7) when the underlying `FloorPlan` data changes.
  Dependency: blocked by Task 2.

- [x] **Task 7 — `TableSelectionScreen` skeleton: load state + pan/zoom canvas + table markers**
  File: `lib/screens/table/table_selection_screen.dart` (new)
  A full-screen `StatefulWidget` taking `loungeId` and `orderId` as constructor args (pushed via `Navigator.push(context, MaterialPageRoute(builder: (_) => TableSelectionScreen(loungeId: ..., orderId: ...)))` — not registered in `main.dart`, matching `my_table_screen.dart`'s route style but as a direct push since this screen is always entered with required context, no named-route args-casting needed).
  On `initState`/first load: run `GQLQueries.floorPlan`, `GQLQueries.tables`, `GQLQueries.activeSessions` (via `Future.wait` for the three queries in parallel, using `GraphQLProvider.of(context).value` same as `order_detail_screen.dart`'s `_graphqlClient` pattern), parse into `FloorPlan`/`List<TableItem>`/`List<TableSession>`, build a `Map<String, TableSession>` keyed by `tableId` (mirroring `my_table_screen.dart`'s `_sessionsByTableId`).
  Render: `InteractiveViewer` (pan + pinch-zoom, reasonable `minScale`/`maxScale`, e.g. 0.5–3.0) wrapping a fixed-size `Stack` sized to the floor plan's bounding box (or a sane default canvas size if walls are empty, per spec's "draw empty plan, only tables" case) containing `CustomPaint(painter: FloorPlanPainter(floorPlan))` plus one `Positioned` marker widget per `TableItem` (positioned by `x`/`y`, visually rotated by `rotation` degrees via `Transform.rotate`), each marker colored/labeled by `classifyTableOccupancy(sessionsByTableId[table.tableId])` (free = tappable/highlighted; occupied now = dimmed/red, not tappable; future booking = distinct color + "забронирован" label, not tappable) and showing `table.label ?? table.tableId` plus `table.seats`.
  Loading/error states follow the same `_loading`/`_error` `setState` pattern as `map_screen.dart`'s `_reloadLounges`.
  Logging: verbose — log on load start/success/failure (`loungeId=`, counts of walls/tables/sessions), on each table tap with its classified status.
  Dependency: blocked by Tasks 1, 2, 3, 6.

- [x] **Task 8 — Guest-count picker + table tap → `openTableSession` flow**
  File: `lib/screens/table/table_selection_screen.dart`
  On tapping a **free** table marker: show a small guest-count picker (a simple `AlertDialog`/`showDialog` with a stepper or dropdown from 1 to `table.seats`, default 1 — reuse/adapt the quantity-dialog pattern from `menu_item_picker.dart`'s `_showQuantityDialog` if suitable, capping the max at `seats` instead of an arbitrary max). After the guest confirms a count:
  1. Refresh `tables`/`activeSessions` one more time (per spec's "refresh right before showing confirmation" guidance) and re-verify the tapped table is still classified `free` — if not, show the conflict message immediately without calling the mutation.
  2. Call `GQLMutations.openTableSession(tableId, loungeId, orderId: widget.orderId, guestCount)`.
  3. On success: `Navigator.pop(context, TableSelectionResult(tableId: ..., tableLabel: ..., sessionId: ...))` (define `TableSelectionResult` as a small typed class in this file, mirroring `MenuItemPickResult` in `menu_item_picker.dart`).
  4. On exception containing `"table occupied"`: do **not** pop — show an inline message ("Это место только что заняли, выберите другое"), refresh `tables`/`activeSessions`, stay on screen.
  5. On any other exception: show a generic friendly `SnackBar` with pattern-matched messages for the known error substrings from the spec (`"стол не найден"`, `"мест меньше"`, `"forbidden"`, `"tables service is not running"`), falling back to a generic error message — mirror `order_detail_screen.dart`'s `_handleAddOrderItemsError` structure (pattern-match, then generic fallback) rather than inventing a new error-handling shape.
  Logging: verbose — log the mutation call params, success (`sessionId=`), and every handled error branch with the raw exception message at WARN.
  Dependency: blocked by Tasks 4, 7.

**Commit checkpoint 2**: `feat(table): floor-plan canvas with pan/zoom and guest table selection flow`

### Phase 3: Order screen integration

- [x] **Task 9 — Gate + wire the "Место" button in `order_detail_screen.dart`**
  File: `lib/screens/order/order_detail_screen.dart`
  Add a `bool _tablesEnabled = false;` state field. In the same load path where `_lounge`/`_order` are resolved (`didChangeDependencies`/existing init flow), fire `GQLQueries.isTablesEnabled(_order.loungeId)` once (non-blocking relative to the rest of the screen's content — don't gate the whole screen's loading spinner on this single flag) and `setState(() => _tablesEnabled = result)` on completion; default `false` (button hidden) until resolved or on error.
  In `_buildInput()`, inside the existing `if (_order.isEditable) [...]` block, add a second `IconButton` (e.g. `Icons.event_seat` or `Icons.table_restaurant`, tooltip `'Место'`) right after the existing "Меню" button, shown/enabled only when `_tablesEnabled == true`. `onPressed` (guarded by a busy-flag `_selectingTable`, mirroring `_addingMenuItem`):
  1. `final result = await Navigator.push<TableSelectionResult>(context, MaterialPageRoute(builder: (_) => TableSelectionScreen(loungeId: _order.loungeId, orderId: _order.id)));`
  2. Guard `if (result == null || !mounted) return;`
  3. `setState(() { _order = _order.copyWith(tableId: result.tableId, tableLabel: result.tableLabel); });`
  4. Show a confirmation `SnackBar`: `"Вы выбрали стол ${result.tableLabel}"`.
  Logging: `AppLogger.d` on button press/navigation, `AppLogger.i` on successful table assignment (`tableId=`, `tableLabel=`), `AppLogger.w` if `isTablesEnabled` query fails (non-fatal — button just stays hidden).
  Dependency: blocked by Tasks 5, 7, 8.

- [x] **Task 10 — Show the assigned table somewhere visible in the order UI**
  File: `lib/screens/order/order_detail_screen.dart`
  Where the order's summary/status info is already displayed near the top of the screen (find the existing header/info area that shows order status/arrival time), add a small line/chip showing `"Стол: ${_order.tableLabel}"` when `_order.tableLabel != null`, so the guest has persistent confirmation beyond the one-time `SnackBar`. Keep this minimal — no new dedicated section, just one line matching the existing info style.
  Logging: none (pure display, no new async logic).
  Dependency: blocked by Task 9.

**Commit checkpoint 3**: `feat(order): let the guest pick their table from the order screen`

### Phase 4: Tests

- [x] **Task 11 — Tests: `FloorPlan` parsing + occupancy classification**
  File: `test/floor_plan_test.dart` (new)
  Test `FloorPlan.fromJson` against a payload shaped like the spec's example blob (walls/windows/doors/zones all populated), and against edge cases: `walls` field as `""`/`"[]"` (must produce an empty `FloorPlan`, not throw), a zone with a malformed `color` hex string (must not throw — fall back to a default color and log WARN).
  Test `classifyTableOccupancy`: no session → `free`; session with empty `bookedFor` → `occupiedNow`; session with `bookedFor` exactly `openedAt + 1800` → `occupiedNow` (boundary is inclusive per spec: "не более чем на 30 минут" = `<=`); session with `bookedFor` at `openedAt + 1801` → `futureBooking`; malformed numeric strings → `occupiedNow` (fail-safe) + verify a WARN log is emitted (or at minimum that it doesn't throw, per this project's existing test style — check how prior tests in this repo assert on `AppLogger` calls, if at all, and match that convention rather than inventing a new one).
  Dependency: blocked by Tasks 2, 3.

- [x] **Task 12 — Tests: query/mutation builders + `Order` model fields**
  File: `test/table_selection_test.dart` (new)
  Test `GQLQueries.isTablesEnabled`/`GQLQueries.floorPlan` embed `loungeId` correctly (including a value with a quote/special character, matching the existing `jsonEncode`-escaping test style from `test/lounges_page_test.dart`). Test the updated `GQLQueries.activeSessions` includes `bookedFor` in its selection set. Test `GQLMutations.openTableSession` embeds `tableId`/`loungeId`/`orderId`/`guestCount` correctly and **always** includes `failIfOccupied: true` verbatim in the built string (regression guard — this must never become a caller-controlled parameter). Test `Order.fromJson`/`copyWith` correctly round-trip `tableId`/`tableLabel`/`tableSeatConflict`, including the `tableSeatConflict: true, tableId: null` conflict-response shape from the spec.
  Dependency: blocked by Tasks 1, 4, 5.

**Commit checkpoint 4**: `test(table): cover floor-plan parsing, occupancy rules, and table-selection GraphQL builders`

## Next Steps

To start implementation, run `/aif-implement`. To view/manage tasks, use `/tasks` or `TaskList` (if unavailable in this session, follow the checklist above directly).
