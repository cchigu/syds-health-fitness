import 'dart:math';

import '../models/nutrients.dart';
import '../models/user_profile.dart';

/// The recommended goals plus the numbers behind them, so the Goals screen
/// can explain where they came from.
class GoalBreakdown {
  const GoalBreakdown({
    required this.bmr,
    required this.tdee,
    required this.activityFactor,
    required this.adjustment,
    required this.hitCalorieFloor,
    required this.calorieFloor,
    required this.proteinPerKg,
    required this.goals,
  });

  /// Calories burned at complete rest.
  final double bmr;

  /// Calories burned on a typical day including activity.
  final double tdee;
  final double activityFactor;

  /// Calories added or removed for the goal (e.g. -500 to lose weight).
  final int adjustment;

  /// True when the goal would have gone below the minimum and was raised.
  final bool hitCalorieFloor;
  final int calorieFloor;
  final double proteinPerKg;
  final Nutrients goals;
}

/// Turns a profile into daily calorie and macro goals.
///
/// - Calories: Mifflin-St Jeor equation x activity level, then adjusted for
///   the goal (-500 to lose, +300 to gain), never below 1,200 (women) or
///   1,500 (men).
/// - Protein: 1.8 g per kg of body weight when losing or gaining,
///   1.6 g/kg to maintain (capped at 35% of calories).
/// - Fat: 30% of calories.
/// - Carbs: whatever calories are left.
/// - Fiber: 14 g per 1,000 calories (US dietary guidelines).
class GoalCalculator {
  GoalCalculator._();

  static double activityFactor(ActivityLevel level) => switch (level) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };

  static int goalAdjustment(Goal goal) => switch (goal) {
        Goal.lose => -500,
        Goal.maintain => 0,
        Goal.gain => 300,
      };

  static int calorieFloor(Sex sex) => sex == Sex.female ? 1200 : 1500;

  /// Returns null until the profile has everything the formula needs.
  static GoalBreakdown? recommend(UserProfile p) {
    final weight = p.weightKg;
    final height = p.heightCm;
    final age = p.age;
    if (!p.isComplete || weight == null || height == null || age == null) {
      return null;
    }

    final bmr = 10 * weight +
        6.25 * height -
        5 * age +
        (p.sex == Sex.male ? 5 : -161);
    final factor = activityFactor(p.activityLevel);
    final tdee = bmr * factor;
    final adjustment = goalAdjustment(p.goal);
    final floor = calorieFloor(p.sex);

    var calories = tdee + adjustment;
    final hitFloor = calories < floor;
    calories = max(calories, floor.toDouble());
    calories = (calories / 10).round() * 10; // tidy number

    final proteinPerKg = p.goal == Goal.maintain ? 1.6 : 1.8;
    final protein = min(weight * proteinPerKg, calories * 0.35 / 4);
    final fat = calories * 0.30 / 9;
    final carbs = max(0.0, (calories - protein * 4 - fat * 9) / 4);
    final fiber = calories / 1000 * 14;

    return GoalBreakdown(
      bmr: bmr,
      tdee: tdee,
      activityFactor: factor,
      adjustment: adjustment,
      hitCalorieFloor: hitFloor,
      calorieFloor: floor,
      proteinPerKg: proteinPerKg,
      goals: Nutrients(
        calories: calories,
        protein: protein,
        carbs: carbs,
        fat: fat,
        fiber: fiber,
      ).rounded(),
    );
  }
}
