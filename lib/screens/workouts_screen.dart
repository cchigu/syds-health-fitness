import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/profile_repository.dart';
import '../services/workout_planner.dart';
import '../services/workout_repository.dart';
import '../utils/dates.dart';
import 'workout_detail_screen.dart';
import 'workout_setup_screen.dart';

/// Workouts tab: this week at a glance, today's workout, and the plan.
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _fullDayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  void _setup(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WorkoutSetupScreen()),
      );

  void _open(BuildContext context, PlannedWorkout w, DateTime day,
          {bool canSwap = true}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          workout: w,
          day: day,
          canSwap: canSwap,
          rebuild: () {
            final prefs = WorkoutPrefsRepository.instance.prefs;
            if (prefs == null) return null;
            return WorkoutPlanner.weekPlan(
                prefs, ProfileRepository.instance.profile.units)[day.weekday];
          },
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final prefsRepo = WorkoutPrefsRepository.instance;
    final log = WorkoutLogRepository.instance;
    final profile = ProfileRepository.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([prefsRepo, log, profile]),
      builder: (context, _) {
        final prefs = prefsRepo.prefs;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Workouts'),
            centerTitle: true,
            actions: [
              if (prefs != null)
                IconButton(
                  tooltip: 'Change my plan',
                  icon: const Icon(Icons.tune),
                  onPressed: () => _setup(context),
                ),
            ],
          ),
          body: prefs == null
              ? _intro(context)
              : _plan(context, prefs, log, profile),
        );
      },
    );
  }

  Widget _intro(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 72, color: colors.primary),
            const SizedBox(height: 16),
            Text('Your at-home plan', style: text.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Answer 5 quick questions and get a weekly plan using just '
              'your dumbbells, the treadmill and some stretches.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _setup(context),
              icon: const Icon(Icons.play_arrow),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Build my plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _plan(BuildContext context, WorkoutPrefs prefs,
      WorkoutLogRepository log, ProfileRepository profile) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final plan = WorkoutPlanner.weekPlan(prefs, profile.profile.units);
    final today = dayOnly(DateTime.now());
    final monday = today.subtract(Duration(days: today.weekday - 1));
    final todays = plan[today.weekday];
    final doneThisWeek = log.doneInWeekOf(today);

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        // This week strip
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 16, 8, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    for (var d = 1; d <= 7; d++)
                      _DayDot(
                        label: _dayNames[d - 1],
                        planned: plan.containsKey(d),
                        done: log.doneOn(monday.add(Duration(days: d - 1))),
                        today: d == today.weekday,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$doneThisWeek of ${plan.length} workouts done this week',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
        ),

        // Today
        Card(
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Today',
                    style: text.labelLarge
                        ?.copyWith(color: colors.onPrimaryContainer)),
                const SizedBox(height: 4),
                Text(
                  todays?.title ?? 'Rest day',
                  style: text.headlineSmall
                      ?.copyWith(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  todays?.subtitle ??
                      'Recovery is part of the plan. A walk or a gentle '
                          'stretch is a nice bonus.',
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 16),
                if (todays != null)
                  FilledButton.icon(
                    onPressed: () => _open(context, todays, today),
                    icon: Icon(log.doneOn(today)
                        ? Icons.check_circle
                        : Icons.play_arrow),
                    label: Text(log.doneOn(today)
                        ? 'Done! View workout'
                        : 'Start workout'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _open(
                      context,
                      WorkoutPlanner.restDayStretch(prefs),
                      today,
                      canSwap: false,
                    ),
                    icon: const Icon(Icons.self_improvement),
                    label: const Text('10-minute stretch'),
                  ),
              ],
            ),
          ),
        ),

        // Week plan
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 4),
          child: Text('This week\'s plan', style: text.titleMedium),
        ),
        for (final entry in (plan.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key))))
          Card(
            child: ListTile(
              onTap: () => _open(
                  context, entry.value, monday.add(Duration(days: entry.key - 1))),
              leading: CircleAvatar(
                backgroundColor: entry.key == today.weekday
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                foregroundColor: entry.key == today.weekday
                    ? colors.onPrimary
                    : colors.onSurface,
                child: Text(_dayNames[entry.key - 1].substring(0, 2)),
              ),
              title: Text(entry.value.title),
              subtitle: Text(
                '${_fullDayNames[entry.key - 1]} · ${entry.value.minutes} min',
              ),
              trailing: log.doneOn(monday.add(Duration(days: entry.key - 1)))
                  ? Icon(Icons.check_circle, color: colors.primary)
                  : const Icon(Icons.chevron_right),
            ),
          ),

        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Text(
            [
              'Plan: ${prefs.focus.label.toLowerCase()}, '
                  '${prefs.experience.label.toLowerCase()}.',
              if (prefs.avoid.isNotEmpty)
                'Going easy on: '
                    '${prefs.avoid.map((a) => a.label.toLowerCase()).join(', ')}.',
              'Stop any exercise that causes sharp pain.',
            ].join(' '),
            style: text.bodySmall?.copyWith(color: colors.outline),
          ),
        ),
      ],
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.label,
    required this.planned,
    required this.done,
    required this.today,
  });

  final String label;
  final bool planned;
  final bool done;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final Color fill = done
        ? colors.primary
        : (planned ? colors.primaryContainer : Colors.transparent);
    return Column(
      children: [
        Text(label,
            style: text.labelSmall?.copyWith(
                fontWeight: today ? FontWeight.bold : FontWeight.normal)),
        const SizedBox(height: 6),
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            border: Border.all(
              color: today ? colors.primary : colors.outlineVariant,
              width: today ? 2 : 1,
            ),
          ),
          child: done
              ? Icon(Icons.check, size: 18, color: colors.onPrimary)
              : (planned
                  ? Icon(Icons.fitness_center,
                      size: 14, color: colors.onPrimaryContainer)
                  : null),
        ),
      ],
    );
  }
}
