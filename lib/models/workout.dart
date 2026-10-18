import '../services/synced_store.dart';
import '../utils/dates.dart';

/// Parts of the body Syd may want to go easy on. Exercises that load an
/// area she picks are left out of her plan.
enum BodyArea { knees, lowerBack, shoulders, wrists, hips, ankles, neck }

extension BodyAreaLabel on BodyArea {
  String get label => switch (this) {
        BodyArea.knees => 'Knees',
        BodyArea.lowerBack => 'Lower back',
        BodyArea.shoulders => 'Shoulders',
        BodyArea.wrists => 'Wrists',
        BodyArea.hips => 'Hips',
        BodyArea.ankles => 'Ankles',
        BodyArea.neck => 'Neck',
      };
}

enum WorkoutFocus { fatLoss, strength, both }

extension WorkoutFocusLabel on WorkoutFocus {
  String get label => switch (this) {
        WorkoutFocus.fatLoss => 'Burn fat & get lean',
        WorkoutFocus.strength => 'Tone up & get stronger',
        WorkoutFocus.both => 'A bit of both',
      };
  String get description => switch (this) {
        WorkoutFocus.fatLoss =>
          'More treadmill time, lighter weights, more reps, short rests.',
        WorkoutFocus.strength =>
          'Heavier dumbbells, fewer reps, longer rests, a little cardio.',
        WorkoutFocus.both => 'Balanced strength work with a cardio finisher.',
      };
}

enum Experience { beginner, intermediate, advanced }

/// The intensity dial on the Workouts tab: -2 (easiest) to +2 (hardest).
class Intensity {
  Intensity._();
  static const int min = -2;
  static const int max = 2;

  static String label(int level) => switch (level) {
        <= -2 => 'Easy does it',
        -1 => 'A bit lighter',
        0 => 'Normal',
        1 => 'Turned up',
        _ => 'Beast mode 🔥',
      };

  static String description(int level) => switch (level) {
        <= -2 => 'Fewer sets, lighter weights, longer rests, gentle cardio.',
        -1 => 'A little easier than your plan — good for tired or busy weeks.',
        0 => 'Your plan exactly as built for you.',
        1 => 'An extra push: more sets, heavier weights, shorter rests.',
        _ => 'Maximum effort: the most sets, heaviest weights and cardio.',
      };
}

extension ExperienceLabel on Experience {
  String get label => switch (this) {
        Experience.beginner => 'New to it',
        Experience.intermediate => 'Some experience',
        Experience.advanced => 'Confident',
      };
  String get description => switch (this) {
        Experience.beginner => 'Little or no weight training yet',
        Experience.intermediate => 'Have worked out with weights before',
        Experience.advanced => 'Train regularly and know the moves',
      };
}

enum ExerciseKind { warmup, strength, core, cardio, stretch }

/// One exercise in the library.
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.kind,
    required this.steps,
    this.tip,
    this.stresses = const {},
    this.weightLb,
    this.perSide = false,
    this.timeBased = false,
    this.equipment = 'Bodyweight',
  });

  final String id;
  final String name;
  final ExerciseKind kind;

  /// How to do it, step by step.
  final List<String> steps;
  final String? tip;

  /// Areas this puts real load on (left out if she wants to protect them).
  final Set<BodyArea> stresses;

  /// Suggested dumbbell range (each hand unless the steps say otherwise).
  final (int, int)? weightLb;
  final bool perSide;

  /// Held for time (plank, stretches) rather than counted in reps.
  final bool timeBased;
  final String equipment;

  bool allowedFor(Set<BodyArea> avoid) => stresses.intersection(avoid).isEmpty;
}

/// Syd's answers to the setup questions.
class WorkoutPrefs implements Syncable {
  const WorkoutPrefs({
    required this.weekdays,
    required this.minutes,
    required this.focus,
    required this.experience,
    required this.avoid,
    required this.updatedAt,
    this.swaps = const {},
    this.intensity = 0,
    this.overrides = const {},
    this.removed = const {},
    this.extras = const {},
    this.customExercises = const [],
    this.minutesByDay = const {},
    this.deleted = false,
  });

