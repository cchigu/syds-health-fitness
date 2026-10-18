import 'dart:math';

import '../data/exercise_library.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
import '../utils/units.dart';

enum SessionType {
  fullA,
  fullB,
  fullC,
  upperA,
  lowerA,
  upperB,
  lowerB,
  cardioCore,
  cardioCore2,
  mobility,
}

/// Builds Syd's weekly plan from her answers.
///
/// - Split by days a week: 1–3 days = full body; 4 = upper/lower twice;
///   5–6 adds treadmill + core days; 7 adds a walk & stretch day.
/// - Each spot in a workout has a list of exercises in order of preference;
///   the first one that doesn't load an area she's protecting is used.
/// - Session length decides how many exercises and how much treadmill time;
///   her focus decides sets, reps, rest and the cardio mix.
class WorkoutPlanner {
  WorkoutPlanner._();

  static const _templates = <SessionType, List<List<String>>>{
    SessionType.fullA: [
      ['goblet_squat', 'sumo_squat', 'glute_bridge'],
      ['one_arm_row', 'reverse_fly'],
      ['floor_press', 'incline_pushup', 'tricep_kickback'],
      ['db_rdl', 'single_leg_bridge', 'glute_bridge'],
      ['dead_bug', 'heel_taps'],
      ['lateral_raise', 'bicep_curl'],
      ['calf_raise', 'side_leg_raise'],
    ],
    SessionType.fullB: [
      ['reverse_lunge', 'side_leg_raise', 'single_leg_bridge'],
      ['floor_press', 'incline_pushup', 'tricep_kickback'],
      ['bent_over_row', 'one_arm_row', 'reverse_fly'],
      ['glute_bridge', 'single_leg_bridge'],
      ['forearm_plank', 'dead_bug', 'heel_taps'],
      ['hammer_curl', 'bicep_curl'],
      ['shoulder_press', 'lateral_raise', 'tricep_kickback'],
    ],
    SessionType.fullC: [
      ['squat_press', 'sumo_squat', 'glute_bridge'],
      ['incline_pushup', 'floor_press', 'tricep_kickback'],
      ['one_arm_row', 'reverse_fly'],
      ['db_rdl', 'single_leg_bridge'],
      ['russian_twist', 'dead_bug', 'heel_taps'],
      ['reverse_fly', 'hammer_curl'],
      ['side_leg_raise', 'calf_raise'],
    ],
    SessionType.upperA: [
      ['floor_press', 'incline_pushup', 'tricep_kickback'],
      ['one_arm_row', 'reverse_fly'],
      ['shoulder_press', 'lateral_raise', 'reverse_fly'],
      ['bicep_curl', 'hammer_curl'],
      ['tricep_kickback'],
      ['dead_bug', 'heel_taps'],
      ['lateral_raise', 'hammer_curl'],
    ],
    SessionType.lowerA: [
      ['goblet_squat', 'sumo_squat', 'glute_bridge'],
      ['db_rdl', 'single_leg_bridge'],
      ['reverse_lunge', 'side_leg_raise'],
      ['glute_bridge', 'single_leg_bridge'],
      ['calf_raise', 'side_leg_raise'],
      ['forearm_plank', 'dead_bug'],
      ['heel_taps', 'dead_bug'],
    ],
    SessionType.upperB: [
      ['incline_pushup', 'floor_press', 'tricep_kickback'],
      ['bent_over_row', 'one_arm_row', 'reverse_fly'],
      ['lateral_raise', 'reverse_fly'],
      ['hammer_curl', 'bicep_curl'],
      ['tricep_kickback'],
      ['side_plank', 'dead_bug'],
      ['reverse_fly', 'bicep_curl'],
    ],
    SessionType.lowerB: [
      ['sumo_squat', 'goblet_squat', 'glute_bridge'],
      ['single_leg_bridge', 'glute_bridge'],
      ['db_rdl', 'single_leg_bridge'],
      ['reverse_lunge', 'side_leg_raise'],
      ['side_leg_raise', 'calf_raise'],
      ['russian_twist', 'heel_taps', 'dead_bug'],
      ['calf_raise', 'glute_bridge'],
    ],
    SessionType.cardioCore: [
      ['dead_bug', 'heel_taps'],
      ['forearm_plank', 'bird_dog', 'heel_taps'],
      ['russian_twist', 'side_plank', 'dead_bug'],
      ['glute_bridge', 'single_leg_bridge'],
    ],
    SessionType.cardioCore2: [
      ['bird_dog', 'dead_bug'],
      ['side_plank', 'heel_taps'],
      ['crunch', 'dead_bug'],
      ['single_leg_bridge', 'glute_bridge'],
    ],
    SessionType.mobility: [],
  };

