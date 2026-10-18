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
          for (final m in [15, 20, 30, 45, 60]) {
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

  group('intensity', () {
    PlannedExercise squat(int level) {
      final w = WorkoutPlanner.build(
        SessionType.lowerA,
        _prefs(minutes: 45).copyWith(intensity: level),
        Units.imperial,
      );
      return _all(w).firstWhere((e) => e.exercise.id == 'goblet_squat');
    }

    int setsOf(PlannedExercise e) =>
        int.parse(e.prescription.split(' ').first);
    int topWeight(PlannedExercise e) =>
        int.parse(e.weight!.split('–').last.split(' ').first);

    test('turning it up adds sets and weight; down does the opposite', () {
      expect(setsOf(squat(2)), greaterThan(setsOf(squat(0))));
      expect(setsOf(squat(-2)), lessThan(setsOf(squat(0))));
      expect(topWeight(squat(1)), greaterThanOrEqualTo(topWeight(squat(0))));
      expect(topWeight(squat(-2)), lessThan(topWeight(squat(0))));
    });

    test('never over 25 lb even in beast mode', () {
      for (final exp in Experience.values) {
        final plan = WorkoutPlanner.weekPlan(
          _prefs(days: {1, 2, 3, 4, 5}, exp: exp, minutes: 45)
              .copyWith(intensity: 2),
          Units.imperial,
        );
        for (final w in plan.values) {
          for (final pe in _all(w)) {
            if (pe.weight == null) continue;
            expect(topWeight(pe), lessThanOrEqualTo(25));
          }
        }
      }
    });

    test('intensity is saved with the plan', () {
      final p = _prefs().copyWith(intensity: -1);
      expect(WorkoutPrefs.fromMap(p.toMap())!.intensity, -1);
    });
  });

  group('her own edits', () {
    final base = _prefs(days: {1, 3, 5}, minutes: 45);

    test('her numbers replace the plan\'s for that exercise', () {
      final p = base.copyWith(overrides: {
        'fullA:goblet_squat':
            const ExerciseOverride(prescription: '4 × 6', weightLb: 25),
      });
      final w = WorkoutPlanner.build(SessionType.fullA, p, Units.imperial);
      final squat = _all(w).firstWhere((e) => e.exercise.id == 'goblet_squat');
      expect(squat.prescription, '4 × 6');
      expect(squat.weight, '25 lb');
      expect(squat.custom, isTrue);
    });

    test('removed exercises disappear; added ones appear', () {
      final p = base.copyWith(
        removed: {'fullA:goblet_squat'},
        extras: {
          'fullA': [
            const ExtraExercise(exerciseId: 'mine_1', prescription: '3 × 15'),
          ],
        },
        customExercises: [
          const CustomExerciseDef(id: 'mine_1', name: 'Donkey kicks'),
        ],
      );
      final w = WorkoutPlanner.build(SessionType.fullA, p, Units.imperial);
      final names = _all(w).map((e) => e.exercise.name).toList();
      expect(names, isNot(contains('Goblet squat')));
      expect(names, contains('Donkey kicks'));
    });

    test('her edits stay in the saved plan', () {
      final p = base.copyWith(
        overrides: {'x:y': const ExerciseOverride(prescription: '2 × 5')},
        removed: {'a:b'},
        customExercises: [const CustomExerciseDef(id: 'mine_2', name: 'Z')],
      );
      final back = WorkoutPrefs.fromMap(p.toMap())!;
      expect(back.overrides['x:y']!.prescription, '2 × 5');
      expect(back.removed, {'a:b'});
      expect(back.customExercises.single.name, 'Z');
    });
  });

  group('one-week moves', () {
    final monday = DateTime(2026, 10, 19);
    final p = _prefs(days: {1, 3, 5});

    test('moving Wednesday to Thursday only changes this week', () {
      final wed = DateTime(2026, 10, 21);
      final thu = DateTime(2026, 10, 22);
      final week = WorkoutPlanner.weekSchedule(p, Units.imperial, monday,
          changeFor: (d) => d == wed
              ? ScheduleChange(
                  originalDay: wed, newDay: thu, updatedAt: DateTime(2026))
              : null);
      expect(week.on(wed), isNull);
      expect(week.on(thu)?.moved, isTrue);
      expect(week.scheduled, hasLength(3));

      // Next week has no changes: back to normal.
      final next = WorkoutPlanner.weekSchedule(
          p, Units.imperial, monday.add(const Duration(days: 7)),
          changeFor: (_) => null);
      expect(next.on(wed.add(const Duration(days: 7))), isNotNull);
    });

    test('skipping takes it off this week', () {
      final fri = DateTime(2026, 10, 23);
      final week = WorkoutPlanner.weekSchedule(p, Units.imperial, monday,
          changeFor: (d) => d == fri
              ? ScheduleChange(originalDay: fri, updatedAt: DateTime(2026))
              : null);
      expect(week.scheduled, hasLength(2));
      expect(week.skipped.single.originalDay, fri);
    });
  });

  group('time', () {
    test('each workout fits the length she picked for that day', () {
      for (final focus in WorkoutFocus.values) {
        for (final m in [15, 20, 30, 45, 60]) {
          for (final type in [SessionType.fullA, SessionType.lowerA,
              SessionType.cardioCore]) {
            final w = WorkoutPlanner.build(
                type, _prefs(focus: focus), Units.imperial, minutes: m);
            expect(w.breakdown.total, inInclusiveRange(m - 4, m + 2),
                reason: '$type $focus $m');
          }
        }
      }
    });

    test('different days can have different lengths', () {
      final p = _prefs(days: {1, 3}).copyWith(minutesByDay: {1: 20, 3: 45});
      final plan = WorkoutPlanner.weekPlan(p, Units.imperial);
      expect(plan[1]!.minutes, lessThan(plan[3]!.minutes));
      expect(WorkoutPrefs.fromMap(p.toMap())!.minutesFor(3), 45);
    });

    test('breakdown adds up and splits by type', () {
      final w = WorkoutPlanner.build(SessionType.fullA,
          _prefs(focus: WorkoutFocus.both), Units.imperial, minutes: 30);
      final b = w.breakdown;
      expect(b.strength, greaterThan(0));
      expect(b.treadmill, greaterThan(0));
      expect(b.stretching, greaterThan(0));
      expect(b.total, w.minutes);
    });
  });
}
