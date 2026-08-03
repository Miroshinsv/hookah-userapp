import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import '../core/auth/auth_state.dart';
import '../core/graphql/mutations.dart';
import '../core/graphql/queries.dart';
import '../core/models/comment.dart';

/// Список отзывов + форма добавления для авторизованных пользователей.
///
/// [entityType] — "lounge" или "staff"
/// [entityId]   — ID объекта
class CommentsWidget extends StatefulWidget {
  final String entityType;
  final String entityId;

  const CommentsWidget({
    super.key,
    required this.entityType,
    required this.entityId,
  });

  @override
  State<CommentsWidget> createState() => _CommentsWidgetState();
}

class _CommentsWidgetState extends State<CommentsWidget> {
  List<Comment> _comments = [];
  bool _loading = true;
  bool _submitting = false;
  bool _showForm = false;
  final _textController = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _fetchComments();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _fetchComments() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.comments(widget.entityType, widget.entityId)),
      fetchPolicy: FetchPolicy.networkOnly,
    ));
    if (!mounted) return;
    final list = result.data?['comments'] as List<dynamic>?;
    setState(() {
      _loading = false;
      _comments = list
              ?.map((e) => Comment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    });
  }

  Future<void> _submitComment() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    final client = GraphQLProvider.of(context).value;
    final result = await client.mutate(MutationOptions(
      document: gql(GQLMutations.createComment(
        widget.entityType,
        widget.entityId,
        text,
      )),
    ));
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!result.hasException) {
      _textController.clear();
      setState(() => _showForm = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Отзыв отправлен на модерацию'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось отправить отзыв'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _promptLogin() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Необходима авторизация'),
        content: const Text('Войдите, чтобы оставить отзыв.'),
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
    final authState = context.watch<AuthState>();
    final isLoggedIn = authState.isLoggedIn;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Отзывы',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            if (!_loading && _comments.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(
                '(${_comments.length})',
                style: TextStyle(
                    color: cs.onSurface.withAlpha(128), fontSize: 13),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // Список
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_comments.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Отзывов пока нет. Будьте первым!',
              style: TextStyle(
                  color: cs.onSurface.withAlpha(128), fontSize: 14),
            ),
          )
        else
          ..._comments.map((c) => _CommentCard(comment: c)),

        const SizedBox(height: 8),

        // Кнопка / форма
        if (!isLoggedIn)
          GestureDetector(
            onTap: _promptLogin,
            child: Text(
              'Войдите, чтобы оставить отзыв',
              style: TextStyle(
                color: cs.primary,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: cs.primary,
              ),
            ),
          )
        else if (_showForm)
          _CommentForm(
            controller: _textController,
            submitting: _submitting,
            onSubmit: _submitComment,
            onCancel: () {
              _textController.clear();
              setState(() => _showForm = false);
            },
          )
        else
          TextButton.icon(
            onPressed: () => setState(() => _showForm = true),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: const Text('Написать отзыв'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }
}

// ─── Карточка одного отзыва ───────────────────────────────────────────────────

class _CommentCard extends StatelessWidget {
  final Comment comment;

  const _CommentCard({required this.comment});

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.isUtc ? dt.toLocal() : dt;
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.isNegative) {
      return '${local.day}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    }
    if (diff.inDays == 0) return 'сегодня';
    if (diff.inDays == 1) return 'вчера';
    if (diff.inDays < 7) return '${diff.inDays} дн. назад';
    return '${local.day}.${local.month.toString().padLeft(2, '0')}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const name = 'Пользователь';
    const initial = 'П';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.secondaryContainer,
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: cs.onSecondaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      name,
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      _formatDate(comment.createdAt),
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withAlpha(100)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  comment.text,
                  style: const TextStyle(fontSize: 14, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Форма добавления отзыва ──────────────────────────────────────────────────

class _CommentForm extends StatelessWidget {
  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const _CommentForm({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Поделитесь впечатлениями…',
            border: OutlineInputBorder(),
            contentPadding: EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: submitting ? null : onCancel,
              child: const Text('Отмена'),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: submitting ? null : onSubmit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Отправить'),
            ),
          ],
        ),
      ],
    );
  }
}