  static const _cooldowns = <SessionType, List<String>>{
    SessionType.fullA: ['hamstring_stretch', 'doorway_chest', 'figure_four',
        'quad_stretch', 'knees_to_chest', 'seated_side_bend'],
    SessionType.fullB: ['quad_stretch', 'cross_body_shoulder', 'hamstring_stretch',
        'childs_pose', 'knees_to_chest', 'seated_side_bend'],
    SessionType.fullC: ['figure_four', 'triceps_stretch', 'hip_flexor_stretch',
        'hamstring_stretch', 'knees_to_chest', 'seated_side_bend'],
    SessionType.upperA: ['doorway_chest', 'cross_body_shoulder',
        'triceps_stretch', 'wrist_stretch', 'seated_side_bend', 'cat_cow'],
    SessionType.upperB: ['cross_body_shoulder', 'triceps_stretch',
        'doorway_chest', 'neck_stretch', 'seated_side_bend', 'childs_pose'],
    SessionType.lowerA: ['hamstring_stretch', 'quad_stretch', 'figure_four',
        'calf_stretch', 'knees_to_chest', 'seated_side_bend'],
    SessionType.lowerB: ['hip_flexor_stretch', 'hamstring_stretch',
        'figure_four', 'calf_stretch', 'knees_to_chest', 'spinal_twist'],
    SessionType.cardioCore: ['calf_stretch', 'hamstring_stretch',
        'knees_to_chest', 'spinal_twist', 'seated_side_bend'],
    SessionType.cardioCore2: ['hip_flexor_stretch', 'hamstring_stretch',
        'knees_to_chest', 'cat_cow', 'seated_side_bend'],
    SessionType.mobility: ['cat_cow', 'hamstring_stretch', 'figure_four',
        'doorway_chest', 'cross_body_shoulder', 'spinal_twist',
        'knees_to_chest', 'calf_stretch', 'neck_stretch', 'seated_side_bend'],
  };

  static List<SessionType> splitFor(int days) => switch (days) {
        1 => [SessionType.fullA],
        2 => [SessionType.fullA, SessionType.fullB],
        3 => [SessionType.fullA, SessionType.fullB, SessionType.fullC],
        4 => [SessionType.upperA, SessionType.lowerA, SessionType.upperB,
            SessionType.lowerB],
        5 => [SessionType.upperA, SessionType.lowerA, SessionType.cardioCore,
            SessionType.upperB, SessionType.lowerB],
        6 => [SessionType.upperA, SessionType.lowerA, SessionType.cardioCore,
            SessionType.upperB, SessionType.lowerB, SessionType.cardioCore2],
        _ => [SessionType.upperA, SessionType.lowerA, SessionType.cardioCore,
            SessionType.upperB, SessionType.lowerB, SessionType.cardioCore2,
            SessionType.mobility],
      };

  static String titleOf(SessionType t) => switch (t) {
        SessionType.fullA => 'Full body A',
        SessionType.fullB => 'Full body B',
        SessionType.fullC => 'Full body C',
        SessionType.upperA => 'Upper body A',
        SessionType.upperB => 'Upper body B',
        SessionType.lowerA => 'Lower body A',
        SessionType.lowerB => 'Lower body B',
        SessionType.cardioCore => 'Treadmill + core',
        SessionType.cardioCore2 => 'Treadmill + core B',
        SessionType.mobility => 'Walk & stretch',
      };

  /// Weekday (1 = Monday) -> that day's workout.
  static Map<int, PlannedWorkout> weekPlan(WorkoutPrefs p, Units units) {
    final days = p.weekdays.toList()..sort();
    final split = splitFor(days.length);
    return {
      for (var i = 0; i < days.length; i++)
        days[i]: build(split[i], p, units),
    };
  }