  /// Workout length for each weekday (falls back to [minutes]).
  final Map<int, int> minutesByDay;

  int minutesFor(int weekday) => minutesByDay[weekday] ?? minutes;

  /// -2 (easiest) to +2 (hardest); 0 = the plan as built.
  final int intensity;

  /// Her own sets/reps/weight for an exercise in a workout.
  /// Key: "<workout>:<exerciseId>", e.g. "lowerA:goblet_squat".
  final Map<String, ExerciseOverride> overrides;

  /// Exercises she took out of a workout (same keys as [overrides]).
  final Set<String> removed;

  /// Exercises she added, by workout (e.g. "lowerA").
  final Map<String, List<ExtraExercise>> extras;

  /// Exercises she made up herself.
  final List<CustomExerciseDef> customExercises;

  /// 1 = Monday ... 7 = Sunday.
  final Set<int> weekdays;
  final int minutes;
  final WorkoutFocus focus;
  final Experience experience;
  final Set<BodyArea> avoid;

  /// Exercises she swapped: slot key -> exercise id.
  final Map<String, String> swaps;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  @override
  String get id => 'current';

  WorkoutPrefs copyWith({
    Map<String, String>? swaps,
    int? intensity,
    Map<String, ExerciseOverride>? overrides,
    Set<String>? removed,
    Map<String, List<ExtraExercise>>? extras,
    List<CustomExerciseDef>? customExercises,
    Map<int, int>? minutesByDay,
    DateTime? updatedAt,
  }) =>
      WorkoutPrefs(
        weekdays: weekdays,
        minutes: minutes,
        focus: focus,
        experience: experience,
        avoid: avoid,
        swaps: swaps ?? this.swaps,
        intensity: intensity ?? this.intensity,
        overrides: overrides ?? this.overrides,
        removed: removed ?? this.removed,
        extras: extras ?? this.extras,
        customExercises: customExercises ?? this.customExercises,
        minutesByDay: minutesByDay ?? this.minutesByDay,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  Map<String, dynamic> toMap() => {
        'weekdays': weekdays.toList()..sort(),
        'minutes': minutes,
        'focus': focus.name,
        'experience': experience.name,
        'avoid': [for (final a in avoid) a.name],
        'swaps': swaps,
        'intensity': intensity,
        'overrides': {
          for (final e in overrides.entries) e.key: e.value.toMap(),
        },
        'removed': removed.toList(),
        'extras': {
          for (final e in extras.entries)
            e.key: [for (final x in e.value) x.toMap()],
        },
        'customExercises': [for (final c in customExercises) c.toMap()],
        'minutesByDay': {
          for (final e in minutesByDay.entries) '${e.key}': e.value,
        },
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static WorkoutPrefs? fromMap(Map<String, dynamic> m) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.firstWhere((v) => v.name == raw, orElse: () => fallback);
    final days = {
      for (final d in (m['weekdays'] as List?) ?? const [])
        if (d is num && d >= 1 && d <= 7) d.toInt(),
    };
    if (days.isEmpty) return null;
    return WorkoutPrefs(
      weekdays: days,
      minutes: (m['minutes'] as num?)?.toInt() ?? 30,
      focus: pick(WorkoutFocus.values, m['focus'], WorkoutFocus.both),
      experience:
          pick(Experience.values, m['experience'], Experience.beginner),
      avoid: {
        for (final a in (m['avoid'] as List?) ?? const [])
          for (final b in BodyArea.values)
            if (b.name == a) b,
      },
      swaps: {
        for (final e in ((m['swaps'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
      intensity: ((m['intensity'] as num?)?.toInt() ?? 0)
          .clamp(Intensity.min, Intensity.max),
      overrides: {
        for (final e in ((m['overrides'] as Map?) ?? const {}).entries)
          if (e.value is Map)
            '${e.key}': ExerciseOverride.fromMap(
                Map<String, dynamic>.from(e.value as Map)),
      },
      removed: {
        for (final r in (m['removed'] as List?) ?? const []) '$r',
      },
      extras: {
        for (final e in ((m['extras'] as Map?) ?? const {}).entries)
          if (e.value is List)
            '${e.key}': [
              for (final x in e.value as List)
                if (x is Map)
                  ExtraExercise.fromMap(Map<String, dynamic>.from(x)),
            ],
      },
      customExercises: [
        for (final c in (m['customExercises'] as List?) ?? const [])
          if (c is Map) CustomExerciseDef.fromMap(Map<String, dynamic>.from(c)),
      ],
      minutesByDay: {
        for (final e in ((m['minutesByDay'] as Map?) ?? const {}).entries)
          if (int.tryParse('${e.key}') case final d? when e.value is num)
            d: (e.value as num).toInt(),
      },
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}

/// A finished workout (one per day).
class WorkoutDone implements Syncable {
  const WorkoutDone({
    required this.day,
    required this.title,
    required this.minutes,
    required this.updatedAt,
    this.deleted = false,
  });

  final DateTime day;
  final String title;
  final int minutes;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  @override
  String get id => dayKey(day);

  @override
  Map<String, dynamic> toMap() => {
        'day': dayKey(day),
        'title': title,
        'minutes': minutes,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static WorkoutDone? fromMap(Map<String, dynamic> m) {
    final day = parseDayKey(m['day'] as String?);
    if (day == null) return null;
    return WorkoutDone(
      day: day,
      title: (m['title'] as String?) ?? 'Workout',
      minutes: (m['minutes'] as num?)?.toInt() ?? 0,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}

/// An exercise as it appears in a planned workout.
class PlannedExercise {
  const PlannedExercise({
    required this.exercise,
    required this.prescription,
    this.weight,
    this.rest,
    this.slotKey,
    this.alternatives = const [],
    this.custom = false,
    this.extraIndex,
    this.minutes = 0,
  });

  final Exercise exercise;

  /// Estimated time this takes, sets and rest included.
  final double minutes;

  PlannedExercise withMinutes(double m) => PlannedExercise(
        exercise: exercise,
        prescription: prescription,
        weight: weight,
        rest: rest,
        slotKey: slotKey,
        alternatives: alternatives,
        custom: custom,
        extraIndex: extraIndex,
        minutes: m,
      );

  /// True when she set her own numbers for it.
  final bool custom;

  /// Set when she added this exercise herself (its place in her extras).
  final int? extraIndex;

  /// e.g. "3 × 10–12" or "Hold 30 s each side" or "10 min: …".
  final String prescription;

  /// e.g. "10–15 lb each hand".
  final String? weight;
  final String? rest;

  /// Identifies the spot in the plan, so a swap sticks.
  final String? slotKey;

  /// Other exercises that could go in this spot.
  final List<Exercise> alternatives;
}

class WorkoutSection {
  const WorkoutSection(this.title, this.exercises, {this.note});
  final String title;
  final List<PlannedExercise> exercises;
  final String? note;
}

class PlannedWorkout {
  const PlannedWorkout({
    required this.title,
    required this.subtitle,
    required this.minutes,
    required this.sections,
    this.sessionKey,
  });

  /// Which workout this is (e.g. "lowerA"); used to save her edits.
  final String? sessionKey;
  final String title;
  final String subtitle;
  final int minutes;
  final List<WorkoutSection> sections;

  /// How the time splits between warm-up, strength, treadmill and stretching.
  WorkoutBreakdown get breakdown {
    var warm = 0.0, strength = 0.0, cardio = 0.0, stretch = 0.0;
    for (final s in sections) {
      for (final pe in s.exercises) {
        switch (pe.exercise.kind) {
          case ExerciseKind.warmup:
            warm += pe.minutes;
          case ExerciseKind.strength:
          case ExerciseKind.core:
            strength += pe.minutes;
          case ExerciseKind.cardio:
            cardio += pe.minutes;
          case ExerciseKind.stretch:
            stretch += pe.minutes;
        }
      }
    }
    return WorkoutBreakdown(
      warmup: warm.round(),
      strength: strength.round(),
      treadmill: cardio.round(),
      stretching: stretch.round(),
    );
  }
}

class WorkoutBreakdown {
  const WorkoutBreakdown({
    required this.warmup,
    required this.strength,
    required this.treadmill,
    required this.stretching,
  });

  final int warmup;

  /// Dumbbell and core work.
  final int strength;
  final int treadmill;
  final int stretching;

  int get total => warmup + strength + treadmill + stretching;
}

/// Her own numbers for an exercise.
class ExerciseOverride {
  const ExerciseOverride({required this.prescription, this.weightLb});

  /// e.g. "3 × 12" or "15 min".
  final String prescription;
  final double? weightLb;

  Map<String, dynamic> toMap() =>
      {'prescription': prescription, 'weightLb': weightLb};

  static ExerciseOverride fromMap(Map<String, dynamic> m) => ExerciseOverride(
        prescription: (m['prescription'] as String?) ?? '',
        weightLb: (m['weightLb'] as num?)?.toDouble(),
      );
}

/// An exercise she added to a workout.
class ExtraExercise {
  const ExtraExercise({
    required this.exerciseId,
    required this.prescription,
    this.weightLb,
  });

  final String exerciseId;
  final String prescription;
  final double? weightLb;

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'prescription': prescription,
        'weightLb': weightLb,
      };

  static ExtraExercise fromMap(Map<String, dynamic> m) => ExtraExercise(
        exerciseId: (m['exerciseId'] as String?) ?? '',
        prescription: (m['prescription'] as String?) ?? '',
        weightLb: (m['weightLb'] as num?)?.toDouble(),
      );
}

/// An exercise she made up (name and her own notes).
class CustomExerciseDef {
  const CustomExerciseDef({
    required this.id,
    required this.name,
    this.notes = '',
  });

  final String id;
  final String name;
  final String notes;

  Exercise toExercise() => Exercise(
        id: id,
        name: name,
        kind: ExerciseKind.strength,
        equipment: 'My exercise',
        steps: notes.trim().isEmpty
            ? const ['One of your own exercises.']
            : notes.trim().split('\n'),
      );

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'notes': notes};

  static CustomExerciseDef fromMap(Map<String, dynamic> m) => CustomExerciseDef(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'My exercise',
        notes: (m['notes'] as String?) ?? '',
      );
}

/// A one-week change: a workout moved to another day, or skipped.
class ScheduleChange implements Syncable {
  const ScheduleChange({
    required this.originalDay,
    required this.updatedAt,
    this.newDay,
    this.deleted = false,
  });

  /// The day it was planned for.
  final DateTime originalDay;

  /// Where it moved to; null means skipped this week.
  final DateTime? newDay;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  bool get skipped => newDay == null;

  @override
  String get id => dayKey(originalDay);

  @override
  Map<String, dynamic> toMap() => {
        'originalDay': dayKey(originalDay),
        'newDay': newDay == null ? null : dayKey(newDay!),
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static ScheduleChange? fromMap(Map<String, dynamic> m) {
    final original = parseDayKey(m['originalDay'] as String?);
    if (original == null) return null;
    return ScheduleChange(
      originalDay: original,
      newDay: parseDayKey(m['newDay'] as String?),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}

/// A workout placed on an actual date this week.
class ScheduledWorkout {
  const ScheduledWorkout({
    required this.day,
    required this.originalDay,
    required this.workout,
  });

  final DateTime day;
  final DateTime originalDay;
  final PlannedWorkout workout;

  bool get moved => !isSameDay(day, originalDay);
}

class WeekSchedule {
  const WeekSchedule(this.scheduled, this.skipped);

  /// Sorted by day.
  final List<ScheduledWorkout> scheduled;
  final List<ScheduledWorkout> skipped;

  ScheduledWorkout? on(DateTime day) {
    for (final s in scheduled) {
      if (isSameDay(s.day, day)) return s;
    }
    return null;
  }
}
