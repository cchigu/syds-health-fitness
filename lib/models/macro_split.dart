import 'nutrients.dart';

enum Macro { protein, carbs, fat }

extension MacroInfo on Macro {
  String get label => switch (this) {
        Macro.protein => 'Protein',
        Macro.carbs => 'Carbs',
        Macro.fat => 'Fat',
      };

  /// Calories in one gram.
  double get kcalPerGram => this == Macro.fat ? 9 : 4;
}

/// How daily calories are divided between protein, carbs and fat
/// (as fractions that always add up to 1), plus a fiber target that
/// scales with calories.
///
/// Because the split is stored as shares of calories, everything stays
/// connected: changing calories rescales every macro, and raising one macro
/// takes the room from the other two.
class MacroSplit {
  const MacroSplit({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiberPer1000,
  });

  final double protein;
  final double carbs;
  final double fat;

  /// Grams of fiber per 1,000 calories.
  final double fiberPer1000;

  static const double minShare = 0.05;
  static const double maxShare = 0.80;

  double share(Macro m) => switch (m) {
        Macro.protein => protein,
        Macro.carbs => carbs,
        Macro.fat => fat,
      };

  /// Grams of each macro for a given calorie total.
  Nutrients goalsFor(double calories) => Nutrients(
        calories: calories,
        protein: calories * protein / 4,
        carbs: calories * carbs / 4,
        fat: calories * fat / 9,
        fiber: calories / 1000 * fiberPer1000,
      ).rounded();

  /// Set one macro's share; the other two shrink or grow to fill the rest,
  /// keeping their ratio to each other.
  MacroSplit withShare(Macro changed, double newShare) {
    final s = newShare.clamp(minShare, maxShare).toDouble();
    final others = Macro.values.where((m) => m != changed).toList();
    final a = share(others[0]);
    final b = share(others[1]);
    final rest = 1 - s;

    var na = (a + b) <= 0 ? rest / 2 : rest * a / (a + b);
    var nb = rest - na;
    if (na < minShare) {
      na = minShare;
      nb = rest - minShare;
    } else if (nb < minShare) {
      nb = minShare;
      na = rest - minShare;
    }

    final values = {changed: s, others[0]: na, others[1]: nb};
    return MacroSplit(
      protein: values[Macro.protein]!,
      carbs: values[Macro.carbs]!,
      fat: values[Macro.fat]!,
      fiberPer1000: fiberPer1000,
    );
  }

  /// Set one macro by grams at the given calories.
  MacroSplit withGrams(Macro m, double grams, double calories) =>
      calories <= 0 ? this : withShare(m, grams * m.kcalPerGram / calories);

  MacroSplit withFiberGrams(double grams, double calories) => MacroSplit(
        protein: protein,
        carbs: carbs,
        fat: fat,
        fiberPer1000: calories <= 0 ? fiberPer1000 : grams / calories * 1000,
      );

  Map<String, dynamic> toMap() => {
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiberPer1000': fiberPer1000,
      };

  static MacroSplit? fromMap(Object? raw) {
    if (raw is! Map) return null;
    double? n(String k) => (raw[k] as num?)?.toDouble();
    final p = n('protein'), c = n('carbs'), f = n('fat');
    if (p == null || c == null || f == null) return null;
    final total = p + c + f;
    if (total <= 0) return null;
    return MacroSplit(
      protein: p / total,
      carbs: c / total,
      fat: f / total,
      fiberPer1000: n('fiberPer1000') ?? 14,
    );
  }
}