  /// A gentle 10-minute stretch for rest days.
  static PlannedWorkout restDayStretch(WorkoutPrefs p) => PlannedWorkout(
        title: 'Rest day stretch',
        subtitle: 'Optional · about 10 minutes',
        minutes: 10,
        sections: [
          WorkoutSection(
            'Stretches',
            _stretches(SessionType.mobility, p, count: 8),
            note: 'Move slowly and breathe. A walk is great too.',
          ),
        ],
      );

  static PlannedWorkout build(SessionType type, WorkoutPrefs p, Units units) {
    final m = p.minutes;
    final isCardioDay = type == SessionType.cardioCore ||
        type == SessionType.cardioCore2;
    final isMobility = type == SessionType.mobility;

    // How the time is split up.
    final (strengthCount, cardioMin) = isMobility
        ? (0, max(15, m - 15))
        : isCardioDay
            ? (m >= 45 ? 4 : 3, max(10, m - 15))
            : switch (p.focus) {
                WorkoutFocus.fatLoss => m <= 20
                    ? (3, 6)
                    : (m <= 30 ? (4, 10) : (6, 15)),
                WorkoutFocus.both => m <= 20
                    ? (3, 5)
                    : (m <= 30 ? (5, 8) : (6, 12)),
                WorkoutFocus.strength => m <= 20
                    ? (4, 0)
                    : (m <= 30 ? (5, 0) : (7, 5)),
              };

    final sections = <WorkoutSection>[
      WorkoutSection('Warm-up', [
        PlannedExercise(
          exercise: ExerciseLibrary.byId('warmup_walk'),
          prescription: '5 min',
        ),
        PlannedExercise(
          exercise: ExerciseLibrary.byId('arm_circles_leg_swings'),
          prescription: '1–2 min',
        ),
      ]),
    ];

    if (strengthCount > 0) {
      final main = _mainBlock(type, p, units, strengthCount);
      sections.add(WorkoutSection(
        isCardioDay ? 'Core' : 'Strength',
        main,
        note: isCardioDay
            ? 'Rest about 30 s between exercises.'
            : _restNote(p),
      ));
    }

    if (cardioMin > 0) {
      sections.add(WorkoutSection(
        'Treadmill',
        [_cardio(p, cardioMin, steady: isMobility)],
      ));
    }

    sections.add(WorkoutSection(
      'Cool-down stretches',
      _stretches(type, p, count: isMobility ? 8 : (m <= 20 ? 3 : 4)),
      note: 'Hold each stretch gently — no bouncing.',
    ));

    return PlannedWorkout(
      title: titleOf(type),
      subtitle: '$m min · ${p.focus.label}',
      minutes: m,
      sections: sections,
    );
  }

  static List<PlannedExercise> _mainBlock(
      SessionType type, WorkoutPrefs p, Units units, int count) {
    final out = <PlannedExercise>[];
    final used = <String>{};
    final slots = _templates[type]!;
    for (var i = 0; i < slots.length && out.length < count; i++) {
      final key = '${type.name}:$i';
      final allowed = [
        for (final id in slots[i])
          if (ExerciseLibrary.byId(id).allowedFor(p.avoid) && !used.contains(id))
            ExerciseLibrary.byId(id),
      ];
      if (allowed.isEmpty) continue;
      final swapped = p.swaps[key];
      final chosen = allowed.firstWhere(
        (e) => e.id == swapped,
        orElse: () => allowed.first,
      );
      used.add(chosen.id);
      out.add(_prescribe(chosen, p, units,
          slotKey: key,
          alternatives: allowed.where((e) => e.id != chosen.id).toList()));
    }
    return out;
  }

