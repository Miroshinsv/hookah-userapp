import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/auth/auth_state.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/lounge.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/schedule_parser.dart';
import '../../widgets/comments_widget.dart';
import '../../widgets/lounge_photo_gallery.dart';
import '../../widgets/rating_widget.dart';

class LoungeDetailScreen extends StatelessWidget {
  const LoungeDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lounge = ModalRoute.of(context)!.settings.arguments as Lounge;
    final schedule = ScheduleParser.parse(lounge.schedule);

    return Scaffold(
      appBar: AppBar(title: Text(lounge.name)),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lounge.photos.isNotEmpty)
              LoungePhotoGallery(photos: lounge.photos),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [_LoungeInfo(lounge: lounge, schedule: schedule)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoungeInfo extends StatelessWidget {
  final Lounge lounge;
  final Map<String, String> schedule;

  const _LoungeInfo({required this.lounge, required this.schedule});

  @override
  Widget build(BuildContext context) {
    final hasOwner =
        lounge.ownerUserId != null && lounge.ownerUserId!.isNotEmpty;
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lounge.name,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        if (lounge.shortAddress != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.location_on, color: Colors.grey, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  lounge.shortAddress!,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
        if (lounge.phone != null) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: lounge.phone!);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Row(
              children: [
                const Icon(Icons.phone, color: Colors.blue, size: 16),
                const SizedBox(width: 4),
                Text(
                  lounge.phone!,
                  style: const TextStyle(
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
        ],
        if (lounge.description != null && lounge.description!.isNotEmpty) ...[
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
                        style: const TextStyle(fontWeight: FontWeight.w600)),
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
          ...lounge.staff.map((s) => _StaffTile(staff: s, loungeId: lounge.id)),
        ],

        // ── Оценки и отзывы ──────────────────────────────────────────
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        const Text(
          'Оценки и отзывы',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        RatingWidget(
          targetType: 'lounge',
          targetId: lounge.id,
          initialAvg: lounge.rating,
        ),
        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 16),
        CommentsWidget(
          entityType: 'lounge',
          entityId: lounge.id,
        ),

        const SizedBox(height: 24),
        if (hasOwner) ...[
          OutlinedButton.icon(
            onPressed: isLoggedIn
                ? () {
                    AppLogger.d('LoungeDetail', 'open my-table loungeId=${lounge.id}');
                    Navigator.pushNamed(context, '/table/my-table',
                        arguments: lounge);
                  }
                : null,
            icon: const Icon(Icons.table_bar_outlined),
            label: const Text('Мой стол'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          if (!isLoggedIn)
            Padding(
              padding: const EdgeInsets.only(top: 6),
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
          const SizedBox(height: 12),
        ],
        if (hasOwner) ...[
          OutlinedButton.icon(
            onPressed: () {
              AppLogger.d('LoungeDetail', 'open tobacco catalog loungeId=${lounge.id}');
              Navigator.pushNamed(context, '/lounge/tobaccos', arguments: lounge);
            },
            icon: const Icon(Icons.local_fire_department_outlined),
            label: const Text('Каталог табаков'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (lounge.chatEnabled) ...[
          OutlinedButton.icon(
            onPressed: hasOwner && isLoggedIn
                ? () => Navigator.pushNamed(context, '/lounge/chat',
                    arguments: lounge)
                : null,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Написать в чат заведения'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          if (!hasOwner)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.block, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    'Заведение не подключено',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
        ],
        _OrderButton(lounge: lounge),
      ],
    );
  }
}

class _OrderButton extends StatelessWidget {
  final Lounge lounge;

  const _OrderButton({required this.lounge});

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthState>().isLoggedIn;
    final hasOwner =
        lounge.ownerUserId != null && lounge.ownerUserId!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          onPressed: hasOwner
              ? isLoggedIn
                  ? () => Navigator.pushNamed(context, '/order/new',
                      arguments: lounge)
                  : () => _promptLogin(context)
              : null,
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('Сделать заказ'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        if (!hasOwner)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Заведение не подключено',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else if (!isLoggedIn)
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
        content:
            const Text('Войдите или зарегистрируйтесь, чтобы сделать заказ.'),
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

class _StaffTile extends StatefulWidget {
  final StaffMember staff;
  final String loungeId;

  const _StaffTile({required this.staff, required this.loungeId});

  @override
  State<_StaffTile> createState() => _StaffTileState();
}

class _StaffTileState extends State<_StaffTile> {
  Map<String, String>? _schedule;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchSchedule());
  }

  Future<void> _fetchSchedule() async {
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.staffSchedule(widget.staff.id)),
      fetchPolicy: FetchPolicy.cacheFirst,
    ));
    if (!mounted) return;
    final list = result.data?['staffSchedule'] as List<Object?>?;
    Map<String, dynamic>? data;
    if (list != null) {
      for (final entry in list.cast<Map<String, dynamic>>()) {
        if (entry['loungeId'] == widget.loungeId) {
          data = entry;
          break;
        }
      }
    }
    setState(() {
      _loading = false;
      if (data != null) {
        _schedule = ScheduleParser.parseCurrentWeek(data['schedule'] as String?);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
              backgroundImage: widget.staff.photoUrl != null
                  ? NetworkImage(widget.staff.photoUrl!)
                  : null,
              child: widget.staff.photoUrl == null
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text('${widget.staff.firstName} ${widget.staff.lastName}'),
            subtitle: Text(widget.staff.displayRoles),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () => Navigator.pushNamed(
              context,
              '/staff',
              arguments: widget.staff,
            ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(left: 56, bottom: 8),
              child: SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (_schedule != null && _schedule!.isNotEmpty)
            _ScheduleChips(schedule: _schedule!),
        ],
      ),
    );
  }
}

class _ScheduleChips extends StatelessWidget {
  final Map<String, String> schedule;

  const _ScheduleChips({required this.schedule});

  static const _allDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 56, bottom: 12),
      child: Row(
        children: _allDays.map((day) {
          final isWorking = schedule.containsKey(day);
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Tooltip(
              message: isWorking ? schedule[day]! : 'Не работает',
              child: Container(
                width: 32,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isWorking ? cs.primaryContainer : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  day,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isWorking ? FontWeight.bold : FontWeight.normal,
                    color: isWorking
                        ? cs.onPrimaryContainer
                        : Colors.grey.shade400,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
