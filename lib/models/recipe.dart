import 'dart:math';

import '../services/synced_store.dart';
import '../utils/units.dart';
import 'food.dart';
import 'nutrients.dart';

/// One ingredient of a saved meal. [remove] subtracts it instead, which is
/// how "Big Mac, no cheese" works: Big Mac + (remove) 1 slice of cheese.
class RecipeComponent {
  const RecipeComponent({
    required this.food,
    required this.serving,
    required this.quantity,
    this.remove = false,
  });

  final FoodItem food;
  final Serving serving;
  final double quantity;
  final bool remove;

  Nutrients get nutrients => food.nutrientsFor(serving, quantity);
  double get grams => serving.grams * quantity;
  String get amount => amountLabel(serving, quantity);

  RecipeComponent copyWith({
    Serving? serving,
    double? quantity,
    bool? remove,
  }) =>
      RecipeComponent(
        food: food,
        serving: serving ?? this.serving,
        quantity: quantity ?? this.quantity,
        remove: remove ?? this.remove,
      );

  Map<String, dynamic> toMap() => {
        'food': food.toMap(),
        'serving': serving.toMap(),
        'quantity': quantity,
        'remove': remove,
      };

  static RecipeComponent? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    if (m['food'] is! Map || m['serving'] is! Map) return null;
    return RecipeComponent(
      food: FoodItem.fromMap(Map<String, dynamic>.from(m['food'] as Map)),
      serving: Serving.fromMap(Map<String, dynamic>.from(m['serving'] as Map)),
      quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
      remove: m['remove'] == true,
    );
  }
}

/// A saved meal or recipe: a name, ingredients, and how many servings
/// it makes. Logged like any food.
class Recipe implements Syncable {
  const Recipe({
    required this.id,
    required this.name,
    required this.components,
    required this.updatedAt,
    this.servings = 1,
    this.deleted = false,
  });

  @override
  final String id;
  final String name;
  final List<RecipeComponent> components;
  final int servings;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  static Recipe draft({required String name, List<RecipeComponent>? components}) {
    final now = DateTime.now();
    return Recipe(
      id: '${now.microsecondsSinceEpoch.toRadixString(36)}'
          '${Random().nextInt(1 << 30).toRadixString(36)}',
      name: name,
      components: components ?? const [],
      updatedAt: now,
    );
  }

  /// Everything added minus everything removed (never below zero).
  Nutrients get total {
    var sum = Nutrients.zero;
    for (final c in components) {
      sum = c.remove ? sum - c.nutrients : sum + c.nutrients;
    }
    return sum.clampedAtZero();
  }

  /// Weight of the finished meal.
  double get netGrams {
    var g = 0.0;
    for (final c in components) {
      g += c.remove ? -c.grams : c.grams;
    }
    return max(g, 1);
  }

  Nutrients get perServing => total.scaled(1 / max(servings, 1));

  /// The meal as a food that can be logged (per 100 g like every food).
  FoodItem toFoodItem() {
    final grams = netGrams;
    final n = max(servings, 1);
    return FoodItem(
      id: 'recipe:$id',
      name: name,
      source: FoodSource.recipe,
      per100g: total.scaled(100 / grams),
      servings: n > 1
          ? [
              Serving('1 serving (${trimNumber(grams / n)} g)', grams / n),
              Serving('Whole recipe (${trimNumber(grams)} g)', grams),
            ]
          : [Serving('1 meal (${trimNumber(grams)} g)', grams)],
    );
  }

  Recipe copyWith({
    String? name,
    List<RecipeComponent>? components,
    int? servings,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      Recipe(
        id: id,
        name: name ?? this.name,
        components: components ?? this.components,
        servings: servings ?? this.servings,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'components': [for (final c in components) c.toMap()],
        'servings': servings,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static Recipe? fromMap(Map<String, dynamic> m) {
    final id = m['id'] as String?;
    if (id == null) return null;
    return Recipe(
      id: id,
      name: (m['name'] as String?) ?? 'My meal',
      components: [
        for (final c in (m['components'] as List?) ?? const [])
          if (RecipeComponent.fromMap(c) case final rc?) rc,
      ],
      servings: (m['servings'] as num?)?.toInt() ?? 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}

/// A food starred for quick re-logging, with the amount used last time.
class FavoriteFood implements Syncable {
  const FavoriteFood({
    required this.food,
    required this.serving,
    required this.quantity,
    required this.updatedAt,
    this.deleted = false,
  });

  final FoodItem food;
  final Serving serving;
  final double quantity;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  @override
  String get id => food.id;

  @override
  Map<String, dynamic> toMap() => {
        'food': food.toMap(),
        'serving': serving.toMap(),
        'quantity': quantity,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static FavoriteFood? fromMap(Map<String, dynamic> m) {
    if (m['food'] is! Map || m['serving'] is! Map) return null;
    return FavoriteFood(
      food: FoodItem.fromMap(Map<String, dynamic>.from(m['food'] as Map)),
      serving: Serving.fromMap(Map<String, dynamic>.from(m['serving'] as Map)),
      quantity: (m['quantity'] as num?)?.toDouble() ?? 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}
