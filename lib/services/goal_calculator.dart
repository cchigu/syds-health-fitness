import 'dart:math';

import '../models/macro_split.dart';
import '../models/nutrients.dart';
import '../models/user_profile.dart';
import 'energy_history.dart';

/// Calories stored in 1 kg of body weight change (about 3,500 per lb).
const double kcalPerKg = 7700;

/// How Syd's maintenance calories (what keeps her weight steady) were found.
class MaintenanceEstimate {
  const MaintenanceEstimate({
    required this.calories,
    required this.formulaCalories,
    required this.dataCalories,
    required this.confidence,
    required this.windowDays,
    required this.loggedDays,
    required this.weighIns,
    required this.avgIntake,
    required this.weightTrendKgPerWeek,
  });

  /// The number actually used: a blend of [formulaCalories] and
  /// [dataCalories], weighted by [confidence].
  final double calories;

  /// From the profile alone (Mifflin-St Jeor x activity level).
  final double formulaCalories;

  /// From her own logs: average eaten minus the energy in her weight change.
  /// Null until there's enough data.
  final double? dataCalories;

  /// 0 = profile formula only, 1 = her own data only.
  final double confidence;

  final int windowDays;
  final int loggedDays;
  final int weighIns;
  final double? avgIntake;
  final double? weightTrendKgPerWeek;

  bool get usesData => dataCalories != null && confidence > 0;
}

/// Learns maintenance calories from the last [windowDays] days.
///
/// Energy balance: if she ate an average of X calories a day and her weight
/// trend moved by S kg a day, her body burned about X - S x 7,700 a day.
/// - The weight trend is a straight-line fit through every weigh-in, so one
///   heavy or light morning (water, salt) barely moves it.
/// - Today is left out (still being logged), and so are days with
///   suspiciously few calories, which are usually forgotten logs.
/// - The result is kept within 30% of the profile formula to guard against
///   bad data, and blended with it until 14 full days are available.
class MaintenanceEstimator {
  MaintenanceEstimator._();

  static const int windowDays = 14;
  static const int minLoggedDays = 7;
  static const int minWeighIns = 3;
  static const int minWeightSpanDays = 7;

  static MaintenanceEstimate estimate({
    required double formulaTdee,
    required EnergyHistory history,
    DateTime? today,
  }) {
    final end = dayOnly(today ?? DateTime.now());
    final start = end.subtract(const Duration(days: windowDays));

    // Average intake over complete, plausible days.
    final minPlausible = max(800.0, formulaTdee * 0.4);
    final intakes = <double>[];
    history.caloriesByDay.forEach((day, kcal) {
      final d = dayOnly(day);
      if (!d.isBefore(start) && d.isBefore(end) && kcal >= minPlausible) {
        intakes.add(kcal);
      }
    });

    // Weight trend from a least-squares line through the weigh-ins.
    final points = history.weights
        .where((w) =>
            !dayOnly(w.date).isBefore(start) && !dayOnly(w.date).isAfter(end))
        .toList();
    double? slopePerDay;
    double spanDays = 0;
    if (points.length >= minWeighIns) {
      final xs = points
          .map((w) => w.date.difference(start).inMinutes / (60 * 24))
          .toList();
      spanDays = xs.reduce(max) - xs.reduce(min);
      if (spanDays >= minWeightSpanDays) {
        final n = points.length;
        final meanX = xs.reduce((a, b) => a + b) / n;
        final meanY = points.map((w) => w.kg).reduce((a, b) => a + b) / n;
        var sxy = 0.0, sxx = 0.0;
        for (var i = 0; i < n; i++) {
          sxy += (xs[i] - meanX) * (points[i].kg - meanY);
          sxx += (xs[i] - meanX) * (xs[i] - meanX);
        }
        if (sxx > 0) slopePerDay = sxy / sxx;
      }
    }

    double? avgIntake;
    double? dataTdee;
    var confidence = 0.0;
    if (intakes.length >= minLoggedDays && slopePerDay != null) {
      avgIntake = intakes.reduce((a, b) => a + b) / intakes.length;
      dataTdee = (avgIntake - slopePerDay * kcalPerKg)
          .clamp(formulaTdee * 0.7, formulaTdee * 1.3)
          .toDouble();
      confidence = min(1.0, intakes.length / windowDays) *
          min(1.0, spanDays / (windowDays - 1));
    }

    final blended = dataTdee == null
        ? formulaTdee
        : confidence * dataTdee + (1 - confidence) * formulaTdee;

    return MaintenanceEstimate(
      calories: blended,
      formulaCalories: formulaTdee,
      dataCalories: dataTdee,
      confidence: confidence,
      windowDays: windowDays,
      loggedDays: intakes.length,
      weighIns: points.length,
      avgIntake: avgIntake,
      weightTrendKgPerWeek: slopePerDay == null ? null : slopePerDay * 7,
    );
  }
}

/// One choice of how fast to lose or gain.
class RateOption {
  const RateOption({
    required this.kgPerWeek,
    required this.calories,
    required this.atFloor,
    required this.recommended,
  });

  final double kgPerWeek;
  final double calories;

  /// True when the pace would go below the minimum, so calories were raised.
  final bool atFloor;
  final bool recommended;
}

/// Everything the Goals screen shows.
class GoalPlan {
  const GoalPlan({
    required this.bmr,
    required this.maintenance,
    required this.rateOptions,
    required this.autoCalories,
    required this.autoAtFloor,
    required this.calories,
    required this.caloriesAreCustom,
    required this.calorieFloor,
    required this.split,
    required this.splitIsCustom,
    required this.goals,
  });

