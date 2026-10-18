import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/models/macro_split.dart';
import 'package:syds_health_fitness/models/user_profile.dart';
import 'package:syds_health_fitness/services/energy_history.dart';
import 'package:syds_health_fitness/services/goal_calculator.dart';

UserProfile _profile({Goal goal = Goal.lose}) => UserProfile(
      name: 'Test',
      sex: Sex.female,
      birthDate: DateTime(DateTime.now().year - 30, 1, 1),
      heightCm: 165,
      weightKg: 65,
      activityLevel: ActivityLevel.light,
      goal: goal,
      units: Units.imperial,
      updatedAt: DateTime(2026),
      rateKgPerWeek: 0.45359237, // 1 lb/week
    );

void main() {
  group('MacroSplit', () {
    const split =
        MacroSplit(protein: 0.3, carbs: 0.4, fat: 0.3, fiberPer1000: 14);

    test('raising one macro shrinks the others and still adds to 100%', () {
      final s = split.withShare(Macro.protein, 0.45);
      expect(s.protein, closeTo(0.45, 1e-9));
      expect(s.protein + s.carbs + s.fat, closeTo(1, 1e-9));
      // Carbs and fat keep their 4:3 ratio.
      expect(s.carbs / s.fat, closeTo(0.4 / 0.3, 1e-9));
    });

    test('changing calories scales every macro proportionally', () {
      final a = split.goalsFor(2000);
      final b = split.goalsFor(1600);
      expect(b.protein / a.protein, closeTo(0.8, 0.01));
      expect(b.carbs / a.carbs, closeTo(0.8, 0.01));
      expect(b.fat / a.fat, closeTo(0.8, 0.02));
      expect(b.fiber / a.fiber, closeTo(0.8, 0.05));
    });

    test('macro calories add up to the calorie goal', () {
      final g = split.withGrams(Macro.protein, 150, 1800).goalsFor(1800);
      final kcal = g.protein * 4 + g.carbs * 4 + g.fat * 9;
      expect(kcal, closeTo(1800, 15)); // rounding to whole grams
    });
  });

  group('MaintenanceEstimator', () {
    final today = DateTime(2026, 10, 18);

    test('uses the profile formula with no data', () {
      final m = MaintenanceEstimator.estimate(
        formulaTdee: 1900,
        history: EnergyHistory.empty,
        today: today,
      );
      expect(m.calories, 1900);
      expect(m.usesData, isFalse);
    });

    test('learns maintenance from 14 days of food and weight', () {
      // Eats 1,700 a day and loses 0.5 kg in 14 days:
      // maintenance = 1700 + 0.5 x 7700 / 14 = 1,975.
      final calories = {
        for (var i = 1; i <= 14; i++)
          dayOnly(today.subtract(Duration(days: i))): 1700.0,
      };
      final weights = [
        for (var i = 0; i <= 14; i++)
          WeightEntry(today.subtract(Duration(days: 14 - i)), 65 - 0.5 * i / 14),
      ];
      final m = MaintenanceEstimator.estimate(
        formulaTdee: 1900,
        history: EnergyHistory(caloriesByDay: calories, weights: weights),
        today: today,
      );
      expect(m.confidence, closeTo(1, 1e-9));
      expect(m.dataCalories, closeTo(1975, 5));
      expect(m.calories, closeTo(1975, 5));
    });

    test('ignores half-logged days', () {
      final calories = {
        for (var i = 1; i <= 14; i++)
          dayOnly(today.subtract(Duration(days: i))): i.isEven ? 1800.0 : 300.0,
      };
      final m = MaintenanceEstimator.estimate(
        formulaTdee: 1900,
        history: EnergyHistory(caloriesByDay: calories),
        today: today,
      );
      expect(m.loggedDays, 7);
    });
  });

  group('GoalCalculator', () {
    test('1 lb/week loss is 500 under maintenance', () {
      final plan = GoalCalculator.plan(_profile(), EnergyHistory.empty)!;
      final maintenance = plan.maintenance.calories;
      expect(plan.calories, closeTo(maintenance - 500, 10));
    });

    test('never recommends below the minimum', () {
      final p = _profile().copyWith(rateKgPerWeek: 2 * 0.45359237);
      final plan = GoalCalculator.plan(p, EnergyHistory.empty)!;
      expect(plan.calories, greaterThanOrEqualTo(1200));
    });

    test('custom calories rescale recommended macros', () {
      final auto = GoalCalculator.plan(_profile(), EnergyHistory.empty)!;
      final custom = GoalCalculator.plan(
        _profile().copyWith(caloriesOverride: auto.calories - 300),
        EnergyHistory.empty,
      )!;
      expect(custom.goals.calories, auto.calories - 300);
      expect(custom.goals.fat, lessThan(auto.goals.fat));
    });
  });
}
