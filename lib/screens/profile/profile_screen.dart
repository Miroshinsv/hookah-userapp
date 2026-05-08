import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/auth/auth_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthState>();

    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                child: const Icon(Icons.person, size: 44),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                auth.phone ?? 'Не указан',
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            const Center(
              child: Text('Пользователь',
                  style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 32),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.phone),
              title: const Text('Телефон'),
              subtitle: Text(auth.phone ?? '—'),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (dialogContext) => AlertDialog(
                      title: const Text('Выход'),
                      content:
                          const Text('Вы уверены, что хотите выйти?'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(dialogContext, false),
                            child: const Text('Отмена')),
                        TextButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Выйти')),
                      ],
                    ),
                  );
                  if (confirm == true && context.mounted) {
                    await auth.logout();
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Выйти из аккаунта'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
