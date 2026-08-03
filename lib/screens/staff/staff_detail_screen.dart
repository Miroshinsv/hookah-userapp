import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graphql/queries.dart';
import '../../core/models/lounge.dart';
import '../../core/utils/schedule_parser.dart';
import '../../widgets/comments_widget.dart';
import '../../widgets/rating_widget.dart';

class StaffDetailScreen extends StatefulWidget {
  const StaffDetailScreen({super.key});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;
  String? _error;
  bool _fetchStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_fetchStarted) {
      _fetchStarted = true;
      _fetchProfile();
    }
  }

  Future<void> _fetchProfile() async {
    final staff = ModalRoute.of(context)!.settings.arguments as StaffMember;
    final client = GraphQLProvider.of(context).value;
    final result = await client.query(QueryOptions(
      document: gql(GQLQueries.staffProfile(staff.id)),
      fetchPolicy: FetchPolicy.cacheFirst,
    ));
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.hasException) {
        _error = result.exception?.graphqlErrors.isNotEmpty == true
            ? result.exception!.graphqlErrors.first.message
            : 'Ошибка загрузки';
      } else {
        _profile = result.data?['staffProfile'] as Map<String, dynamic>?;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final staff = ModalRoute.of(context)!.settings.arguments as StaffMember;
    return Scaffold(
      appBar: AppBar(
        title: Text(staff.displayRoles),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 48, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.redAccent)),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _loading = true;
                              _error = null;
                            });
                            _fetchProfile();
                          },
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : _profile == null
                  ? const Center(child: Text('Нет данных'))
                  : _ProfileBody(profile: _profile!, staff: staff),
    );
  }
}

// ─── Основной контент профиля ─────────────────────────────────────────────────

class _ProfileBody extends StatelessWidget {
  final Map<String, dynamic> profile;
  final StaffMember staff;

  const _ProfileBody({required this.profile, required this.staff});

  static const _roleLabels = {
    'hookah_master': 'Кальянный мастер',
    'hostess': 'Хостес',
    'waiter': 'Официант',
    'admin': 'Администратор',
    'owner': 'Владелец',
  };

  @override
  Widget build(BuildContext context) {
    final roles = (profile['roles'] as List<dynamic>?)
            ?.map((e) => e as String)
            .where((r) => r != 'owner' && r != 'deputy')
            .map((r) => _roleLabels[r] ?? r)
            .join(', ') ??
        '—';
    final bio = profile['bio'] as String?;
    final rating = (profile['rating'] as num?)?.toDouble();
    final photoUrl = profile['photoUrl'] as String?;
    final lounges = (profile['lounges'] as List<dynamic>?)
            ?.map((l) => l as Map<String, dynamic>)
            .toList() ??
        [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Аватар + имя ──────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor:
                      Theme.of(context).colorScheme.secondaryContainer,
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Icon(Icons.person,
                          size: 56,
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer)
                      : null,
                ),
                const SizedBox(height: 14),
                Text(
                  roles,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          // ── Биография ─────────────────────────────────────────────────
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            Text(bio,
                style: const TextStyle(fontSize: 15, height: 1.55)),
          ],

          // ── Расписание по заведениям ──────────────────────────────────
          if (lounges.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const Text('Расписание',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...lounges.map((l) => _LoungeScheduleCard(lounge: l)),
          ],

          // ── Оценки и отзывы ───────────────────────────────────────────
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 12),
          const Text(
            'Оценки и отзывы',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          RatingWidget(
            targetType: 'staff',
            targetId: staff.id,
            initialAvg: rating,
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          CommentsWidget(
            entityType: 'staff',
            entityId: staff.id,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Карточка расписания в одном заведении ────────────────────────────────────

class _LoungeScheduleCard extends StatelessWidget {
  final Map<String, dynamic> lounge;
  const _LoungeScheduleCard({required this.lounge});

  @override
  Widget build(BuildContext context) {
    final name = lounge['name'] as String? ?? '';
    final shortAddress = lounge['shortAddress'] as String?;
    final schedule =
        ScheduleParser.parseCurrentWeek(lounge['schedule'] as String?);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14)),
          if (shortAddress != null && shortAddress.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              shortAddress,
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha(128),
                  fontSize: 12),
            ),
          ],
          const SizedBox(height: 8),
          if (schedule.isNotEmpty)
            _ScheduleChipsRow(schedule: schedule)
          else
            Text(
              'Расписание не указано',
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withAlpha(100),
                  fontSize: 12),
            ),
        ],
      ),
    );
  }
}

// ─── Строка чипов дней недели ─────────────────────────────────────────────────

class _ScheduleChipsRow extends StatelessWidget {
  final Map<String, String> schedule;
  const _ScheduleChipsRow({required this.schedule});

  static const _allDays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: _allDays.map((day) {
        final isWorking = schedule.containsKey(day);
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Tooltip(
            message: isWorking ? schedule[day]! : 'Не работает',
            child: Container(
              width: 34,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isWorking
                    ? cs.primaryContainer
                    : cs.surface.withAlpha(80),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isWorking
                      ? cs.primaryContainer
                      : cs.onSurface.withAlpha(30),
                ),
              ),
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isWorking
                      ? FontWeight.bold
                      : FontWeight.normal,
                  color: isWorking
                      ? cs.onPrimaryContainer
                      : cs.onSurface.withAlpha(90),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
