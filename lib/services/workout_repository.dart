import '../models/workout.dart';
import '../utils/dates.dart';
import 'synced_store.dart';

/// Syd's workout setup answers (users/{uid}/workoutPrefs/current).
class WorkoutPrefsRepository extends SyncedStore<WorkoutPrefs> {
  WorkoutPrefsRepository._()
      : super(
          prefsKey: 'workout_prefs_v1',
          collection: 'workoutPrefs',
          fromMap: WorkoutPrefs.fromMap,
        );
  static final WorkoutPrefsRepository instance = WorkoutPrefsRepository._();

  WorkoutPrefs? get prefs => byId('current');

  Future<void> save(WorkoutPrefs p) =>
      put(p.copyWith(updatedAt: DateTime.now()));

  /// Turn the intensity dial (-2 to +2).
  Future<void> setIntensity(int level) async {
    final p = prefs;
    if (p == null) return;
    await save(p.copyWith(
        intensity: level.clamp(Intensity.min, Intensity.max)));
  }

  /// Remember an exercise swap so the plan keeps it.
  Future<void> swap(String slotKey, String exerciseId) async {
    final p = prefs;
    if (p == null) return;
    await save(p.copyWith(swaps: {...p.swaps, slotKey: exerciseId}));
  }
}

/// Finished workouts (users/{uid}/workouts), one per day.
class WorkoutLogRepository extends SyncedStore<WorkoutDone> {
  WorkoutLogRepository._()
      : super(
          prefsKey: 'workouts_done_v1',
          collection: 'workouts',
          fromMap: WorkoutDone.fromMap,
        );
  static final WorkoutLogRepository instance = WorkoutLogRepository._();

  bool doneOn(DateTime day) => byId(dayKey(day)) != null;

  Future<void> markDone(DateTime day, String title, int minutes) =>
      put(WorkoutDone(
        day: dayOnly(day),
        title: title,
        minutes: minutes,
        updatedAt: DateTime.now(),
      ));

  Future<void> undo(DateTime day) async {
    final w = byId(dayKey(day));
    if (w == null) return;
    await put(WorkoutDone(
      day: w.day,
      title: w.title,
      minutes: w.minutes,
      updatedAt: DateTime.now(),
      deleted: true,
    ));
  }

  /// Workouts finished Monday–Sunday of the week containing [day].
  int doneInWeekOf(DateTime day) {
    final monday = dayOnly(day).subtract(Duration(days: day.weekday - 1));
    var n = 0;
    for (var i = 0; i < 7; i++) {
      if (doneOn(monday.add(Duration(days: i)))) n++;
    }
    return n;
  }
}
