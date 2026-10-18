import 'package:flutter/material.dart';

import '../models/nutrients.dart';
import '../services/profile_repository.dart';
import '../widgets/daily_progress_card.dart';
import 'goals_screen.dart';

/// Today tab: calories and macros eaten vs. goals.
/// Food logging (breakfast/lunch/dinner/snacks) arrives in Milestone 4.
class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];
  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  @override
  Widget build(BuildContext context) {
    final repo = ProfileRepository.instance;
    final now = DateTime.now();
    final dateLabel =
        '${_weekdays[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final goals = repo.goals;
        final text = Theme.of(context).textTheme;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Today'),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'Daily goals',
                icon: const Icon(Icons.flag_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                ),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(dateLabel,
                  textAlign: TextAlign.center, style: text.titleMedium),
              const SizedBox(height: 12),
              if (goals == null)
                const Card(
                  child: ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('Finish your profile'),
                    subtitle: Text(
                      'Add your birthday, height and weight in the Profile '
                      'tab to get your calorie and macro goals.',
                    ),
                  ),
                )
              else
                DailyProgressCard(eaten: Nutrients.zero, goals: goals),
              const SizedBox(height: 12),
              Text(
                'Logging breakfast, lunch, dinner and snacks is coming next!',
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}
