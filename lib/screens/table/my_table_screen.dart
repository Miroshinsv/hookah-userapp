import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/lounge.dart';
import '../../core/models/table.dart';
import '../../core/models/table_session.dart';
import '../../core/utils/logger.dart';

// Экран выбора стола. Гость только присоединяется к уже открытой персоналом
// посадке — openTableSession/closeTableSession здесь никогда не вызываются:
// повторный openTableSession для стола с активной сессией молча закрывает её.
class MyTableScreen extends StatefulWidget {
  const MyTableScreen({super.key});

  @override
  State<MyTableScreen> createState() => _MyTableScreenState();
}

class _MyTableScreenState extends State<MyTableScreen> {
  static const _tag = 'MyTable';

  bool _loading = true;
  String? _error;
  List<TableItem> _tables = const [];
  Map<String, TableSession> _sessionsByTableId = const {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final lounge = ModalRoute.of(context)!.settings.arguments as Lounge;
    setState(() {
      _loading = true;
      _error = null;
    });

    final client = GraphQLProvider.of(context).value;
    AppLogger.d(_tag, 'load loungeId=${lounge.id}');

    final tablesResult = await client.query(QueryOptions(
      document: gql(GQLQueries.tables(lounge.id)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    final sessionsResult = await client.query(QueryOptions(
      document: gql(GQLQueries.activeSessions(lounge.id)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;

    if (tablesResult.hasException || sessionsResult.hasException) {
      final message = tablesResult.exception?.graphqlErrors.firstOrNull?.message ??
          sessionsResult.exception?.graphqlErrors.firstOrNull?.message ??
          'Не удалось загрузить столы';
      AppLogger.w(_tag, 'load failed loungeId=${lounge.id}: $message');
      setState(() {
        _loading = false;
        _error = message;
      });
      return;
    }

    final tablesData = (tablesResult.data?['tables'] as List<Object?>?) ?? const [];
    final sessionsData =
        (sessionsResult.data?['activeSessions'] as List<Object?>?) ?? const [];

    final tables = tablesData
        .cast<Map<String, dynamic>>()
        .map(TableItem.fromJson)
        .toList();
    final sessions = sessionsData
        .cast<Map<String, dynamic>>()
        .map(TableSession.fromJson)
        .toList();

    AppLogger.d(
      _tag,
      'loaded loungeId=${lounge.id} tables=${tables.length} activeSessions=${sessions.length}',
    );

    setState(() {
      _loading = false;
      _tables = tables;
      _sessionsByTableId = {for (final s in sessions) s.tableId: s};
    });
  }

  void _joinSession(Lounge lounge, TableItem table, TableSession session) {
    AppLogger.i(
      _tag,
      'join sessionId=${session.sessionId} tableId=${table.tableId} loungeId=${lounge.id}',
    );
    Navigator.pushNamed(
      context,
      '/table/session',
      arguments: {
        'sessionId': session.sessionId,
        'loungeId': lounge.id,
        'tableLabel': table.label ?? table.tableId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lounge = ModalRoute.of(context)!.settings.arguments as Lounge;

    return Scaffold(
      appBar: AppBar(title: const Text('Мой стол')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(lounge),
      ),
    );
  }

  Widget _buildBody(Lounge lounge) {
    if (_loading && _tables.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _tables.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: Colors.grey.shade500),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
        ],
      );
    }
    if (_tables.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('В этой кальянной пока нет столов')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tables.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final table = _tables[index];
        final session = _sessionsByTableId[table.tableId];
        final isOpen = session != null;

        return Card(
          child: ListTile(
            enabled: isOpen,
            leading: Icon(
              Icons.table_bar,
              color: isOpen ? Theme.of(context).colorScheme.primary : Colors.grey,
            ),
            title: Text(table.label ?? 'Стол ${table.tableId}'),
            subtitle: Text(
              isOpen
                  ? 'Посадка открыта · мест: ${table.seats}'
                  : 'Посадка ещё не открыта — обратитесь к персоналу',
            ),
            trailing: isOpen ? const Icon(Icons.chevron_right) : null,
            onTap: isOpen ? () => _joinSession(lounge, table, session) : null,
          ),
        );
      },
    );
  }
}
