import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../core/graphql/queries.dart';
import '../../core/utils/schedule_parser.dart';

class StaffProfileScreen extends StatelessWidget {
  const StaffProfileScreen({super.key});

  static const _roleLabels = {
    'hookah_master': 'Кальянный мастер',
    'hostess': 'Хостес',
    'waiter': 'Официант',
    'admin': 'Администратор',
    'owner': 'Владелец',
  };

  @override
  Widget build(BuildContext context) {
    final staffId = ModalRoute.of(context)!.settings.arguments as String;

    return Query(
      options: QueryOptions(
        document: gql(GQLQueries.staffProfile(staffId)),
        fetchPolicy: FetchPolicy.cacheFirst,
      ),
      builder: (result, {fetchMore, refetch}) {
        if (result.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (result.hasException || result.data == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Профиль')),
            body: Center(
              child: Text(
                'Не удалось загрузить профиль',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
          );
        }

        final d = result.data!['staffProfile'] as Map<String, dynamic>;
        final firstName = d['firstName'] as String? ?? '';
        final lastName = d['lastName'] as String? ?? '';
        final bio = d['bio'] as String?;
        final photoUrl = d['photoUrl'] as String?;
        final rating = (d['rating'] as num?)?.toDouble();
        final roles = (d['roles'] as List<dynamic>?)
                ?.map((e) => e as String)
                .where((r) => r != 'owner')
                .toList() ??
            [];
        final lounges = (d['lounges'] as List<dynamic>?)
                ?.map((e) => e as Map<String, dynamic>)
                .toList() ??
            [];

        final rolesLabel =
            roles.map((r) => _roleLabels[r] ?? r).join(', ');

        return Scaffold(
          appBar: AppBar(title: Text('$firstName $lastName')),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Header(
                  firstName: firstName,
                  lastName: lastName,
                  photoUrl: photoUrl,
                  rating: rating,
                  rolesLabel: rolesLabel,
                  bio: bio,
                ),
                if (lounges.isNotEmpty) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: Text(
                      'Работает в',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  ...lounges.map((l) => _LoungeCard(data: l)),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  final String firstName;
  final String lastName;
  final String? photoUrl;
  final double? rating;
  final String rolesLabel;
  final String? bio;

  const _Header({
    required this.firstName,
    required this.lastName,
    required this.photoUrl,
    required this.rating,
    required this.rolesLabel,
    required this.bio,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
            child: photoUrl == null
                ? const Icon(Icons.person, size: 44)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$firstName $lastName',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                if (rolesLabel.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    rolesLabel,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  ),
                ],
                if (rating != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        rating!.toStringAsFixed(1),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ],
                  ),
                ],
                if (bio != null && bio!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(bio!, style: const TextStyle(fontSize: 14)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoungeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LoungeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final name = data['name'] as String? ?? '';
    final shortAddress = data['shortAddress'] as String?;
    final schedule = ScheduleParser.parse(data['schedule'] as String?);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.smoking_rooms, size: 16, color: Colors.grey),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          if (shortAddress != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                shortAddress,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              ),
            ),
          ],
          if (schedule.isNotEmpty) ...[
            const SizedBox(height: 6),
            _ScheduleChips(schedule: schedule),
          ],
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
    return Row(
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
                color: isWorking ? cs.primaryContainer : Colors.grey.shade800,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                day,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isWorking ? FontWeight.bold : FontWeight.normal,
                  color: isWorking ? cs.onPrimaryContainer : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
