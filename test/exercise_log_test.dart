import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/models/exercise_session.dart';
import 'package:syds_health_fitness/models/user_profile.dart';
import 'package:syds_health_fitness/widgets/exercise_stats.dart';

ExerciseSession _s(int day, List<ExerciseSet> sets) => ExerciseSession(
      day: DateTime(2026, 10, day),
      exerciseId: 'goblet_squat',
      sets: sets,
      updatedAt: DateTime(2026),
    );

void main() {
  test('summaries read naturally', () {
    expect(
      sessionSummary(
          _s(1, List.filled(3, const ExerciseSet(weightLb: 15, reps: 10))),
          Units.imperial),
      '3 × 10 @ 15 lb',
    );
    expect(
      sessionSummary(
          _s(1, const [
            ExerciseSet(weightLb: 15, reps: 10),
            ExerciseSet(weightLb: 15, reps: 10),
            ExerciseSet(weightLb: 15, reps: 8),
          ]),
          Units.imperial),
      '10, 10, 8 reps @ 15 lb',
    );
    expect(
      sessionSummary(
          _s(1, const [
            ExerciseSet(weightLb: 15, reps: 10),
            ExerciseSet(weightLb: 20, reps: 8),
          ]),
          Units.imperial),
      '15×10 · 20×8 lb',
    );
    expect(
      sessionSummary(
          _s(1, const [ExerciseSet(seconds: 45), ExerciseSet(seconds: 45)]),
          Units.imperial),
      '2 × 45 s',
    );
    expect(
      sessionSummary(_s(1, const [ExerciseSet(reps: 12)]), Units.imperial),
      '1 × 12',
    );
  });

  test('best session: heavier wins, then more total work', () {
    final light = _s(1, List.filled(3, const ExerciseSet(weightLb: 15, reps: 12)));
    final heavy = _s(2, List.filled(3, const ExerciseSet(weightLb: 20, reps: 8)));
    final heavyMore =
        _s(3, List.filled(3, const ExerciseSet(weightLb: 20, reps: 10)));
    expect(ExerciseSession.compare(heavy, light), greaterThan(0));
    expect(ExerciseSession.compare(heavyMore, heavy), greaterThan(0));
  });

  test('sessions survive saving and loading', () {
    final s = _s(5, const [ExerciseSet(weightLb: 12.5, reps: 9)]);
    final back = ExerciseSession.fromMap(s.toMap())!;
    expect(back.id, '2026-10-05_goblet_squat');
    expect(back.sets.single.weightLb, 12.5);
    expect(back.maxReps, 9);
  });
}
