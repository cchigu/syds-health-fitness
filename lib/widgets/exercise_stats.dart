import 'package:flutter/material.dart';

import '../models/exercise_session.dart';
import '../models/user_profile.dart';
import '../services/exercise_log_repository.dart';
import '../utils/dates.dart';
import '../utils/units.dart';

String weightText(double lb, Units units) => units == Units.imperial
    ? '${trimNumber(lb)} lb'
    : '${trimNumber(lbToKg(lb))} kg';

/// "3 × 10 @ 15 lb", "10, 10, 8 reps @ 15 lb", "15×10 · 20×8 lb" or
/// "3 × 45 s".
String sessionSummary(ExerciseSession s, Units units) {
  final sets = s.sets;
  if (sets.isEmpty) return '—';
  final unit = units == Units.imperial ? 'lb' : 'kg';
  String num(double lb) =>
      trimNumber(units == Units.imperial ? lb : lbToKg(lb));

  final timed = sets.every((x) => x.reps == null && x.seconds != null);
  if (timed) {
    final secs = sets.map((x) => x.seconds!).toList();
    return secs.toSet().length == 1
        ? '${secs.length} × ${secs.first} s'
        : '${secs.join(' · ')} s';
  }

  final weights = sets.map((x) => x.weightLb).toList();
  final reps = sets.map((x) => x.reps ?? 0).toList();
  final sameWeight = weights.toSet().length == 1;
  final sameReps = reps.toSet().length == 1;
  final w = weights.first;
  final at = w == null ? '' : ' @ ${num(w)} $unit';

  if (sameWeight && sameReps) return '${sets.length} × ${reps.first}$at';
  if (sameWeight) return '${reps.join(', ')} reps$at';
  return '${[
    for (var i = 0; i < sets.length; i++)
      '${weights[i] == null ? 'BW' : num(weights[i]!)}×${reps[i]}',
  ].join(' · ')} $unit';
}

/// Last session, best session and records for one exercise.
class ExerciseStatsCard extends StatelessWidget {
  const ExerciseStatsCard({
    super.key,
    required this.exerciseId,
    required this.units,
  });

  final String exerciseId;
  final Units units;

  @override
  Widget build(BuildContext context) {
    final repo = ExerciseLogRepository.instance;
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: repo,
      builder: (context, _) {
        final history = repo.history(exerciseId);
        if (history.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No sets logged yet. Log your sets to track your last and '
              'best sessions.',
              style: text.bodyMedium,
            ),
          );
        }
        final last = history.first;
        final best = repo.best(exerciseId)!;
        final heaviest = repo.heaviest(exerciseId);
        final mostReps = repo.mostReps(exerciseId);
        final longest = repo.longestHold(exerciseId);

        Widget row(IconData icon, Color color, String label,
                ExerciseSession s) =>
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: color),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$label · ${friendlyDay(s.day)}',
                            style: text.labelMedium),
                        Text(sessionSummary(s, units),
                            style: text.titleMedium),
                      ],
                    ),
                  ),
                ],
              ),
            );

        return Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              row(Icons.history, colors.primary, 'Last session', last),
              row(Icons.emoji_events, const Color(0xFFF2A541), 'Best session',
                  best),
              const SizedBox(height: 4),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (heaviest != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.fitness_center, size: 16),
                      label: Text('Heaviest ${weightText(heaviest, units)}'),
                    ),
                  if (mostReps != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.repeat, size: 16),
                      label: Text('Most reps $mostReps'),
                    ),
                  if (longest != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.timer_outlined, size: 16),
                      label: Text('Longest ${longest}s'),
                    ),
                ],
              ),
              if (history.length > 1)
                Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text('History (${history.length})',
                        style: text.labelLarge),
                    children: [
                      for (final s in history.take(20))
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(sessionSummary(s, units)),
                          trailing: Text(friendlyDay(s.day),
                              style: text.bodySmall),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
