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
    this.deleted = false,
  });

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

  WorkoutPrefs copyWith({Map<String, String>? swaps, DateTime? updatedAt}) =>
      WorkoutPrefs(
        weekdays: weekdays,
        minutes: minutes,
        focus: focus,
        experience: experience,
        avoid: avoid,
        swaps: swaps ?? this.swaps,
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
  });

  final Exercise exercise;

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
  });

  final String title;
  final String subtitle;
  final int minutes;
  final List<WorkoutSection> sections;
}
