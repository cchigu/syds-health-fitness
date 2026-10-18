import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/models/food.dart';
import 'package:syds_health_fitness/models/log_entry.dart';
import 'package:syds_health_fitness/models/meal.dart';
import 'package:syds_health_fitness/models/nutrients.dart';
import 'package:syds_health_fitness/services/food_search_service.dart';
import 'package:syds_health_fitness/services/http_helper.dart';

void main() {
  test('parses a USDA branded food with its serving', () {
    final foods = FoodSearchService.parseUsda({
      'foods': [
        {
          'fdcId': 123,
          'description': "McDONALD'S, BIG MAC",
          'dataType': 'Branded',
          'brandOwner': "McDONALD'S",
          'servingSize': 219,
          'servingSizeUnit': 'g',
          'householdServingFullText': '1 sandwich',
          'foodNutrients': [
            {'nutrientId': 1008, 'unitName': 'KCAL', 'value': 257},
            {'nutrientId': 1003, 'unitName': 'G', 'value': 11.8},
            {'nutrientId': 1004, 'unitName': 'G', 'value': 15.0},
            {'nutrientId': 1005, 'unitName': 'G', 'value': 20.1},
            {'nutrientId': 1079, 'unitName': 'G', 'value': 1.6},
          ],
        },
        {'fdcId': 9, 'description': 'NO ENERGY', 'foodNutrients': []},
      ],
    });

    expect(foods, hasLength(1)); // the one with no calories is skipped
    final f = foods.single;
    expect(f.name, "McDonald's, Big Mac");
    expect(f.fromUs, isTrue);
    expect(f.defaultServing.label, '1 sandwich (219 g)');
    expect(f.nutrientsFor(f.defaultServing, 1).calories, closeTo(563, 1));
    // Standard servings are always offered too.
    expect(f.servings, contains(Serving.hundredGrams));
    expect(f.servings.last.isGram, isTrue);
  });

  test('parses Open Food Facts, including numbers sent as text', () {
    final foods = FoodSearchService.parseOff({
      'products': [
        {
          'code': '0049000028911',
          'product_name': 'Greek Yogurt',
          'brands': 'Chobani, Other',
          'serving_size': '150 g',
          'serving_quantity': '150',
          'countries_tags': ['en:united-states'],
          'nutriments': {
            'energy-kcal_100g': 59,
            'proteins_100g': '10.3',
            'carbohydrates_100g': 3.6,
            'fat_100g': 0.4,
          },
        },
        {
          'code': '1',
          'product_name': 'Only kJ',
          'nutriments': {'energy_100g': 418.4},
        },
      ],
    });

    expect(foods, hasLength(2));
    expect(foods[0].brand, 'Chobani');
    expect(foods[0].fromUs, isTrue);
    expect(foods[0].per100g.protein, 10.3);
    expect(foods[0].defaultServing.grams, 150);
    expect(foods[1].per100g.calories, closeTo(100, 0.01));
    expect(foods[1].fromUs, isFalse);
  });

  test('amount labels read naturally', () {
    const s = Serving('1 sandwich (219 g)', 219);
    expect(amountLabel(s, 1), '1 sandwich (219 g)');
    expect(amountLabel(s, 1.5), '1.5 × 1 sandwich (219 g)');
    expect(amountLabel(Serving.gram, 150), '150 g');
  });

  test('log entries survive saving and loading', () {
    final food = FoodItem(
      id: 'usda:1',
      name: 'Banana',
      source: FoodSource.usda,
      per100g: const Nutrients(
          calories: 89, protein: 1.1, carbs: 22.8, fat: 0.3, fiber: 2.6),
      servings: const [Serving('1 medium (118 g)', 118)],
    );
    final e = LogEntry(
      id: 'abc',
      day: DateTime(2026, 10, 18),
      meal: Meal.breakfast,
      food: food,
      serving: food.defaultServing,
      quantity: 2,
      createdAt: DateTime(2026, 10, 18, 8),
      updatedAt: DateTime(2026, 10, 18, 8),
    );
    final back = LogEntry.fromMap(e.toMap())!;
    expect(back.day, DateTime(2026, 10, 18));
    expect(back.meal, Meal.breakfast);
    expect(back.nutrients.calories, closeTo(89 * 2.36, 0.01));
  });

  test('reads the fast Open Food Facts search (hits, brand lists)', () {
    final foods = FoodSearchService.parseOff({
      'hits': [
        {
          'code': '123',
          'product_name': 'Oat Milk',
          'brands': ['Oatly'],
          'countries_tags': ['en:united-states'],
          'nutriments': {'energy-kcal_100g': 48},
        },
      ],
    });
    expect(foods.single.brand, 'Oatly');
    expect(foods.single.fromUs, isTrue);
  });

  test('errors explain what actually happened', () {
    expect(describeError(TimeoutException('x'), source: 'USDA'),
        contains('slow'));
    expect(describeError(const HttpStatusError(429), source: 'USDA'),
        contains('limiting'));
    expect(
        describeError(const SocketException('Failed host lookup: x'),
            source: 'USDA'),
        'No internet connection.');
  });

  test('results show US sources first and drop duplicates', () {
    FoodItem f(String id, String name, {bool us = false}) => FoodItem(
          id: id,
          name: name,
          source: FoodSource.openFoodFacts,
          fromUs: us,
          per100g: Nutrients.zero,
        );
    final r = FoodSearchResult(
      usda: SourceResult.done([f('u', 'Apple', us: true)]),
      off: SourceResult.done([
        f('o1', 'Apfel'),
        f('o2', 'Apple Pie', us: true),
        f('o3', 'apple'),
      ]),
    );
    expect(r.foods.map((x) => x.id), ['u', 'o2', 'o1']);
  });
}
