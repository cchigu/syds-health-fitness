import '../models/food.dart';
import '../models/recipe.dart';
import 'synced_store.dart';

/// Starred foods (users/{uid}/favorites).
class FavoritesRepository extends SyncedStore<FavoriteFood> {
  FavoritesRepository._()
      : super(
          prefsKey: 'favorites_v1',
          collection: 'favorites',
          fromMap: FavoriteFood.fromMap,
        );
  static final FavoritesRepository instance = FavoritesRepository._();

  bool isFavorite(String foodId) => byId(foodId) != null;

  /// Star or unstar. Returns true if it's now a favorite.
  Future<bool> toggle(FoodItem food, Serving serving, double quantity) async {
    final existing = byId(food.id);
    await put(FavoriteFood(
      food: food,
      serving: serving,
      quantity: quantity,
      updatedAt: DateTime.now(),
      deleted: existing != null,
    ));
    return existing == null;
  }
}

/// Saved meals and recipes (users/{uid}/recipes).
class RecipeRepository extends SyncedStore<Recipe> {
  RecipeRepository._()
      : super(
          prefsKey: 'recipes_v1',
          collection: 'recipes',
          fromMap: Recipe.fromMap,
        );
  static final RecipeRepository instance = RecipeRepository._();

  /// The saved meal behind a logged "recipe:..." food, if it still exists.
  Recipe? forFood(FoodItem food) => food.id.startsWith('recipe:')
      ? byId(food.id.substring('recipe:'.length))
      : null;

  Future<void> save(Recipe r) => put(r.copyWith(updatedAt: DateTime.now()));

  Future<void> delete(Recipe r) =>
      put(r.copyWith(deleted: true, updatedAt: DateTime.now()));
}
