import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_state.dart';
import '../core/graphql/mutations.dart';
import '../core/graphql/queries.dart';

/// Отображает средний рейтинг и позволяет авторизованному пользователю
/// поставить или обновить оценку (1–5 звёзд).
///
/// [targetType] — "lounge" или "staff"
/// [targetId]   — ID объекта
/// [initialAvg] — начальный avg из уже загруженных данных (показывается сразу)
class RatingWidget extends StatefulWidget {
  final String targetType;
  final String targetId;
  final double? initialAvg;

  const RatingWidget({
    super.key,
    required this.targetType,
    required this.targetId,
    this.initialAvg,
  });

  @override
  State<RatingWidget> createState() => _RatingWidgetState();
}

class _RatingWidgetState extends State<RatingWidget> {
  double? _avg;
  int? _count;
  int _userScore = 0; // 0 = ещё не оценил
  bool _loadingData = false;
  bool _submitting = false;
  bool _initialized = false;
  int _hoverScore = 0;

  @override
  void initState() {
    super.initState();
    _avg = widget.initialAvg;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _fetchData();
    }
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _loadingData = true);

    final client = GraphQLProvider.of(context).value;
    final isLoggedIn = context.read<AuthState>().isLoggedIn;

    // Два запроса параллельно: статистика + проверка оценки пользователя
    final futures = <Future>[
      client.query(QueryOptions(
        document: gql(GQLQueries.ratingStats(
            widget.targetType, widget.targetId)),
        fetchPolicy: FetchPolicy.cacheFirst,
      )),
      if (isLoggedIn)
        client.query(QueryOptions(
          document: gql(GQLQueries.hasRated(
              widget.targetType, widget.targetId)),
          fetchPolicy: FetchPolicy.networkOnly,
        )),
    ];

    final results = await Future.wait(futures);
    if (!mounted) return;

    // ratingStats
    final statsData =
        (results[0] as QueryResult).data?['ratingStats'] as Map<String, dynamic>?;

    // hasRated (если запрашивали)
    Map<String, dynamic>? hasRatedData;
    if (isLoggedIn && results.length > 1) {
      hasRatedData =
          (results[1] as QueryResult).data?['hasRated'] as Map<String, dynamic>?;
    }

    setState(() {
      _loadingData = false;
      if (statsData != null) {
        _avg = (statsData['avgRating'] as num?)?.toDouble() ?? _avg;
        _count = statsData['count'] as int?;
      }
      if (hasRatedData != null) {
        final rated = hasRatedData['rated'] as bool? ?? false;
        _userScore = rated ? (hasRatedData['score'] as int? ?? 0) : 0;
      }
    });
  }

  Future<void> _submitRating(int score) async {
    if (_submitting) return;
    setState(() => _submitting = true);

    final client = GraphQLProvider.of(context).value;
    final mutation = widget.targetType == 'lounge'
        ? GQLMutations.rateLounge(widget.targetId, score)
        : GQLMutations.rateStaff(widget.targetId, score);

    final result = await client.mutate(MutationOptions(
      document: gql(mutation),
    ));
    if (!mounted) return;

    if (!result.hasException) {
      final key =
          widget.targetType == 'lounge' ? 'rateLounge' : 'rateStaff';
      final data = result.data?[key] as Map<String, dynamic>?;
      setState(() {
        _userScore = score;
        if (data != null) {
          _avg = (data['avgRating'] as num?)?.toDouble() ?? _avg;
          _count = data['count'] as int?;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_userScore > 0
                ? 'Оценка обновлена'
                : 'Оценка сохранена'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить оценку'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
    if (mounted) setState(() => _submitting = false);
  }

  void _promptLogin(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Необходима авторизация'),
        content: const Text('Войдите, чтобы оставить оценку.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/auth');
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Средний рейтинг ─────────────────────────────────────────
        if (_avg != null)
          Row(
            children: [
              _StarRow(score: _avg!, size: 18),
              const SizedBox(width: 6),
              Text(
                _avg!.toStringAsFixed(1),
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600),
              ),
              if (_count != null) ...[
                const SizedBox(width: 4),
                Text(
                  '($_count ${_pluralRating(_count!)})',
                  style: TextStyle(
                      color: cs.onSurface.withAlpha(128), fontSize: 13),
                ),
              ],
            ],
          )
        else if (_loadingData)
          Row(
            children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('Загрузка рейтинга…',
                  style: TextStyle(
                      color: cs.onSurface.withAlpha(100), fontSize: 13)),
            ],
          ),

        // ── Оценить ─────────────────────────────────────────────────
        const SizedBox(height: 10),
        if (_loadingData && isLoggedIn)
          const SizedBox.shrink()
        else if (!isLoggedIn)
          GestureDetector(
            onTap: () => _promptLogin(context),
            child: Text(
              'Войдите, чтобы оценить',
              style: TextStyle(
                  color: cs.primary,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.primary),
            ),
          )
        else
          Row(
            children: [
              Text(
                _userScore > 0 ? 'Ваша оценка:' : 'Оценить:',
                style: TextStyle(
                    color: cs.onSurface.withAlpha(153), fontSize: 13),
              ),
              const SizedBox(width: 6),
              ..._buildInteractiveStars(),
              if (_submitting) ...[
                const SizedBox(width: 10),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
      ],
    );
  }

  List<Widget> _buildInteractiveStars() {
    return List.generate(5, (i) {
      final starScore = i + 1;
      final active = _hoverScore > 0 ? _hoverScore : _userScore;
      final filled = starScore <= active;

      return GestureDetector(
        onTap: _submitting ? null : () => _submitRating(starScore),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hoverScore = starScore),
          onExit: (_) => setState(() => _hoverScore = 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              color: filled ? Colors.amber : Colors.grey.shade400,
              size: 28,
            ),
          ),
        ),
      );
    });
  }

  String _pluralRating(int n) {
    if (n % 100 >= 11 && n % 100 <= 19) return 'оценок';
    switch (n % 10) {
      case 1:
        return 'оценка';
      case 2:
      case 3:
      case 4:
        return 'оценки';
      default:
        return 'оценок';
    }
  }
}

/// Ряд заполненных/пустых звёзд для отображения (read-only).
class _StarRow extends StatelessWidget {
  final double score;
  final double size;

  const _StarRow({required this.score, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = i < score.round();
        return Icon(
          filled ? Icons.star_rounded : Icons.star_outline_rounded,
          color: Colors.amber,
          size: size,
        );
      }),
    );
  }
}
