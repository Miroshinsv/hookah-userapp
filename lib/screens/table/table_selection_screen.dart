import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';

import '../../core/graphql/mutations.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/floor_plan.dart';
import '../../core/models/table.dart';
import '../../core/models/table_session.dart';
import '../../core/utils/logger.dart';
import '../../widgets/floor_plan/floor_plan_painter.dart';

class TableSelectionResult {
  final String sessionId;
  final String tableId;
  final String tableLabel;

  const TableSelectionResult({
    required this.sessionId,
    required this.tableId,
    required this.tableLabel,
  });
}

// Полноэкранная карта зала для выбора стола к уже созданному заказу
// (sitplace.txt). Пушится через Navigator.push и возвращает
// TableSelectionResult через Navigator.pop при успешном выборе — вызывающий
// экран (order_detail_screen.dart) сам сохраняет результат в свой Order.
class TableSelectionScreen extends StatefulWidget {
  final String loungeId;
  final String orderId;

  const TableSelectionScreen({
    super.key,
    required this.loungeId,
    required this.orderId,
  });

  @override
  State<TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends State<TableSelectionScreen> {
  static const _tag = 'TableSelection';
  static const _markerSize = 56.0;
  static const _defaultCanvasSize = Size(800, 560);

  bool _loading = true;
  String? _error;
  bool _selecting = false;
  FloorPlan _floorPlan = FloorPlan.empty;
  List<TableItem> _tables = const [];
  Map<String, TableSession> _sessionsByTableId = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  GraphQLClient get _client => GraphQLProvider.of(context).value;

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    AppLogger.d(_tag, 'load loungeId=${widget.loungeId}');
    final results = await Future.wait([
      _client.query(QueryOptions(
        document: gql(GQLQueries.floorPlan(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
      _client.query(QueryOptions(
        document: gql(GQLQueries.tables(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
      _client.query(QueryOptions(
        document: gql(GQLQueries.activeSessions(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
    ]);
    if (!mounted) return;

    final floorPlanResult = results[0];
    final tablesResult = results[1];
    final sessionsResult = results[2];

    if (floorPlanResult.hasException || tablesResult.hasException || sessionsResult.hasException) {
      final message = floorPlanResult.exception?.graphqlErrors.firstOrNull?.message ??
          tablesResult.exception?.graphqlErrors.firstOrNull?.message ??
          sessionsResult.exception?.graphqlErrors.firstOrNull?.message ??
          'Не удалось загрузить карту зала';
      AppLogger.w(_tag, 'load failed loungeId=${widget.loungeId}: $message');
      setState(() {
        _loading = false;
        _error = message;
      });
      return;
    }

    final floorPlanData = floorPlanResult.data?['floorPlan'] as Map<String, dynamic>?;
    final floorPlan = floorPlanData != null ? FloorPlan.fromJson(floorPlanData) : FloorPlan.empty;
    final tables = _parseTables(tablesResult);
    final sessionsByTableId = _parseSessions(sessionsResult);

    AppLogger.d(
      _tag,
      'loaded loungeId=${widget.loungeId} walls=${floorPlan.walls.length} '
      'tables=${tables.length} sessions=${sessionsByTableId.length}',
    );

    setState(() {
      _loading = false;
      _floorPlan = floorPlan;
      _tables = tables;
      _sessionsByTableId = sessionsByTableId;
    });
  }

  List<TableItem> _parseTables(QueryResult result) {
    final data = (result.data?['tables'] as List<Object?>?) ?? const [];
    return data.cast<Map<String, dynamic>>().map(TableItem.fromJson).toList();
  }

  Map<String, TableSession> _parseSessions(QueryResult result) {
    final data = (result.data?['activeSessions'] as List<Object?>?) ?? const [];
    final sessions = data.cast<Map<String, dynamic>>().map(TableSession.fromJson).toList();
    return {for (final s in sessions) s.tableId: s};
  }

  // Обновляет tables/activeSessions без перезагрузки floorPlan (план
  // помещения меняется редко, а вот занятость столов — часто) — вызывается
  // и перед отправкой openTableSession, и после конфликта "table occupied".
  Future<void> _refreshTablesAndSessions() async {
    AppLogger.d(_tag, 'refresh tables/sessions loungeId=${widget.loungeId}');
    final results = await Future.wait([
      _client.query(QueryOptions(
        document: gql(GQLQueries.tables(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
      _client.query(QueryOptions(
        document: gql(GQLQueries.activeSessions(widget.loungeId)),
        fetchPolicy: FetchPolicy.networkOnly,
      )),
    ]);
    if (!mounted) return;

    final tablesResult = results[0];
    final sessionsResult = results[1];
    if (tablesResult.hasException || sessionsResult.hasException) {
      AppLogger.w(_tag, 'refresh tables/sessions failed loungeId=${widget.loungeId}');
      return;
    }
    setState(() {
      _tables = _parseTables(tablesResult);
      _sessionsByTableId = _parseSessions(sessionsResult);
    });
  }

  Future<void> _onTableTap(TableItem table) async {
    AppLogger.d(_tag, 'tap tableId=${table.tableId} seats=${table.seats}');
    final guestCount = await _showGuestCountDialog(table);
    if (guestCount == null || !mounted) return;
    await _selectTable(table, guestCount);
  }

  Future<int?> _showGuestCountDialog(TableItem table) {
    var guestCount = 1;
    final maxGuests = table.seats > 0 ? table.seats : 1;
    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Стол ${table.label ?? table.tableId}'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: guestCount > 1 ? () => setDialogState(() => guestCount--) : null,
                icon: const Icon(Icons.remove_circle_outline),
              ),
              Text('$guestCount', style: const TextStyle(fontSize: 18)),
              IconButton(
                onPressed:
                    guestCount < maxGuests ? () => setDialogState(() => guestCount++) : null,
                icon: const Icon(Icons.add_circle_outline),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, guestCount),
              child: const Text('  Выбрать  '),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTable(TableItem table, int guestCount) async {
    setState(() => _selecting = true);

    // Обновляем занятость прямо перед отправкой — состояние могло измениться,
    // пока гость рассматривал карту/выбирал число гостей.
    await _refreshTablesAndSessions();
    if (!mounted) return;

    final currentStatus = classifyTableOccupancy(_sessionsByTableId[table.tableId]);
    if (currentStatus != TableOccupancyStatus.free) {
      setState(() => _selecting = false);
      AppLogger.w(_tag, 'tableId=${table.tableId} no longer free before mutation: $currentStatus');
      _showConflictMessage();
      return;
    }

    AppLogger.d(
      _tag,
      'openTableSession tableId=${table.tableId} loungeId=${widget.loungeId} '
      'orderId=${widget.orderId} guestCount=$guestCount',
    );
    final result = await _client.mutate(MutationOptions(
      document: gql(GQLMutations.openTableSession(
        tableId: table.tableId,
        loungeId: widget.loungeId,
        orderId: widget.orderId,
        guestCount: guestCount,
      )),
    ));
    if (!mounted) return;
    setState(() => _selecting = false);

    if (result.hasException) {
      await _handleOpenTableSessionError(result.exception);
      return;
    }

    final data = result.data?['openTableSession'] as Map<String, dynamic>?;
    final sessionId = data?['sessionId'] as String?;
    final resultTableId = data?['tableId'] as String?;
    if (sessionId == null || resultTableId == null) {
      AppLogger.w(_tag, 'openTableSession returned no session/table id, treating as conflict');
      _showConflictMessage();
      await _refreshTablesAndSessions();
      return;
    }

    AppLogger.i(_tag, 'openTableSession ok sessionId=$sessionId tableId=$resultTableId');
    if (!mounted) return;
    Navigator.pop(
      context,
      TableSelectionResult(
        sessionId: sessionId,
        tableId: resultTableId,
        tableLabel: table.label ?? table.tableId,
      ),
    );
  }

  // Реакция на ошибки openTableSession по sitplace.txt разделу "Возможные
  // ошибки". "table occupied" — гонка за столом, не фатально для заказа.
  Future<void> _handleOpenTableSessionError(OperationException? exception) async {
    final message = exception?.graphqlErrors.firstOrNull?.message;
    AppLogger.w(_tag, 'openTableSession failed: $message', exception);

    if (message != null && message.contains('table occupied')) {
      _showConflictMessage();
      await _refreshTablesAndSessions();
      return;
    }
    if (message != null && message.contains('forbidden')) {
      _showSnackBar('Недостаточно прав для выбора стола');
      return;
    }
    if (message != null && message.contains('мест меньше')) {
      _showSnackBar('За этот стол не поместится вся компания — выберите другой');
      return;
    }
    if (message != null && message.contains('стол не найден')) {
      _showSnackBar('Этот стол больше недоступен');
      await _refreshTablesAndSessions();
      return;
    }
    if (message != null && message.contains('tables service is not running')) {
      _showSnackBar('Выбор стола временно недоступен');
      return;
    }
    _showSnackBar(message ?? 'Не удалось выбрать стол');
  }

  void _showConflictMessage() =>
      _showSnackBar('Это место только что заняли, выберите другое');

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Size _computeCanvasSize() {
    var maxX = _defaultCanvasSize.width;
    var maxY = _defaultCanvasSize.height;
    for (final table in _tables) {
      if (table.x + _markerSize > maxX) maxX = table.x + _markerSize;
      if (table.y + _markerSize > maxY) maxY = table.y + _markerSize;
    }
    for (final wall in _floorPlan.walls) {
      for (final point in wall.points) {
        if (point.dx + 40 > maxX) maxX = point.dx + 40;
        if (point.dy + 40 > maxY) maxY = point.dy + 40;
      }
    }
    return Size(maxX, maxY);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Выбор стола')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: _load, child: const Text('Повторить')),
            ],
          ),
        ),
      );
    }

    final canvasSize = _computeCanvasSize();
    return Stack(
      children: [
        InteractiveViewer(
          minScale: 0.5,
          maxScale: 3,
          constrained: false,
          boundaryMargin: const EdgeInsets.all(80),
          child: SizedBox(
            width: canvasSize.width,
            height: canvasSize.height,
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: FloorPlanPainter(_floorPlan))),
                ..._tables.map(_buildTableMarker),
              ],
            ),
          ),
        ),
        if (_selecting)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black26,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  Widget _buildTableMarker(TableItem table) {
    final status = classifyTableOccupancy(_sessionsByTableId[table.tableId]);
    final Color color;
    final String statusLabel;
    switch (status) {
      case TableOccupancyStatus.free:
        color = const Color(0xFF43A047);
        statusLabel = 'Свободен';
        break;
      case TableOccupancyStatus.occupiedNow:
        color = const Color(0xFFE53935);
        statusLabel = 'Занят';
        break;
      case TableOccupancyStatus.futureBooking:
        color = const Color(0xFFFB8C00);
        statusLabel = 'Забронирован';
        break;
    }
    final tappable = status == TableOccupancyStatus.free;

    return Positioned(
      left: table.x - _markerSize / 2,
      top: table.y - _markerSize / 2,
      child: Transform.rotate(
        angle: table.rotation * math.pi / 180,
        child: Tooltip(
          message: '${table.label ?? table.tableId} · ${table.seats} мест · $statusLabel',
          child: GestureDetector(
            onTap: tappable ? () => _onTableTap(table) : null,
            child: Container(
              width: _markerSize,
              height: _markerSize,
              decoration: BoxDecoration(
                color: color.withValues(alpha: tappable ? 0.85 : 0.5),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(
                table.label ?? table.tableId,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
