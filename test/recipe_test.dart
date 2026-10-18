import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/models/food.dart';
import 'package:syds_health_fitness/models/nutrients.dart';
import 'package:syds_health_fitness/models/recipe.dart';

FoodItem _food(String id, double kcalPer100, double fatPer100) => FoodItem(
      id: id,
      name: id,
      source: FoodSource.usda,
      per100g: Nutrients(
          calories: kcalPer100, protein: 10, carbs: 20, fat: fatPer100, fiber: 1),
    );

void main() {
  final burger = _food('burger', 257, 15); // 219 g sandwich ≈ 563 kcal
  final cheese = _food('cheese', 371, 30); // 21 g slice ≈ 78 kcal
  final sauce = _food('sauce', 400, 40); // 15 g ≈ 60 kcal

  test('taking cheese out and adding sauce changes the totals', () {
    final r = Recipe.draft(name: 'Big Mac my way', components: [
      RecipeComponent(food: burger, serving: const Serving('1', 219), quantity: 1),
      RecipeComponent(
          food: cheese, serving: const Serving('slice', 21), quantity: 1, remove: true),
      RecipeComponent(food: sauce, serving: const Serving('tbsp', 15), quantity: 1),
    ]);
    final expected = 257 * 2.19 - 371 * 0.21 + 400 * 0.15;
    expect(r.total.calories, closeTo(expected, 0.01));
    expect(r.netGrams, closeTo(219 - 21 + 15, 0.01));

    // Logged as one food, the whole meal gives the same calories.
    final food = r.toFoodItem();
    expect(food.nutrientsFor(food.defaultServing, 1).calories,
        closeTo(expected, 0.5));
  });

  test('removing more than is there never goes negative', () {
    final r = Recipe.draft(name: 'x', components: [
      RecipeComponent(food: cheese, serving: const Serving('slice', 21), quantity: 1),
      RecipeComponent(
          food: cheese, serving: const Serving('slice', 21), quantity: 3, remove: true),
    ]);
    expect(r.total.calories, 0);
    expect(r.total.fat, 0);
  });

  test('recipes split into servings', () {
    final r = Recipe.draft(name: 'Lasagna', components: [
      RecipeComponent(food: burger, serving: Serving.hundredGrams, quantity: 8),
    ]).copyWith(servings: 4);
    expect(r.perServing.calories, closeTo(257 * 8 / 4, 0.01));
    final food = r.toFoodItem();
    expect(food.defaultServing.grams, closeTo(200, 0.01));
  });

  test('saved meals survive saving and loading', () {
    final r = Recipe.draft(name: 'Test', components: [
      RecipeComponent(
          food: cheese, serving: const Serving('slice', 21), quantity: 2, remove: true),
    ]);
    final back = Recipe.fromMap(r.toMap())!;
    expect(back.name, 'Test');
    expect(back.components.single.remove, isTrue);
    expect(back.components.single.quantity, 2);
  });
}
