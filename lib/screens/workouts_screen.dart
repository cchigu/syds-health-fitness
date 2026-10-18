import 'package:flutter/material.dart';

import '../models/workout.dart';
import '../services/profile_repository.dart';
import '../services/workout_planner.dart';
import '../services/workout_repository.dart';
import '../utils/dates.dart';
import '../widgets/minutes_stepper.dart';
import '../widgets/time_breakdown.dart';
import 'records_screen.dart';
import 'workout_detail_screen.dart';
import 'workout_setup_screen.dart';

/// Workouts tab: this week at a glance, today's workout, intensity, and the
/// week's plan, where any workout can be moved or skipped for this week only.
class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _fullDayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
    'Sunday',
  ];

  static DateTime _monday(DateTime day) =>
      dayOnly(day).subtract(Duration(days: day.weekday - 1));

  static WeekSchedule _schedule(WorkoutPrefs prefs) => WorkoutPlanner
      .weekSchedule(
        prefs,
        ProfileRepository.instance.profile.units,
        _monday(DateTime.now()),
        changeFor: WorkoutScheduleRepository.instance.changeFor,
      );

  void _setup(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WorkoutSetupScreen()),
      );

  /// Opens a workout. [isRestDay] opens the rest-day stretch instead.
  void _open(BuildContext context, PlannedWorkout w, DateTime day,
          {bool isRestDay = false}) =>
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => WorkoutDetailScreen(
          workout: w,
          day: day,
          canSwap: !isRestDay,
          rebuild: () {
            final prefs = WorkoutPrefsRepository.instance.prefs;
            if (prefs == null) return null;
            if (isRestDay) {
              return WorkoutPlanner.restDay(
                  prefs, ProfileRepository.instance.profile.units);
            }
            return _schedule(prefs).on(day)?.workout;
          },
        ),
      ));

  // ------------------------------------------------------- move / skip

  /// Change one workout for this week only: move it, change its length,
  /// or skip it.
  Future<void> _moveOrSkip(BuildContext context, ScheduledWorkout s,
      WeekSchedule week) async {
    final repo = WorkoutScheduleRepository.instance;
    final monday = _monday(s.originalDay);
    final text = Theme.of(context).textTheme;
    final usual = s.usualMinutes ?? s.workout.minutes;
    var length = s.lengthThisWeek ?? usual;

    final choice = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(s.workout.title, style: text.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Just for this week — your regular plan stays the same.',
                  style: text.bodySmall,
                ),
                const SizedBox(height: 16),

                // Length this week
                Text('Length this week', style: text.titleSmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    MinutesStepper(
                      value: length,
                      onChanged: (m) => setLocal(() => length = m),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Usually $usual min',
                          style: text.bodySmall),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    FilledButton.tonal(
                      onPressed: length == (s.lengthThisWeek ?? usual)
                          ? null
                          : () => Navigator.pop(ctx, ('minutes', length)),
                      child: const Text('Save length'),
                    ),
                    const SizedBox(width: 8),
                    if (s.lengthThisWeek != null)
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, ('minutes', null)),
                        child: Text('Back to $usual min'),
                      ),
                  ],
                ),
                const Divider(height: 28),

                // Move
                Text('Move it to', style: text.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var d = 0; d < 7; d++)
                      () {
                        final day = monday.add(Duration(days: d));
                        final taken = week.on(day);
                        final isHere = isSameDay(day, s.day);
                        final free = taken == null || identical(taken, s);
                        return ChoiceChip(
                          label: Text('${_dayNames[d]} ${day.day}'),
                          selected: isHere,
                          onSelected: free && !isHere
                              ? (_) => Navigator.pop(ctx, day)
                              : null,
                        );
                      }(),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Days that already have a workout are greyed out.',
                  style: text.bodySmall,
                ),
                if (s.moved)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, 'back'),
                      icon: const Icon(Icons.undo),
                      label: Text('Put back on '
                          '${_fullDayNames[s.originalDay.weekday - 1]}'),
                    ),
                  ),
                const Divider(height: 28),
                TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'skip'),
                  icon: const Icon(Icons.event_busy),
                  label: const Text('Skip it this week'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (choice == null) return;
    switch (choice) {
      case DateTime day:
        await repo.move(s.originalDay, day);
      case 'back':
        await repo.move(s.originalDay, s.originalDay);
      case 'skip':
        await repo.skip(s.originalDay);
      case ('minutes', final int? m):
        await repo.setMinutes(s.originalDay, m);
    }
  }

  // ------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final prefsRepo = WorkoutPrefsRepository.instance;
    final log = WorkoutLogRepository.instance;
    final profile = ProfileRepository.instance;
    final moves = WorkoutScheduleRepository.instance;

    return ListenableBuilder(
      listenable: Listenable.merge([prefsRepo, log, profile, moves]),
      builder: (context, _) {
        final prefs = prefsRepo.prefs;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Workouts'),
            centerTitle: true,
            actions: [
              IconButton(
                tooltip: 'My records',
                icon: const Icon(Icons.emoji_events_outlined),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RecordsScreen()),
                ),
              ),
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
              : _plan(context, prefs, log),
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

  Widget _plan(
      BuildContext context, WorkoutPrefs prefs, WorkoutLogRepository log) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final week = _schedule(prefs);
    final today = dayOnly(DateTime.now());
    final monday = _monday(today);
    final todays = week.on(today);
    final doneThisWeek = log.doneInWeekOf(today);
    final totalThisWeek = week.scheduled.length;

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
                    for (var d = 0; d < 7; d++)
                      _DayDot(
                        label: _dayNames[d],
                        planned:
                            week.on(monday.add(Duration(days: d))) != null,
                        done: log.doneOn(monday.add(Duration(days: d))),
                        today: d == today.weekday - 1,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '$doneThisWeek of $totalThisWeek workouts done this week',
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
                  todays?.workout.title ?? 'Rest day',
                  style: text.headlineSmall
                      ?.copyWith(color: colors.onPrimaryContainer),
                ),
                const SizedBox(height: 4),
                Text(
                  todays == null
                      ? 'Recovery is part of the plan. A walk or a gentle '
                          'stretch is a nice bonus.'
                      : [
                          todays.workout.subtitle,
                          if (todays.moved)
                            'moved from '
                                '${_fullDayNames[todays.originalDay.weekday - 1]}',
                          if (todays.lengthThisWeek != null)
                            'usually ${todays.usualMinutes} min',
                        ].join(' · '),
                  style: TextStyle(color: colors.onPrimaryContainer),
                ),
                if (todays != null) ...[
                  const SizedBox(height: 12),
                  TimeBreakdown(
                    breakdown: todays.workout.breakdown,
                    onColor: colors.onPrimaryContainer,
                  ),
                ],
                const SizedBox(height: 16),
                if (todays != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () =>
                            _open(context, todays.workout, today),
                        icon: Icon(log.doneOn(today)
                            ? Icons.check_circle
                            : Icons.play_arrow),
                        label: Text(log.doneOn(today)
                            ? 'Done! View workout'
                            : 'Start workout'),
                      ),
                      if (!log.doneOn(today))
                        TextButton(
                          onPressed: () =>
                              _moveOrSkip(context, todays, week),
                          child: const Text('Change this week'),
                        ),
                    ],
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () => _open(
                      context,
                      WorkoutPlanner.restDay(
                          prefs, ProfileRepository.instance.profile.units),
                      today,
                      isRestDay: true,
                    ),
                    icon: const Icon(Icons.self_improvement),
                    label: const Text('10-minute stretch'),
                  ),
              ],
            ),
          ),
        ),

        _IntensityCard(level: prefs.intensity),

        // Week plan
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
          child: Text('This week\'s plan', style: text.titleMedium),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 2, 8, 4),
          child: Text(
            'Tap ⋮ to move, shorten or lengthen, or skip a workout just for '
            'this week.',
            style: text.bodySmall?.copyWith(color: colors.outline),
          ),
        ),
        for (final s in week.scheduled)
          Card(
            child: ListTile(
              onTap: () => _open(context, s.workout, s.day),
              leading: CircleAvatar(
                backgroundColor: isSameDay(s.day, today)
                    ? colors.primary
                    : colors.surfaceContainerHighest,
                foregroundColor: isSameDay(s.day, today)
                    ? colors.onPrimary
                    : colors.onSurface,
                child: Text(_dayNames[s.day.weekday - 1].substring(0, 2)),
              ),
              title: Text(s.workout.title),
              isThreeLine: true,
              subtitle: Text(
                s.moved
                    ? '${_fullDayNames[s.day.weekday - 1]} · moved from '
                        '${_fullDayNames[s.originalDay.weekday - 1]}\n'
                        '${breakdownSummary(s.workout.breakdown)}'
                    : '${_fullDayNames[s.day.weekday - 1]} · '
                        '${s.workout.minutes} min'
                        '${s.lengthThisWeek != null ? ' this week (usually ${s.usualMinutes})' : ''}\n'
                        '${breakdownSummary(s.workout.breakdown)}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (log.doneOn(s.day))
                    Icon(Icons.check_circle, color: colors.primary),
                  IconButton(
                    tooltip: 'Change this week',
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _moveOrSkip(context, s, week),
                  ),
                ],
              ),
            ),
          ),
        for (final s in week.skipped)
          Card(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.4),
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.event_busy)),
              title: Text(
                s.workout.title,
                style: const TextStyle(decoration: TextDecoration.lineThrough),
              ),
              subtitle: Text(
                  '${_fullDayNames[s.originalDay.weekday - 1]} · skipped this week'),
              trailing: TextButton(
                onPressed: () => WorkoutScheduleRepository.instance
                    .unskip(s.originalDay),
                child: const Text('Undo'),
              ),
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
              'Open a workout to change its exercises, sets or weights.',
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

/// Turn the whole plan up or down: sets, weights, holds, rest, treadmill.
class _IntensityCard extends StatelessWidget {
  const _IntensityCard({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final repo = WorkoutPrefsRepository.instance;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Intensity', style: text.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: 'Turn it down',
                  onPressed: level <= Intensity.min
                      ? null
                      : () => repo.setIntensity(level - 1),
                  icon: const Icon(Icons.remove),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        Intensity.label(level),
                        style: text.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var l = Intensity.min; l <= Intensity.max; l++)
                            Container(
                              width: 22,
                              height: 8,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                color: l <= level
                                    ? colors.primary
                                    : colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: 'Turn it up',
                  onPressed: level >= Intensity.max
                      ? null
                      : () => repo.setIntensity(level + 1),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              Intensity.description(level),
              style: text.bodySmall?.copyWith(color: colors.outline),
            ),
          ],
        ),
      ),
    );
  }
}
