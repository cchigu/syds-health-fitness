import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../models/meal.dart';
import '../services/food_log_repository.dart';
import '../services/profile_repository.dart';
import '../utils/dates.dart';
import '../widgets/daily_progress_card.dart';
import '../widgets/meal_section.dart';
import 'food_detail_screen.dart';
import 'food_search_screen.dart';
import 'goals_screen.dart';

/// Today tab: calories and macros vs. goals, and the four meals.
/// The arrows switch days so past days can be checked or filled in.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  DateTime _day = dayOnly(DateTime.now());

  bool get _isToday => isSameDay(_day, DateTime.now());

  void _shiftDay(int days) =>
      setState(() => _day = dayOnly(_day.add(Duration(days: days))));

  Future<void> _pickDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: dayOnly(DateTime.now()),
    );
    if (picked != null) setState(() => _day = dayOnly(picked));
  }

  Future<void> _addFood(Meal meal) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen(meal: meal, day: _day),
      ),
    );
  }

  Future<void> _openEntry(LogEntry entry) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => FoodDetailScreen.edit(entry: entry)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ProfileRepository.instance;
    final log = FoodLogRepository.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([profile, log]),
      builder: (context, _) {
        final goals = profile.goals;
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              // Day switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shiftDay(-1),
                  ),
                  TextButton(
                    onPressed: _pickDay,
                    child: Text(friendlyDay(_day), style: text.titleMedium),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _isToday ? null : () => _shiftDay(1),
                  ),
                ],
              ),

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
                DailyProgressCard(eaten: log.totalFor(_day), goals: goals),

              const SizedBox(height: 4),
              for (final meal in Meal.values)
                MealSection(
                  meal: meal,
                  entries: log.entriesFor(_day, meal),
                  onAdd: () => _addFood(meal),
                  onOpen: _openEntry,
                ),
            ],
          ),
        );
      },
    );
  }
}
