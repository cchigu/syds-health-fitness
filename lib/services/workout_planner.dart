import 'dart:math';

import '../data/exercise_library.dart';
import '../models/user_profile.dart';
import '../models/workout.dart';
import '../utils/dates.dart';
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

  /// Weekday (1 = Monday) -> which workout is that day.
  static Map<int, SessionType> weekTypes(WorkoutPrefs p) {
    final days = p.weekdays.toList()..sort();
    final split = splitFor(days.length);
    return {for (var i = 0; i < days.length; i++) days[i]: split[i]};
  }

  /// Weekday (1 = Monday) -> that day's workout at her usual length.
  static Map<int, PlannedWorkout> weekPlan(WorkoutPrefs p, Units units) => {
        for (final e in weekTypes(p).entries)
          e.key: build(e.value, p, units, minutes: p.minutesFor(e.key)),
      };

  /// The actual dates for the week starting [monday], after one-week moves
  /// and skips.
  static WeekSchedule weekSchedule(
    WorkoutPrefs p,
    Units units,
    DateTime monday, {
    required ScheduleChange? Function(DateTime originalDay) changeFor,
  }) {
    final scheduled = <ScheduledWorkout>[];
    final skipped = <ScheduledWorkout>[];
    weekTypes(p).forEach((weekday, type) {
      final original = dayOnly(monday.add(Duration(days: weekday - 1)));
      final change = changeFor(original);
      final usual = p.minutesFor(weekday);
      final s = ScheduledWorkout(
        day: change?.newDay ?? original,
        originalDay: original,
        workout: build(type, p, units, minutes: change?.minutes ?? usual),
        lengthThisWeek: change?.minutes,
        usualMinutes: usual,
      );
      if (change != null && change.skipped) {
        skipped.add(s);
      } else {
        scheduled.add(s);
      }
    });
    scheduled.sort((a, b) => a.day.compareTo(b.day));
    skipped.sort((a, b) => a.originalDay.compareTo(b.originalDay));
    return WeekSchedule(scheduled, skipped);
  }

  /// Any exercise: from the library or one she made up.
  static Exercise? exerciseById(WorkoutPrefs p, String id) {
    final lib = ExerciseLibrary.all[id];
    if (lib != null) return lib;
    for (final c in p.customExercises) {
      if (c.id == id) return c.toExercise();
    }
    return null;
  }

  static String formatWeight(double lb, Units units) => units == Units.imperial
      ? '${trimNumber(lb)} lb'
      : '${trimNumber(lbToKg(lb))} kg';

  /// A gentle 10-minute stretch for rest days.
  static PlannedWorkout restDayStretch(WorkoutPrefs p) => PlannedWorkout(
        sessionKey: 'restDay',
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

  /// Rest-day stretch with her edits applied.
  static PlannedWorkout restDay(WorkoutPrefs p, Units units) {
    final base = restDayStretch(p);
    return _finish(PlannedWorkout(
      sessionKey: base.sessionKey,
      title: base.title,
      subtitle: '',
      minutes: base.minutes,
      sections: _applyEdits('restDay', base.sections, p, units),
    ), p, subtitle: (m) => 'Optional · about $m min');
  }

  /// Minutes per set, including rest (or time paired with another move).
  static double _perSet(WorkoutPrefs p) => switch (p.focus) {
        WorkoutFocus.strength => 1.4,
        WorkoutFocus.both => 1.0,
        WorkoutFocus.fatLoss => 0.9,
      };

  static int _setAdj(WorkoutPrefs p) {
    final i = p.intensity;
    return switch (p.experience) {
          Experience.beginner => -1,
          Experience.intermediate => 0,
          Experience.advanced => 1,
        } +
        (i > 0 ? 1 : (i < 0 ? -1 : 0)) +
        (i.abs() >= 2 ? i.sign : 0);
  }

  static int _strengthSets(WorkoutPrefs p) => (3 + _setAdj(p)).clamp(2, 5);
  static int _coreSets(WorkoutPrefs p) =>
      (3 + min<int>(_setAdj(p), 1)).clamp(2, 4);

  /// How long an exercise takes, read from what it says to do.
  static double estimateMinutes(Exercise e, String prescription, WorkoutPrefs p) {
    double? first(String pattern) {
      final m = RegExp(pattern).firstMatch(prescription);
      return m == null ? null : double.tryParse(m.group(1)!);
    }

    switch (e.kind) {
      case ExerciseKind.warmup:
      case ExerciseKind.cardio:
        return first(r'(\d+(?:\.\d+)?)\s*min') ?? first(r'(\d+)') ?? 5;
      case ExerciseKind.stretch:
        final secs = first(r'(\d+)\s*s') ?? 30;
        final sides = prescription.contains('each side') ? 2 : 1;
        return secs * sides / 60 + 0.25;
      case ExerciseKind.strength:
      case ExerciseKind.core:
        final sets = first(r'^\s*(\d+)\s*×') ?? 3;
        return sets * (e.kind == ExerciseKind.core ? 0.75 : _perSet(p));
    }
  }

  /// Adds time estimates to every exercise and sets the total + subtitle.
  static PlannedWorkout _finish(PlannedWorkout w, WorkoutPrefs p,
      {required String Function(int minutes) subtitle}) {
    final sections = [
      for (final s in w.sections)
        WorkoutSection(
          s.title,
          [
            for (final pe in s.exercises)
              pe.withMinutes(estimateMinutes(pe.exercise, pe.prescription, p)),
          ],
          note: s.note,
        ),
    ];
    final draft = PlannedWorkout(
      sessionKey: w.sessionKey,
      title: w.title,
      subtitle: w.subtitle,
      minutes: w.minutes,
      sections: sections,
    );
    final total = draft.breakdown.total;
    return PlannedWorkout(
      sessionKey: w.sessionKey,
      title: w.title,
      subtitle: subtitle(total),
      minutes: total,
      sections: sections,
    );
  }

  /// Builds one workout to fit [minutes] (her length for that day).
  ///
  /// The time is budgeted: warm-up and stretches first, then a treadmill
  /// share that depends on her goal, and the rest goes to strength —
  /// as many exercises as fit at her number of sets.
  static PlannedWorkout build(SessionType type, WorkoutPrefs p, Units units,
      {int? minutes}) {
    final m = minutes ?? p.minutes;
    final i = p.intensity;
    final isCardioDay = type == SessionType.cardioCore ||
        type == SessionType.cardioCore2;
    final isMobility = type == SessionType.mobility;

    final warm = m <= 12 ? 2 : (m <= 15 ? 3 : 5);
    final stretchList = _stretches(type, p,
        count: isMobility
            ? 8
            : (m <= 12
                ? 2
                : (m <= 20
                    ? 3
                    : (m <= 30 ? 4 : (m <= 45 ? 5 : (m <= 75 ? 6 : 7))))));
    final stretchMin = stretchList.fold<double>(
        0, (t, pe) => t + estimateMinutes(pe.exercise, pe.prescription, p));
    final left = m - warm - stretchMin;

    var strengthCount = 0;
    var perExercise = 0.0;
    var strengthBudget = 0.0;
    int cardio;
    if (isMobility) {
      cardio = max(5, left.round());
    } else if (isCardioDay) {
      strengthCount = m >= 45 ? 4 : 3;
      perExercise = _coreSets(p) * 0.75;
      // Short days: fewer core moves so there's still real treadmill time.
      while (strengthCount > 1 && left - strengthCount * perExercise < 5) {
        strengthCount--;
      }
      strengthBudget = strengthCount * perExercise;
      cardio = max(5, (left - strengthBudget).round());
    } else {
      final share = switch (p.focus) {
        WorkoutFocus.fatLoss => 0.45,
        WorkoutFocus.both => 0.30,
        WorkoutFocus.strength => m >= 45 ? 0.12 : 0.0,
      };
      cardio = (left * share).round();
      if (cardio > 0) cardio += 2 * i; // intensity: ~2 min per level
      if (cardio == 0 && i >= 2 && m >= 20) cardio = 5;
      if (cardio < 4) {
        cardio = p.focus == WorkoutFocus.fatLoss && left >= 9 ? 4 : 0;
      }

      perExercise = _strengthSets(p) * _perSet(p);
      strengthBudget = max(0.0, left - cardio);
      strengthCount = (strengthBudget / perExercise).floor().clamp(1, 7);
    }

    // Build the exercises first: if fewer fit than planned (e.g. some were
    // left out to protect an area), the spare time goes to the treadmill.
    final main = strengthCount > 0
        ? _mainBlock(type, p, units, strengthCount)
        : const <PlannedExercise>[];
    final spare = strengthBudget - main.length * perExercise;
    if (spare >= 2) cardio += spare.floor();

    final sections = <WorkoutSection>[
      WorkoutSection('Warm-up', [
        PlannedExercise(
          exercise: ExerciseLibrary.byId('warmup_walk'),
          prescription: '${max(1, warm - 1)} min',
        ),
        PlannedExercise(
          exercise: ExerciseLibrary.byId('arm_circles_leg_swings'),
          prescription: '1 min',
        ),
      ]),
    ];

    if (main.isNotEmpty) {
      sections.add(WorkoutSection(
        isCardioDay ? 'Core' : 'Strength',
        main,
        note: isCardioDay
            ? 'Rest about ${max(15, 30 - 5 * i)} s between exercises.'
            : _restNote(p),
      ));
    }

    if (cardio > 0) {
      sections.add(WorkoutSection(
        'Treadmill',
        [_cardio(p, cardio, steady: isMobility)],
        note: i > 0
            ? 'Push the speed or incline up a notch from your usual.'
            : (i < 0 ? 'Keep it comfortable — you can talk the whole time.'
                : null),
      ));
    }

    sections.add(WorkoutSection(
      'Cool-down stretches',
      stretchList,
      note: 'Hold each stretch gently — no bouncing.',
    ));

    return _finish(
      PlannedWorkout(
        sessionKey: type.name,
        title: titleOf(type),
        subtitle: '',
        minutes: m,
        sections: _applyEdits(type.name, sections, p, units),
      ),
      p,
      subtitle: (total) => i == 0
          ? '$total min · ${p.focus.label}'
          : '$total min · ${p.focus.label} · ${Intensity.label(i)}',
    );
  }

  /// Her own changes: removed exercises, her numbers, and added exercises.
  static List<WorkoutSection> _applyEdits(String session,
      List<WorkoutSection> sections, WorkoutPrefs p, Units units) {
    final edited = <WorkoutSection>[
      for (final s in sections)
        WorkoutSection(
          s.title,
          [
            for (final pe in s.exercises)
              if (!p.removed.contains('$session:${pe.exercise.id}'))
                _withOverride(pe, p.overrides['$session:${pe.exercise.id}'],
                    units),
          ],
          note: s.note,
        ),
    ];

    final extras = p.extras[session] ?? const [];
    if (extras.isEmpty) return edited;
    final added = <PlannedExercise>[
      for (var i = 0; i < extras.length; i++)
        if (exerciseById(p, extras[i].exerciseId) case final e?)
          PlannedExercise(
            exercise: e,
            prescription: extras[i].prescription,
            weight: extras[i].weightLb == null
                ? null
                : formatWeight(extras[i].weightLb!, units),
            custom: true,
            extraIndex: i,
          ),
    ];
    final main = edited.indexWhere(
        (s) => s.title == 'Strength' || s.title == 'Core');
    if (main >= 0) {
      final s = edited[main];
      edited[main] =
          WorkoutSection(s.title, [...s.exercises, ...added], note: s.note);
    } else {
      // Rest-day stretch or walk days: put them before the cool-down.
      final at = max(0, edited.length - 1);
      edited.insert(at, WorkoutSection('My exercises', added));
    }
    return edited;
  }

  static PlannedExercise _withOverride(
      PlannedExercise pe, ExerciseOverride? o, Units units) {
    if (o == null) return pe;
    return PlannedExercise(
      exercise: pe.exercise,
      prescription: o.prescription,
      weight: o.weightLb == null ? pe.weight : formatWeight(o.weightLb!, units),
      rest: pe.rest,
      slotKey: pe.slotKey,
      alternatives: pe.alternatives,
      custom: true,
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
    final i = p.intensity;

    if (e.kind == ExerciseKind.core) {
      final sets = _coreSets(p);
      // Experience picks the starting point; intensity moves it up or down.
      final level = (p.experience.index + 1 + i).clamp(0, 4);
      final dose = e.timeBased
          ? const ['15–20 s', '20–30 s', '30–45 s', '45–60 s', '60–75 s'][level]
          : const ['6–8', '8–10', '10–12', '12–15', '15–20'][level];
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
    final sets = (baseSets - 3 + _strengthSets(p)).clamp(2, 5);

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
      // Intensity: about 2–3 lb heavier or lighter per level.
      a += (i * 2.5).round();
      b += (i * 2.5).round();
      final floor = i < 0 ? max(3, lo - 5) : lo;
      a = max(floor, min(a, 25));
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

  /// Shorter rests when turned up, longer when turned down.
  static String _rest(WorkoutPrefs p) {
    final (lo, hi) = switch (p.focus) {
      WorkoutFocus.strength => (60, 90),
      WorkoutFocus.both => (45, 60),
      WorkoutFocus.fatLoss => (30, 45),
    };
    final shift = 10 * p.intensity;
    return 'Rest ${max(20, lo - shift)}–${max(30, hi - shift)} s';
  }

  static String _restNote(WorkoutPrefs p) =>
      '${_rest(p)} between sets. Pick a weight where the last 2 reps feel '
      'hard but your form stays clean.';

  static PlannedExercise _cardio(WorkoutPrefs p, int minutes,
      {bool steady = false}) {
    // Turning intensity up or down picks the cardio for one level of
    // experience higher or lower.
    final level = (p.experience.index + p.intensity.sign).clamp(0, 2);
    final exp = Experience.values[level];
    final order = steady
        ? ['steady_walk']
        : switch (p.focus) {
            WorkoutFocus.fatLoss => exp == Experience.beginner
                ? ['walk_intervals', 'incline_walk', 'steady_walk']
                : ['run_intervals', 'incline_intervals', 'walk_intervals',
                    'steady_walk'],
            WorkoutFocus.both => exp == Experience.advanced
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
