import 'package:flutter/material.dart';

import '../models/meal.dart';
import '../models/nutrients.dart';
import '../models/user_profile.dart';
import '../services/exercise_log_repository.dart';
import '../services/food_log_repository.dart';
import '../services/profile_repository.dart';
import '../services/treadmill_repository.dart';
import '../services/weight_repository.dart';
import '../services/workout_planner.dart';
import '../services/workout_repository.dart';
import '../utils/dates.dart';
import '../utils/units.dart';
import '../widgets/exercise_stats.dart';
import 'today_screen.dart';
import 'treadmill_log_sheet.dart';

/// Calendar tab: a month of days, each marked with calories eaten (colored
/// by how close to the goal), weigh-ins, workouts and treadmill sessions.
/// Tap a day for the details.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

/// Colors for the day markers (also used in the legend).
class _Mark {
  static const onTarget = Color(0xFF3FB58A);
  static const over = Color(0xFFF2A541);
  static const under = Color(0xFF64B5F6);
  static const weight = Color(0xFF7B6CF6);
  static const workout = Color(0xFFE85D8E);
  static const treadmill = Color(0xFF26A69A);
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late DateTime _selected = dayOnly(DateTime.now());

  static const _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];

  void _shiftMonth(int delta) => setState(() {
        _month = DateTime(_month.year, _month.month + delta);
      });

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        FoodLogRepository.instance,
        WeightRepository.instance,
        WorkoutLogRepository.instance,
        ExerciseLogRepository.instance,
        TreadmillRepository.instance,
        ProfileRepository.instance,
      ]),
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Calendar'),
            centerTitle: true,
            actions: [
              if (!_isCurrentMonth || !isSameDay(_selected, DateTime.now()))
                TextButton(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    _month = DateTime(now.year, now.month);
                    _selected = dayOnly(now);
                  }),
                  child: const Text('Today'),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            children: [
              _monthHeader(),
              _grid(),
              _legend(),
              const SizedBox(height: 8),
              _DayDetails(day: _selected),
              const SizedBox(height: 8),
              _MonthSummary(month: _month),
            ],
          ),
        );
      },
    );
  }

  Widget _monthHeader() => Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(-1),
          ),
          Expanded(
            child: Text(
              '${_monthNames[_month.month - 1]} ${_month.year}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: _isCurrentMonth ? null : () => _shiftMonth(1),
          ),
        ],
      );

  Widget _grid() {
    final text = Theme.of(context).textTheme;
    final first = DateTime(_month.year, _month.month, 1);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final lead = first.weekday % 7; // Sunday-first weeks
    final cells = lead + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        Row(
          children: [
            for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
              Expanded(
                child: Center(child: Text(d, style: text.labelSmall)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var r = 0; r < rows; r++)
          Row(
            children: [
              for (var c = 0; c < 7; c++)
                Expanded(
                  child: () {
                    final n = r * 7 + c - lead + 1;
                    if (n < 1 || n > daysInMonth) {
                      return const SizedBox(height: 58);
                    }
                    final day = DateTime(_month.year, _month.month, n);
                    return _DayCell(
                      day: day,
                      selected: isSameDay(day, _selected),
                      onTap: () => setState(() => _selected = day),
                    );
                  }(),
                ),
            ],
          ),
      ],
    );
  }

  Widget _legend() {
    final text = Theme.of(context).textTheme;
    Widget item(Color c, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 9, color: c),
            const SizedBox(width: 4),
            Text(label, style: text.labelSmall),
          ],
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: [
          item(_Mark.onTarget, 'Calories on target'),
          item(_Mark.under, 'Under'),
          item(_Mark.over, 'Over'),
          item(_Mark.weight, 'Weigh-in'),
          item(_Mark.workout, 'Workout'),
          item(_Mark.treadmill, 'Treadmill'),
        ],
      ),
    );
  }
}

