import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/models/user_profile.dart';
import 'package:syds_health_fitness/models/workout.dart';
import 'package:syds_health_fitness/services/workout_planner.dart';

WorkoutPrefs _prefs({
  Set<int> days = const {1, 3, 5},
  int minutes = 30,
  WorkoutFocus focus = WorkoutFocus.both,
  Experience exp = Experience.intermediate,
  Set<BodyArea> avoid = const {},
}) =>
    WorkoutPrefs(
      weekdays: days,
      minutes: minutes,
      focus: focus,
      experience: exp,
      avoid: avoid,
      updatedAt: DateTime(2026),
    );

Iterable<PlannedExercise> _all(PlannedWorkout w) =>
    w.sections.expand((s) => s.exercises);

void main() {
  test('every session builds for every combination (no missing exercises)', () {
    for (final type in SessionType.values) {
      for (final focus in WorkoutFocus.values) {
        for (final exp in Experience.values) {
          for (final m in [20, 30, 45]) {
            for (final avoid in [
              <BodyArea>{},
              {BodyArea.knees},
              BodyArea.values.toSet(),
            ]) {
              final w = WorkoutPlanner.build(
                type,
                _prefs(focus: focus, exp: exp, minutes: m, avoid: avoid),
                Units.imperial,
              );
              expect(w.sections, isNotEmpty);
            }
          }
        }
      }
    }
  });

  test('protected areas are left out of the whole week', () {
    const avoid = {BodyArea.knees, BodyArea.lowerBack};
    final plan = WorkoutPlanner.weekPlan(
      _prefs(days: {1, 2, 3, 4, 5, 6, 7}, avoid: avoid, minutes: 45),
      Units.imperial,
    );
    for (final w in plan.values) {
      for (final pe in _all(w)) {
        expect(pe.exercise.stresses.intersection(avoid), isEmpty,
            reason: '${pe.exercise.name} loads a protected area');
      }
    }
  });

  test('dumbbell suggestions never go over 25 lb', () {
    for (final exp in Experience.values) {
      for (final focus in WorkoutFocus.values) {
        final plan = WorkoutPlanner.weekPlan(
          _prefs(days: {1, 2, 3, 4, 5}, exp: exp, focus: focus, minutes: 45),
          Units.imperial,
        );
        for (final w in plan.values) {
          for (final pe in _all(w)) {
            final weight = pe.weight;
            if (weight == null) continue;
            final hi = int.parse(weight.split('–').last.split(' ').first);
            expect(hi, lessThanOrEqualTo(25), reason: pe.exercise.name);
          }
        }
      }
    }
  });

  test('plan follows the chosen days', () {
    final plan = WorkoutPlanner.weekPlan(_prefs(days: {2, 4}), Units.imperial);
    expect(plan.keys.toSet(), {2, 4});
    expect(plan[2]!.title, 'Full body A');
  });

  test('fat loss gets more treadmill time than strength', () {
    int treadmill(WorkoutFocus f) {
      final w = WorkoutPlanner.build(
          SessionType.fullA, _prefs(focus: f, minutes: 45), Units.imperial);
      final s = w.sections.where((s) => s.title == 'Treadmill');
      if (s.isEmpty) return 0;
      return int.parse(s.first.exercises.first.prescription.split(' ').first);
    }

    expect(treadmill(WorkoutFocus.fatLoss),
        greaterThan(treadmill(WorkoutFocus.strength)));
  });

  test('prefs survive saving and loading', () {
    final p = _prefs(avoid: {BodyArea.wrists});
    final back = WorkoutPrefs.fromMap(p.toMap())!;
    expect(back.weekdays, {1, 3, 5});
    expect(back.avoid, {BodyArea.wrists});
  });
}
