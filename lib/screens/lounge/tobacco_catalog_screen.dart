import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/lounge.dart';
import '../../core/models/tobacco.dart';
import '../../core/utils/logger.dart';

// Только просмотр каталога табаков кальянной — без выбора/корзины/цен для
// конструктора кастомного кальяна (это отдельная будущая задача).
class TobaccoCatalogScreen extends StatefulWidget {
  const TobaccoCatalogScreen({super.key});

  @override
  State<TobaccoCatalogScreen> createState() => _TobaccoCatalogScreenState();
}

class _TobaccoCatalogScreenState extends State<TobaccoCatalogScreen> {
  static const _tag = 'TobaccoCatalog';

  bool _loading = true;
  String? _error;
  List<HookahTobacco> _tobaccos = const [];

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

    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.tobaccos(lounge.id)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));

    if (!mounted) return;

    if (result.hasException) {
      final message =
          result.exception?.graphqlErrors.firstOrNull?.message ?? 'Не удалось загрузить табаки';
      AppLogger.w(_tag, 'load failed loungeId=${lounge.id}: $message');
      setState(() {
        _loading = false;
        _error = message;
      });
      return;
    }

    final data = (result.data?['tobaccos'] as List<Object?>?) ?? const [];
    final tobaccos = data.cast<Map<String, dynamic>>().map(HookahTobacco.fromJson).toList();

    AppLogger.d(_tag, 'loaded loungeId=${lounge.id} tobaccos=${tobaccos.length}');

    setState(() {
      _loading = false;
      _tobaccos = tobaccos;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Каталог табаков')),
      body: RefreshIndicator(onRefresh: _load, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading && _tobaccos.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _tobaccos.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
        ],
      );
    }
    if (_tobaccos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Center(child: Text('В этой кальянной пока нет табаков в каталоге')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _tobaccos.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tobacco = _tobaccos[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.local_fire_department_outlined),
            title: Text(tobacco.name),
            subtitle: Text('Крепость: ${tobacco.strength}/10'),
            trailing: Text('${tobacco.price.toStringAsFixed(0)} ₽'),
          ),
        );
      },
    );
  }
}
