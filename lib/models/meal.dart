import 'package:flutter/material.dart';

enum Meal { breakfast, lunch, dinner, snacks }

extension MealInfo on Meal {
  String get label => switch (this) {
        Meal.breakfast => 'Breakfast',
        Meal.lunch => 'Lunch',
        Meal.dinner => 'Dinner',
        Meal.snacks => 'Snacks',
      };

  IconData get icon => switch (this) {
        Meal.breakfast => Icons.free_breakfast_outlined,
        Meal.lunch => Icons.lunch_dining_outlined,
        Meal.dinner => Icons.dinner_dining_outlined,
        Meal.snacks => Icons.cookie_outlined,
      };

  /// A sensible meal for the current time of day.
  static Meal forTime(DateTime t) {
    if (t.hour < 11) return Meal.breakfast;
    if (t.hour < 15) return Meal.lunch;
    if (t.hour < 21) return Meal.dinner;
    return Meal.snacks;
  }
}
