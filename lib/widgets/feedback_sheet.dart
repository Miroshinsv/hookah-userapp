import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../core/graphql/mutations.dart';

/// Открывает шторку запроса обратной связи по заказу.
Future<void> showFeedbackSheet(
  BuildContext context, {
  required GraphQLClient client,
  required String title,
  required String loungeName,
  required String loungeId,
  required String orderId,
  String? orderTime,
  String? firstName,
  String? lastName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: false,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => FeedbackSheet(
      client: client,
      title: title,
      loungeName: loungeName,
      loungeId: loungeId,
      orderId: orderId,
      orderTime: orderTime,
      firstName: firstName,
      lastName: lastName,
    ),
  );
}

class FeedbackSheet extends StatefulWidget {
  final GraphQLClient client;
  final String title;
  final String loungeName;
  final String loungeId;
  final String orderId;
  final String? orderTime;
  final String? firstName;
  final String? lastName;

  const FeedbackSheet({
    super.key,
    required this.client,
    required this.title,
    required this.loungeName,
    required this.loungeId,
    required this.orderId,
    this.orderTime,
    this.firstName,
    this.lastName,
  });

  @override
  State<FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<FeedbackSheet> {
  int _selectedScore = 0;
  bool _showCommentField = false;
  final _commentCtrl = TextEditingController();
  bool _submitting = false;
  bool _done = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedScore == 0) return;
    setState(() => _submitting = true);

    final comment = _commentCtrl.text.trim();

    await widget.client.mutate(MutationOptions(
      document: gql(GQLMutations.rateLounge(widget.loungeId, _selectedScore)),
    ));
    if (comment.isNotEmpty) {
      await widget.client.mutate(MutationOptions(
        document: gql(GQLMutations.createComment('lounge', widget.loungeId, comment)),
      ));
    }
    await widget.client.mutate(MutationOptions(
      document: gql(GQLMutations.submitFeedback(
        orderId: widget.orderId,
        loungeId: widget.loungeId,
        score: _selectedScore,
        comment: comment.isEmpty ? null : comment,
        firstName: widget.firstName,
        lastName: widget.lastName,
      )),
    ));

    if (!mounted) return;
    setState(() {
      _submitting = false;
      _done = true;
    });

    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _skip() async {
    setState(() => _submitting = true);
    await widget.client.mutate(MutationOptions(
      document: gql(GQLMutations.cancelFeedbackRequest(widget.orderId)),
    ));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 28,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: cs.onSurface.withAlpha(50),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          if (_done) ...[
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.green, size: 32),
                SizedBox(width: 10),
                Text(
                  'Спасибо за отзыв!',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ] else ...[
            Text(
              widget.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            // Кальянная и время
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store_outlined,
                          size: 16, color: cs.onSurface.withAlpha(153)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          widget.loungeName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                  if (widget.orderTime != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 16, color: cs.onSurface.withAlpha(153)),
                        const SizedBox(width: 6),
                        Text(
                          widget.orderTime!,
                          style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurface.withAlpha(153)),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            const Text('Оцените посещение:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedScore = star),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      star <= _selectedScore
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: star <= _selectedScore
                          ? Colors.amber
                          : Colors.grey.shade400,
                      size: 40,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            if (_showCommentField) ...[
              TextField(
                controller: _commentCtrl,
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
            ] else
              TextButton.icon(
                onPressed: () => setState(() => _showCommentField = true),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Добавить комментарий'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting ? null : _skip,
                    child: const Text('Пропустить'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (_selectedScore == 0 || _submitting) ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Отправить'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
