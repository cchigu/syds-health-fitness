/// An amount of calories and the four tracked macros.
///
/// Used for daily goals, for what's been eaten, and (from Milestone 4)
/// for individual foods.
class Nutrients {
  const Nutrients({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
  });

  static const Nutrients zero =
      Nutrients(calories: 0, protein: 0, carbs: 0, fat: 0, fiber: 0);

  final double calories;

  /// Grams.
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;

  Nutrients operator +(Nutrients o) => Nutrients(
        calories: calories + o.calories,
        protein: protein + o.protein,
        carbs: carbs + o.carbs,
        fat: fat + o.fat,
        fiber: fiber + o.fiber,
      );

  Nutrients operator -(Nutrients o) => Nutrients(
        calories: calories - o.calories,
        protein: protein - o.protein,
        carbs: carbs - o.carbs,
        fat: fat - o.fat,
        fiber: fiber - o.fiber,
      );

  /// Nothing can go below zero (e.g. removing more cheese than there was).
  Nutrients clampedAtZero() => Nutrients(
        calories: calories < 0 ? 0 : calories,
        protein: protein < 0 ? 0 : protein,
        carbs: carbs < 0 ? 0 : carbs,
        fat: fat < 0 ? 0 : fat,
        fiber: fiber < 0 ? 0 : fiber,
      );

  Nutrients scaled(double factor) => Nutrients(
        calories: calories * factor,
        protein: protein * factor,
        carbs: carbs * factor,
        fat: fat * factor,
        fiber: fiber * factor,
      );

  /// Rounds everything to whole numbers, which is how goals are shown.
  Nutrients rounded() => Nutrients(
        calories: calories.roundToDouble(),
        protein: protein.roundToDouble(),
        carbs: carbs.roundToDouble(),
        fat: fat.roundToDouble(),
        fiber: fiber.roundToDouble(),
      );

  Map<String, dynamic> toMap() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
      };

  factory Nutrients.fromMap(Map<String, dynamic> map) {
    double n(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return Nutrients(
      calories: n('calories'),
      protein: n('protein'),
      carbs: n('carbs'),
      fat: n('fat'),
      fiber: n('fiber'),
    );
  }
}
