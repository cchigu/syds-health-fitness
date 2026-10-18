/// Everything about Syd that the app needs for goals and display.
///
/// Measurements are always stored in metric (cm, kg) so the math is simple;
/// the [units] setting only changes how they are shown and typed in.
library;

import 'nutrients.dart';

enum Sex { female, male }

enum ActivityLevel { sedentary, light, moderate, active, veryActive }

enum Goal { lose, maintain, gain }

enum Units { imperial, metric }

extension SexLabel on Sex {
  String get label => this == Sex.female ? 'Female' : 'Male';
}

extension ActivityLevelLabel on ActivityLevel {
  String get label => switch (this) {
        ActivityLevel.sedentary => 'Sedentary',
        ActivityLevel.light => 'Lightly active',
        ActivityLevel.moderate => 'Moderately active',
        ActivityLevel.active => 'Very active',
        ActivityLevel.veryActive => 'Extremely active',
      };

  String get description => switch (this) {
        ActivityLevel.sedentary => 'Desk job, little or no exercise',
        ActivityLevel.light => 'Light exercise 1–3 days a week',
        ActivityLevel.moderate => 'Moderate exercise 3–5 days a week',
        ActivityLevel.active => 'Hard exercise 6–7 days a week',
        ActivityLevel.veryActive => 'Physical job plus hard training',
      };
}

extension GoalLabel on Goal {
  String get label => switch (this) {
        Goal.lose => 'Lose weight',
        Goal.maintain => 'Maintain',
        Goal.gain => 'Gain weight',
      };
}

extension UnitsLabel on Units {
  String get label => this == Units.imperial ? 'lbs / ft' : 'kg / cm';
}

class UserProfile {
  const UserProfile({
    required this.name,
    required this.sex,
    required this.birthDate,
    required this.heightCm,
    required this.weightKg,
    required this.activityLevel,
    required this.goal,
    required this.units,
    required this.updatedAt,
    this.customGoals,
  });

  final String name;
  final Sex sex;
  final DateTime? birthDate;
  final double? heightCm;
  final double? weightKg;
  final ActivityLevel activityLevel;
  final Goal goal;
  final Units units;

  /// When this profile was last edited; used to decide whether the phone's
  /// copy or the cloud copy is newer.
  final DateTime updatedAt;

  /// Goals Syd typed in herself. Null means "use the recommended goals",
  /// which update automatically whenever the profile changes.
  final Nutrients? customGoals;

  static UserProfile empty() => UserProfile(
        name: '',
        sex: Sex.female,
        birthDate: null,
        heightCm: null,
        weightKg: null,
        activityLevel: ActivityLevel.light,
        goal: Goal.maintain,
        units: Units.imperial,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  /// True once every field the macro calculator needs has been filled in.
  bool get isComplete =>
      name.trim().isNotEmpty &&
      birthDate != null &&
      heightCm != null &&
      weightKg != null;

  /// True if anything at all has been saved yet.
  bool get hasBeenEdited => updatedAt.millisecondsSinceEpoch > 0;

  int? get age {
    final b = birthDate;
    if (b == null) return null;
    final now = DateTime.now();
    var years = now.year - b.year;
    if (now.month < b.month || (now.month == b.month && now.day < b.day)) {
      years--;
    }
    return years;
  }

  UserProfile copyWith({DateTime? updatedAt}) => withCustomGoals(
        customGoals,
        updatedAt: updatedAt,
      );

  /// Same profile with different custom goals (pass null to go back to
  /// the recommended goals).
  UserProfile withCustomGoals(Nutrients? goals, {DateTime? updatedAt}) =>
      UserProfile(
        name: name,
        sex: sex,
        birthDate: birthDate,
        heightCm: heightCm,
        weightKg: weightKg,
        activityLevel: activityLevel,
        goal: goal,
        units: units,
        updatedAt: updatedAt ?? this.updatedAt,
        customGoals: goals,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'sex': sex.name,
        'birthDate': birthDate?.toIso8601String(),
        'heightCm': heightCm,
        'weightKg': weightKg,
        'activityLevel': activityLevel.name,
        'goal': goal.name,
        'units': units.name,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'customGoals': customGoals?.toMap(),
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    T pick<T extends Enum>(List<T> values, Object? raw, T fallback) =>
        values.firstWhere((v) => v.name == raw, orElse: () => fallback);

    double? toDouble(Object? v) => v is num ? v.toDouble() : null;

    return UserProfile(
      name: (map['name'] as String?) ?? '',
      sex: pick(Sex.values, map['sex'], Sex.female),
      birthDate: map['birthDate'] is String
          ? DateTime.tryParse(map['birthDate'] as String)
          : null,
      heightCm: toDouble(map['heightCm']),
      weightKg: toDouble(map['weightKg']),
      activityLevel:
          pick(ActivityLevel.values, map['activityLevel'], ActivityLevel.light),
      goal: pick(Goal.values, map['goal'], Goal.maintain),
      units: pick(Units.values, map['units'], Units.imperial),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        (map['updatedAt'] as num?)?.toInt() ?? 0,
      ),
      customGoals: map['customGoals'] is Map
          ? Nutrients.fromMap(
              Map<String, dynamic>.from(map['customGoals'] as Map))
          : null,
    );
  }
}
