import 'package:flutter/material.dart';

import '../models/food.dart';
import '../models/meal.dart';
import '../models/nutrients.dart';
import '../models/recipe.dart';
import '../services/saved_meals.dart';
import '../utils/units.dart';
import '../widgets/daily_progress_card.dart';
import 'food_detail_screen.dart';
import 'food_search_screen.dart';

/// Build or edit a saved meal / recipe: add ingredients, take things out
/// (no cheese!), set how many servings it makes.
///
/// When [logTo] is given, there's also a "Save and log" button; the screen
/// pops with true if the meal was logged.
class RecipeEditorScreen extends StatefulWidget {
  const RecipeEditorScreen({
    super.key,
    required this.recipe,
    this.isNew = false,
    this.logTo,
  });

  final Recipe recipe;
  final bool isNew;
  final (Meal, DateTime)? logTo;

  @override
  State<RecipeEditorScreen> createState() => _RecipeEditorScreenState();
}

class _RecipeEditorScreenState extends State<RecipeEditorScreen> {
  late Recipe _recipe = widget.recipe;
  late final TextEditingController _name =
      TextEditingController(text: widget.recipe.name);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _setComponents(List<RecipeComponent> list) =>
      setState(() => _recipe = _recipe.copyWith(components: list));

  Future<void> _addComponent({required bool remove}) async {
    final picked = await Navigator.of(context).push<PickedFood>(
      MaterialPageRoute(
        builder: (_) => FoodSearchScreen.pick(
          title: remove ? 'Take something out' : 'Add an ingredient',
          actionLabel: remove ? 'Take it out' : 'Add to meal',
        ),
      ),
    );
    if (picked == null) return;
    _setComponents([
      ..._recipe.components,
      RecipeComponent(
        food: picked.food,
        serving: picked.serving,
        quantity: picked.quantity,
        remove: remove,
      ),
    ]);
  }

  Future<void> _editComponent(int index) async {
    final c = _recipe.components[index];
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(c.food.name,
                  style: Theme.of(ctx).textTheme.titleMedium),
              subtitle: Text(c.amount),
            ),
            ListTile(
              leading: const Icon(Icons.scale_outlined),
              title: const Text('Change amount'),
              onTap: () => Navigator.pop(ctx, 'amount'),
            ),
            ListTile(
              leading: Icon(c.remove ? Icons.add_circle_outline
                  : Icons.remove_circle_outline),
              title: Text(c.remove ? 'Add it instead of taking it out'
                  : 'Take it out instead of adding it'),
              onTap: () => Navigator.pop(ctx, 'flip'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete from this meal'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    final list = [..._recipe.components];
    switch (action) {
      case 'amount':
        final picked = await Navigator.of(context).push<PickedFood>(
          MaterialPageRoute(
            builder: (_) => FoodDetailScreen.pick(
              food: c.food,
              pickLabel: 'Update',
              initialServing: c.serving,
              initialQuantity: c.quantity,
            ),
          ),
        );
        if (picked == null) return;
        list[index] =
            c.copyWith(serving: picked.serving, quantity: picked.quantity);
      case 'flip':
        list[index] = c.copyWith(remove: !c.remove);
      case 'delete':
        list.removeAt(index);
    }
    _setComponents(list);
  }

  Future<void> _save({required bool andLog}) async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _snack('Please give this meal a name.');
      return;
    }
    if (!_recipe.components.any((c) => !c.remove)) {
      _snack('Add at least one ingredient first.');
      return;
    }
    final saved = _recipe.copyWith(name: name);
    await RecipeRepository.instance.save(saved);
    if (!mounted) return;

    final target = widget.logTo;
    if (andLog && target != null) {
      final logged = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => FoodDetailScreen.add(
            food: saved.toFoodItem(),
            meal: target.$1,
            day: target.$2,
            initialQuantity: 1,
          ),
        ),
      );
      if (mounted) Navigator.of(context).pop(logged == true);
      return;
    }
    _snack('Saved to My meals');
    Navigator.of(context).pop(false);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this meal?'),
        content: const Text(
            'Days you already logged it on keep their numbers.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await RecipeRepository.instance.delete(_recipe);
    if (mounted) Navigator.of(context).pop(false);
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final perServing = _recipe.perServing;
    final target = widget.logTo;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isNew ? 'New meal' : 'Edit meal'),
        actions: [
          if (!widget.isNew)
            IconButton(
              tooltip: 'Delete meal',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Meal name',
                hintText: 'e.g. Big Mac, no cheese',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Servings
            Row(
              children: [
                Text('Makes', style: text.bodyLarge),
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _recipe.servings <= 1
                      ? null
                      : () => setState(() => _recipe =
                          _recipe.copyWith(servings: _recipe.servings - 1)),
                ),
                Text('${_recipe.servings}', style: text.titleLarge),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () => setState(() => _recipe =
                      _recipe.copyWith(servings: _recipe.servings + 1)),
                ),
                Text(_recipe.servings == 1 ? 'serving' : 'servings',
                    style: text.bodyLarge),
              ],
            ),

            _NutritionSummary(
              n: perServing,
              caption: _recipe.servings > 1 ? 'per serving' : 'whole meal',
            ),
            const SizedBox(height: 16),

            Text('Ingredients', style: text.titleMedium),
            const SizedBox(height: 4),
            if (_recipe.components.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No ingredients yet.', style: text.bodyMedium),
              ),
            for (var i = 0; i < _recipe.components.length; i++)
              _ComponentTile(
                c: _recipe.components[i],
                onTap: () => _editComponent(i),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _addComponent(remove: false),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _addComponent(remove: true),
                    icon: const Icon(Icons.remove),
                    label: const Text('Take out'),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Take out subtracts something that\'s already in a food, '
                'like the cheese in a burger.',
                style: text.bodySmall?.copyWith(color: colors.outline),
              ),
            ),
            const SizedBox(height: 24),

            if (target != null) ...[
              FilledButton(
                onPressed: () => _save(andLog: true),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('Save and log to ${target.$1.label}'),
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => _save(andLog: false),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Save to My meals only'),
                ),
              ),
            ] else
              FilledButton(
                onPressed: () => _save(andLog: false),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Save meal'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.c, required this.onTap});

  final RecipeComponent c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final kcal = c.nutrients.calories.round();
    final color = c.remove ? colors.error : colors.primary;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(c.remove ? Icons.remove : Icons.add,
              size: 18, color: color),
        ),
        title: Text(c.food.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(c.remove ? 'Taken out · ${c.amount}' : c.amount,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text(
          c.remove ? '−$kcal' : '+$kcal',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _NutritionSummary extends StatelessWidget {
  const _NutritionSummary({required this.n, required this.caption});

  final Nutrients n;
  final String caption;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    Widget macro(String label, double g, Color color) => Expanded(
          child: Column(
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(height: 4),
              Text('${trimNumber(g)} g', style: text.titleSmall),
              Text(label, style: text.bodySmall),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('${n.calories.round()} cal',
                style: text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
            Text(caption, style: text.bodySmall),
            const SizedBox(height: 12),
            Row(
              children: [
                macro('Protein', n.protein, MacroColors.protein),
                macro('Carbs', n.carbs, MacroColors.carbs),
                macro('Fat', n.fat, MacroColors.fat),
                macro('Fiber', n.fiber, MacroColors.fiber),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
