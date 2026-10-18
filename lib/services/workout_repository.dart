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

  /// Her own numbers for an exercise in a workout (null clears them).
  Future<void> setOverride(
      String session, String exerciseId, ExerciseOverride? o) async {
    final p = prefs;
    if (p == null) return;
    final map = {...p.overrides};
    final key = '$session:$exerciseId';
    if (o == null) {
      map.remove(key);
    } else {
      map[key] = o;
    }
    await save(p.copyWith(overrides: map));
  }

  /// Take an exercise out of a workout (or put it back).
  Future<void> setRemoved(String session, String exerciseId, bool removed) async {
    final p = prefs;
    if (p == null) return;
    final set = {...p.removed};
    final key = '$session:$exerciseId';
    removed ? set.add(key) : set.remove(key);
    await save(p.copyWith(removed: set));
  }

  Future<void> addExtra(String session, ExtraExercise x) async {
    final p = prefs;
    if (p == null) return;
    await save(p.copyWith(extras: {
      ...p.extras,
      session: [...?p.extras[session], x],
    }));
  }

  Future<void> updateExtra(String session, int index, ExtraExercise? x) async {
    final p = prefs;
    if (p == null) return;
    final list = [...?p.extras[session]];
    if (index < 0 || index >= list.length) return;
    if (x == null) {
      list.removeAt(index);
    } else {
      list[index] = x;
    }
    await save(p.copyWith(extras: {...p.extras, session: list}));
  }

  /// Save an exercise she made up and return it.
  Future<CustomExerciseDef> createExercise(String name, String notes) async {
    final def = CustomExerciseDef(
      id: 'mine_${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      notes: notes,
    );
    final p = prefs;
    if (p != null) {
      await save(p.copyWith(customExercises: [...p.customExercises, def]));
    }
    return def;
  }

  /// Undo all her edits to one workout.
  Future<void> resetWorkout(String session) async {
    final p = prefs;
    if (p == null) return;
    bool mine(String k) => k.startsWith('$session:');
    await save(p.copyWith(
      overrides: {...p.overrides}..removeWhere((k, _) => mine(k)),
      removed: {...p.removed}..removeWhere(mine),
      extras: {...p.extras}..remove(session),
      swaps: {...p.swaps}..removeWhere((k, _) => mine(k)),
    ));
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

  WorkoutDone? on(DateTime day) => byId(dayKey(day));

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

/// One-week moves and skips (users/{uid}/workoutMoves).
class WorkoutScheduleRepository extends SyncedStore<ScheduleChange> {
  WorkoutScheduleRepository._()
      : super(
          prefsKey: 'workout_moves_v1',
          collection: 'workoutMoves',
          fromMap: ScheduleChange.fromMap,
        );
  static final WorkoutScheduleRepository instance =
      WorkoutScheduleRepository._();

  ScheduleChange? changeFor(DateTime originalDay) =>
      byId(dayKey(originalDay));

  Future<void> _update(
    DateTime originalDay, {
    DateTime? Function(DateTime?)? newDay,
    bool? skipped,
    int? Function(int?)? minutes,
  }) {
    final old = changeFor(originalDay);
    final next = ScheduleChange(
      originalDay: dayOnly(originalDay),
      newDay: newDay != null ? newDay(old?.newDay) : old?.newDay,
      skipped: skipped ?? old?.skipped ?? false,
      minutes: minutes != null ? minutes(old?.minutes) : old?.minutes,
      updatedAt: DateTime.now(),
    );
    return put(next.isEmpty
        ? ScheduleChange(
            originalDay: next.originalDay,
            updatedAt: next.updatedAt,
            deleted: true,
          )
        : next);
  }

  /// Move it to another day this week (moving back = its usual day).
  Future<void> move(DateTime originalDay, DateTime newDay) => _update(
        originalDay,
        newDay: (_) => isSameDay(originalDay, newDay) ? null : dayOnly(newDay),
        skipped: false,
      );

  Future<void> skip(DateTime originalDay) =>
      _update(originalDay, skipped: true);

  Future<void> unskip(DateTime originalDay) =>
      _update(originalDay, skipped: false);

  /// A different length just this week (null = her usual length).
  Future<void> setMinutes(DateTime originalDay, int? minutes) =>
      _update(originalDay, minutes: (_) => minutes);

  /// Undo every change to it this week.
  Future<void> restore(DateTime originalDay) => put(ScheduleChange(
        originalDay: dayOnly(originalDay),
        updatedAt: DateTime.now(),
        deleted: true,
      ));
}