  static PlannedExercise _prescribe(Exercise e, WorkoutPrefs p, Units units,
      {String? slotKey, List<Exercise> alternatives = const []}) {
    final each = e.perSide ? ' each side' : '';
    final setAdj = switch (p.experience) {
      Experience.beginner => -1,
      Experience.intermediate => 0,
      Experience.advanced => 1,
    };

    if (e.kind == ExerciseKind.core) {
      final sets = max(2, 3 + (setAdj > 0 ? 0 : setAdj));
      final dose = e.timeBased
          ? switch (p.experience) {
              Experience.beginner => '20–30 s',
              Experience.intermediate => '30–45 s',
              Experience.advanced => '45–60 s',
            }
          : switch (p.experience) {
              Experience.beginner => '8–10',
              Experience.intermediate => '10–12',
              Experience.advanced => '12–15',
            };
      return PlannedExercise(
        exercise: e,
        prescription: '$sets × $dose$each',
        slotKey: slotKey,
        alternatives: alternatives,
      );
    }

    final (baseSets, reps) = switch (p.focus) {
      WorkoutFocus.strength => (3, '8–10'),
      WorkoutFocus.both => (3, '10–12'),
      WorkoutFocus.fatLoss => (3, '12–15'),
    };
    final sets = (baseSets + setAdj).clamp(2, 4);

    String? weight;
    final range = e.weightLb;
    if (range != null) {
      final (lo, hi) = range;
      final mid = ((lo + hi) / 2).round();
      // Lighter for more reps; heavier for strength. Never over 25 lb.
      var (a, b) = switch (p.experience) {
        Experience.beginner => (lo, mid),
        Experience.intermediate => (mid - 2, hi - 3),
        Experience.advanced => (mid, hi),
      };
      if (p.focus == WorkoutFocus.fatLoss) {
        a = max(lo, a - 3);
        b = max(a + 2, b - 3);
      }
      a = max(lo, min(a, 25));
      b = max(a, min(b, 25));
      weight = units == Units.imperial
          ? '$a–$b lb'
          : '${trimNumber(lbToKg(a.toDouble()))}–'
              '${trimNumber(lbToKg(b.toDouble()))} kg';
    }

    return PlannedExercise(
      exercise: e,
      prescription: '$sets × $reps$each',
      weight: weight,
      rest: _rest(p),
      slotKey: slotKey,
      alternatives: alternatives,
    );
  }

  static String _rest(WorkoutPrefs p) => switch (p.focus) {
        WorkoutFocus.strength => 'Rest 60–90 s',
        WorkoutFocus.both => 'Rest 45–60 s',
        WorkoutFocus.fatLoss => 'Rest 30–45 s',
      };

  static String _restNote(WorkoutPrefs p) =>
      '${_rest(p)} between sets. Pick a weight where the last 2 reps feel '
      'hard but your form stays clean.';

  static PlannedExercise _cardio(WorkoutPrefs p, int minutes,
      {bool steady = false}) {
    final order = steady
        ? ['steady_walk']
        : switch (p.focus) {
            WorkoutFocus.fatLoss => p.experience == Experience.beginner
                ? ['walk_intervals', 'incline_walk', 'steady_walk']
                : ['run_intervals', 'incline_intervals', 'walk_intervals',
                    'steady_walk'],
            WorkoutFocus.both => p.experience == Experience.advanced
                ? ['incline_intervals', 'walk_intervals', 'steady_walk']
                : ['incline_walk', 'walk_intervals', 'steady_walk'],
            WorkoutFocus.strength => ['incline_walk', 'steady_walk'],
          };
    final e = order
        .map(ExerciseLibrary.byId)
        .firstWhere((x) => x.allowedFor(p.avoid),
            orElse: () => ExerciseLibrary.byId('steady_walk'));
    return PlannedExercise(exercise: e, prescription: '$minutes min');
  }

  static List<PlannedExercise> _stretches(SessionType type, WorkoutPrefs p,
      {required int count}) {
    final ids = [
      ..._cooldowns[type]!,
      // Safe fallbacks if some were excluded.
      'knees_to_chest', 'seated_side_bend', 'hamstring_stretch',
    ];
    final out = <PlannedExercise>[];
    final used = <String>{};
    for (final id in ids) {
      if (out.length >= count) break;
      final e = ExerciseLibrary.byId(id);
      if (!e.allowedFor(p.avoid) || !used.add(id)) continue;
      out.add(PlannedExercise(
        exercise: e,
        prescription: 'Hold 30 s${e.perSide ? ' each side' : ''}',
      ));
    }
    return out;
  }
}