  /// Calories burned at complete rest (profile formula).
  final double bmr;
  final MaintenanceEstimate maintenance;

  /// Pace choices for the current goal (empty when maintaining).
  final List<RateOption> rateOptions;

  /// Calories recommended for the chosen goal and pace.
  final double autoCalories;
  final bool autoAtFloor;

  /// Calories actually used (Syd's own number if she set one).
  final double calories;
  final bool caloriesAreCustom;
  final int calorieFloor;

  final MacroSplit split;
  final bool splitIsCustom;

  /// Final daily targets in grams.
  final Nutrients goals;
}

class GoalCalculator {
  GoalCalculator._();

  static double activityFactor(ActivityLevel level) => switch (level) {
        ActivityLevel.sedentary => 1.2,
        ActivityLevel.light => 1.375,
        ActivityLevel.moderate => 1.55,
        ActivityLevel.active => 1.725,
        ActivityLevel.veryActive => 1.9,
      };

  static int calorieFloor(Sex sex) => sex == Sex.female ? 1200 : 1500;

  /// Pace presets in kg/week, picked to be round numbers in each unit system.
  static List<double> ratePresets(Goal goal, Units units) {
    const lb = 0.45359237;
    if (goal == Goal.maintain) return const [];
    if (units == Units.imperial) {
      return goal == Goal.lose
          ? [0.5 * lb, 1 * lb, 1.5 * lb, 2 * lb]
          : [0.25 * lb, 0.5 * lb];
    }
    return goal == Goal.lose ? const [0.25, 0.5, 0.75, 1.0] : const [0.1, 0.25];
  }

  /// Mifflin-St Jeor resting calories.
  static double bmr(UserProfile p) =>
      10 * p.weightKg! +
      6.25 * p.heightCm! -
      5 * p.age! +
      (p.sex == Sex.male ? 5 : -161);

  /// Calories per day for a goal and pace, starting from maintenance.
  /// Returns (calories, raisedToFloor).
  static (double, bool) caloriesFor(
      double maintenance, Goal goal, double kgPerWeek, int floor) {
    final change = kgPerWeek * kcalPerKg / 7;
    final raw = switch (goal) {
      Goal.lose => maintenance - change,
      Goal.maintain => maintenance,
      Goal.gain => maintenance + change,
    };
    final atFloor = raw < floor;
    final kcal = max(raw, floor.toDouble());
    return ((kcal / 10).round() * 10.0, atFloor);
  }

  /// Recommended split at a calorie level: protein by body weight
  /// (1.8 g/kg losing or gaining, 1.6 g/kg maintaining, max 35%), fat 30%,
  /// carbs the rest, fiber 14 g per 1,000 calories.
  static MacroSplit recommendedSplit(UserProfile p, double calories) {
    final perKg = p.goal == Goal.maintain ? 1.6 : 1.8;
    final proteinShare =
        (p.weightKg! * perKg * 4 / calories).clamp(0.10, 0.35).toDouble();
    const fatShare = 0.30;
    return MacroSplit(
      protein: proteinShare,
      fat: fatShare,
      carbs: 1 - proteinShare - fatShare,
      fiberPer1000: 14,
    );
  }

  /// Builds the full plan. Returns null until the profile is complete.
  static GoalPlan? plan(UserProfile p, EnergyHistory history,
      {DateTime? today}) {
    if (!p.isComplete || p.age == null) return null;

    final restCalories = bmr(p);
    final formulaTdee = restCalories * activityFactor(p.activityLevel);
    final maintenance = MaintenanceEstimator.estimate(
      formulaTdee: formulaTdee,
      history: history,
      today: today,
    );
    final floor = calorieFloor(p.sex);

    // Pace options; recommend the one closest to 0.7% of body weight a week
    // for losing (the middle of the usual 0.5–1% guideline), and the gentlest
    // pace for gaining.
    final presets = ratePresets(p.goal, p.units);
    final target = p.goal == Goal.lose
        ? p.weightKg! * 0.007
        : (presets.isEmpty ? 0.0 : presets.first);
    double? recommendedRate;
    for (final r in presets) {
      if (recommendedRate == null ||
          (r - target).abs() < (recommendedRate - target).abs()) {
        recommendedRate = r;
      }
    }
    final options = [
      for (final r in presets)
        () {
          final (kcal, atFloor) =
              caloriesFor(maintenance.calories, p.goal, r, floor);
          return RateOption(
            kgPerWeek: r,
            calories: kcal,
            atFloor: atFloor,
            recommended: r == recommendedRate,
          );
        }(),
    ];

    final (autoCalories, autoAtFloor) =
        caloriesFor(maintenance.calories, p.goal, p.rateKgPerWeek, floor);
    final calories = p.caloriesOverride ?? autoCalories;
    final split = p.macroSplit ?? recommendedSplit(p, calories);

    return GoalPlan(
      bmr: restCalories,
      maintenance: maintenance,
      rateOptions: options,
      autoCalories: autoCalories,
      autoAtFloor: autoAtFloor,
      calories: calories,
      caloriesAreCustom: p.caloriesOverride != null,
      calorieFloor: floor,
      split: split,
      splitIsCustom: p.macroSplit != null,
      goals: split.goalsFor(calories),
    );
  }
}
