import '../models/exercise_session.dart';
import '../utils/dates.dart';
import 'synced_store.dart';

/// The sets Syd logged for each exercise (users/{uid}/exerciseLog),
/// one session per exercise per day.
class ExerciseLogRepository extends SyncedStore<ExerciseSession> {
  ExerciseLogRepository._()
      : super(
          prefsKey: 'exercise_log_v1',
          collection: 'exerciseLog',
          fromMap: ExerciseSession.fromMap,
        );
  static final ExerciseLogRepository instance = ExerciseLogRepository._();

  /// Newest first.
  List<ExerciseSession> history(String exerciseId) => items
      .where((s) => s.exerciseId == exerciseId && s.sets.isNotEmpty)
      .toList()
    ..sort((a, b) => b.day.compareTo(a.day));

  ExerciseSession? onDay(String exerciseId, DateTime day) =>
      byId(ExerciseSession.idFor(day, exerciseId));

  ExerciseSession? last(String exerciseId) {
    final h = history(exerciseId);
    return h.isEmpty ? null : h.first;
  }

  /// The most recent session before [day] (not counting that day).
  ExerciseSession? lastBefore(String exerciseId, DateTime day) {
    final cutoff = dayOnly(day);
    for (final s in history(exerciseId)) {
      if (s.day.isBefore(cutoff)) return s;
    }
    return null;
  }

  ExerciseSession? best(String exerciseId) {
    ExerciseSession? top;
    for (final s in history(exerciseId)) {
      if (top == null || ExerciseSession.compare(s, top) > 0) top = s;
    }
    return top;
  }

  double? heaviest(String exerciseId) {
    double? top;
    for (final s in history(exerciseId)) {
      final w = s.topWeight;
      if (w != null && (top == null || w > top)) top = w;
    }
    return top;
  }

  int? mostReps(String exerciseId) {
    int? top;
    for (final s in history(exerciseId)) {
      final r = s.maxReps;
      if (r != null && (top == null || r > top)) top = r;
    }
    return top;
  }

  int? longestHold(String exerciseId) {
    int? top;
    for (final s in history(exerciseId)) {
      final x = s.maxSeconds;
      if (x != null && (top == null || x > top)) top = x;
    }
    return top;
  }

  /// Every exercise she has logged at least once.
  Set<String> get loggedExercises => {
        for (final s in items)
          if (s.sets.isNotEmpty) s.exerciseId,
      };

  Future<void> save(DateTime day, String exerciseId, List<ExerciseSet> sets) =>
      put(ExerciseSession(
        day: dayOnly(day),
        exerciseId: exerciseId,
        sets: sets,
        updatedAt: DateTime.now(),
        deleted: sets.isEmpty,
      ));
}