/// Calorie color for a day: within 10% of the goal is on target.
Color? _calorieColor(double eaten, double? goal) {
  if (eaten <= 0) return null;
  if (goal == null || goal <= 0) return _Mark.onTarget;
  final ratio = eaten / goal;
  if (ratio > 1.10) return _Mark.over;
  if (ratio < 0.90) return _Mark.under;
  return _Mark.onTarget;
}

bool _hadWorkout(DateTime day) =>
    WorkoutLogRepository.instance.doneOn(day) ||
    ExerciseLogRepository.instance.allOnDay(day).isNotEmpty;

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.onTap,
  });

  final DateTime day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final today = isSameDay(day, DateTime.now());
    final future = day.isAfter(dayOnly(DateTime.now()));

    final kcal = FoodLogRepository.instance.totalFor(day).calories;
    final calColor =
        _calorieColor(kcal, ProfileRepository.instance.goals?.calories);
    final dots = <Color>[
      if (WeightRepository.instance.onDay(day) != null) _Mark.weight,
      if (_hadWorkout(day)) _Mark.workout,
      if (TreadmillRepository.instance.onDay(day).isNotEmpty) _Mark.treadmill,
    ];

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: future ? null : onTap,
      child: Container(
        height: 58,
        margin: const EdgeInsets.all(1.5),
        decoration: BoxDecoration(
          color: selected ? colors.primaryContainer : null,
          borderRadius: BorderRadius.circular(10),
          border: today ? Border.all(color: colors.primary, width: 2) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${day.day}',
              style: text.bodyMedium?.copyWith(
                fontWeight: today ? FontWeight.bold : null,
                color: future ? colors.outline : null,
              ),
            ),
            const SizedBox(height: 2),
            // Calories (number tinted by how close to the goal).
            SizedBox(
              height: 14,
              child: calColor == null
                  ? null
                  : FittedBox(
                      child: Text(
                        '${kcal.round()}',
                        style: text.labelSmall?.copyWith(
                          color: calColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 2),
            SizedBox(
              height: 7,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final c in dots)
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration:
                          BoxDecoration(color: c, shape: BoxShape.circle),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything logged on one day.
class _DayDetails extends StatelessWidget {
  const _DayDetails({required this.day});
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final profile = ProfileRepository.instance;
    final units = profile.profile.units;
    final food = FoodLogRepository.instance;
    final eaten = food.totalFor(day);
    final goals = profile.goals;
    final weigh = WeightRepository.instance.onDay(day);
    final workout = WorkoutLogRepository.instance.on(day);
    final sets = ExerciseLogRepository.instance.allOnDay(day);
    final treadmill = TreadmillRepository.instance.onDay(day);
    final weightKg = profile.profile.weightKg ?? 65;
    final prefs = WorkoutPrefsRepository.instance.prefs;

    String exerciseName(String id) =>
        (prefs == null ? null : WorkoutPlanner.exerciseById(prefs, id)?.name) ??
        id;

    Widget section(IconData icon, Color color, String title, Widget body) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleSmall),
                    const SizedBox(height: 2),
                    body,
                  ],
                ),
              ),
            ],
          ),
        );

    final nothing = eaten.calories <= 0 &&
        weigh == null &&
        workout == null &&
        sets.isEmpty &&
        treadmill.isEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(friendlyDay(day), style: text.titleLarge),
            if (nothing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Nothing logged this day.',
                    style: text.bodyMedium?.copyWith(color: colors.outline)),
              ),

            // Food
            if (eaten.calories > 0)
              section(
                Icons.restaurant,
                _calorieColor(eaten.calories, goals?.calories) ??
                    _Mark.onTarget,
                goals == null
                    ? '${eaten.calories.round()} calories'
                    : '${eaten.calories.round()} of '
                        '${goals.calories.round()} calories',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_macroLine(eaten, goals), style: text.bodySmall),
                    const SizedBox(height: 2),
                    Text(
                      [
                        for (final m in Meal.values)
                          if (food.totalFor(day, m).calories > 0)
                            '${m.label} ${food.totalFor(day, m).calories.round()}',
                      ].join(' · '),
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),

            // Weight
            if (weigh != null)
              section(
                Icons.monitor_weight_outlined,
                _Mark.weight,
                'Weighed in at ${formatWeight(weigh.kg, units)}',
                const SizedBox.shrink(),
              ),

            // Workout + logged sets
            if (workout != null || sets.isNotEmpty)
              section(
                Icons.fitness_center,
                _Mark.workout,
                workout == null
                    ? 'Exercises logged'
                    : '${workout.title} · ${workout.minutes} min',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final s in sets)
                      Text(
                        '${exerciseName(s.exerciseId)}: '
                        '${sessionSummary(s, units)}',
                        style: text.bodySmall,
                      ),
                  ],
                ),
              ),

            // Treadmill
            if (treadmill.isNotEmpty)
              section(
                Icons.directions_walk,
                _Mark.treadmill,
                treadmill.length == 1
                    ? 'Treadmill'
                    : 'Treadmill · ${treadmill.length} sessions',
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final t in treadmill)
                      InkWell(
                        onTap: () => showTreadmillLog(context, existing: t),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            '${treadmillSummary(t, units)} · '
                            '${distanceText(t.miles, units)} · '
                            '≈ ${t.caloriesFor(weightKg).round()} cal',
                            style: text.bodySmall,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

            const Divider(height: 20),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => TodayScreen(initialDay: day)),
                  ),
                  icon: const Icon(Icons.restaurant_menu),
                  label: const Text('Food log'),
                ),
                TextButton.icon(
                  onPressed: () => showTreadmillLog(context, day: day),
                  icon: const Icon(Icons.add),
                  label: const Text('Treadmill'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _macroLine(Nutrients n, Nutrients? goals) {
    String part(String label, double v, double? g) =>
        g == null ? '$label ${v.round()} g' : '$label ${v.round()}/${g.round()} g';
    return [
      part('Protein', n.protein, goals?.protein),
      part('Carbs', n.carbs, goals?.carbs),
      part('Fat', n.fat, goals?.fat),
      part('Fiber', n.fiber, goals?.fiber),
    ].join(' · ');
  }
}

/// Totals for the month shown.
class _MonthSummary extends StatelessWidget {
  const _MonthSummary({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final units = ProfileRepository.instance.profile.units;
    final today = dayOnly(DateTime.now());
    final last = DateTime(month.year, month.month + 1, 0);
    final end = last.isAfter(today) ? today : last;

    var foodDays = 0;
    var kcalTotal = 0.0;
    var workouts = 0;
    var treadMin = 0.0;
    for (var d = DateTime(month.year, month.month, 1);
        !d.isAfter(end);
        d = DateTime(d.year, d.month, d.day + 1)) {
      final k = FoodLogRepository.instance.totalFor(d).calories;
      if (k > 0) {
        foodDays++;
        kcalTotal += k;
      }
      if (_hadWorkout(d)) workouts++;
      treadMin += TreadmillRepository.instance
          .onDay(d)
          .fold<double>(0, (t, s) => t + s.minutes);
    }

    final weighIns = WeightRepository.instance.entries
        .where((w) =>
            w.day.year == month.year && w.day.month == month.month)
        .toList();
    final change = weighIns.length >= 2
        ? weighIns.last.kg - weighIns.first.kg
        : null;

    Widget stat(String value, String label) => Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(value, style: text.titleMedium),
              ),
              Text(label,
                  style: text.bodySmall, textAlign: TextAlign.center),
            ],
          ),
        );

    String changeText(double kg) {
      final v = units == Units.imperial ? kgToLb(kg) : kg;
      final unit = units == Units.imperial ? 'lb' : 'kg';
      if (v.abs() < 0.05) return '±0 $unit';
      return '${v > 0 ? '+' : '−'}${trimNumber(v.abs())} $unit';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This month', style: text.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                stat(foodDays == 0 ? '—' : '${(kcalTotal / foodDays).round()}',
                    'avg calories\n($foodDays days logged)'),
                stat('$workouts', 'workout\ndays'),
                stat('${treadMin.round()}', 'treadmill\nminutes'),
                stat(change == null ? '—' : changeText(change),
                    'weight\nchange'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
