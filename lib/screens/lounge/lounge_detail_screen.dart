import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';
import '../../core/models/lounge.dart';
import '../../core/utils/schedule_parser.dart';

class LoungeDetailScreen extends StatelessWidget {
  const LoungeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lounge = ModalRoute.of(context)!.settings.arguments as Lounge;
    final schedule = ScheduleParser.parse(lounge.schedule);

    return Scaffold(
      appBar: AppBar(title: Text(lounge.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    lounge.name,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                if (lounge.rating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        lounge.rating!.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
              ],
            ),
            if (lounge.shortAddress != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Text(lounge.shortAddress!,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
            if (lounge.phone != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.phone, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Text(lounge.phone!,
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ],
            if (lounge.description != null &&
                lounge.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(lounge.description!),
            ],
            if (schedule.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Расписание',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ...schedule.entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 36,
                        child: Text(e.key,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      Text(e.value),
                    ],
                  ),
                ),
              ),
            ],
            if (lounge.staff.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('Персонал',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...lounge.staff.map(
                (s) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.secondaryContainer,
                    child: const Icon(Icons.person),
                  ),
                  title: Text('${s.firstName} ${s.lastName}'),
                  subtitle: Text(s.displayRole),
                ),
              ),
            ],
            const SizedBox(height: 32),
            _OrderButton(lounge: lounge),
          ],
        ),
      ),
    );
  }
}

class _OrderButton extends StatelessWidget {
  final Lounge lounge;

  const _OrderButton({required this.lounge});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: isLoggedIn
              ? () => Navigator.pushNamed(context, '/order/new', arguments: lounge)
              : () => _promptLogin(context),
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Сделать заказ'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (!isLoggedIn)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Требуется авторизация',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
      ],
    );
  }

  void _promptLogin(BuildContext context) {
    final nav = Navigator.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Необходима авторизация'),
        content: const Text('Войдите или зарегистрируйтесь, чтобы сделать заказ.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              nav.pushNamed('/auth');
            },
            child: const Text('Войти'),
          ),
        ],
      ),
    );
  }
}
