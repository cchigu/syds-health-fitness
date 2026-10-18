import 'package:flutter/material.dart';

import '../models/food.dart';
import '../models/log_entry.dart';
import '../models/meal.dart';
import '../models/recipe.dart';
import '../services/food_log_repository.dart';
import '../services/saved_meals.dart';
import '../utils/dates.dart';
import '../utils/units.dart';
import '../widgets/daily_progress_card.dart';
import 'recipe_editor_screen.dart';

/// Pick serving, amount and meal for a food, then add it to the log.
/// Also used to edit (or delete) an entry that's already logged, and to
/// choose an amount for a meal ingredient ([FoodDetailScreen.pick]).
class FoodDetailScreen extends StatefulWidget {
  const FoodDetailScreen.add({
    super.key,
    required FoodItem this.food,
    required Meal this.meal,
    required DateTime this.day,
    this.initialServing,
    this.initialQuantity,
  })  : entry = null,
        pickLabel = null;

  /// Choose serving and amount only; pops with a [PickedFood].
  const FoodDetailScreen.pick({
    super.key,
    required FoodItem this.food,
    required String this.pickLabel,
    this.initialServing,
    this.initialQuantity,
  })  : entry = null,
        meal = null,
        day = null;

  const FoodDetailScreen.edit({super.key, required LogEntry this.entry})
      : food = null,
        meal = null,
        day = null,
        initialServing = null,
        initialQuantity = null,
        pickLabel = null;

  final FoodItem? food;
  final Meal? meal;
  final DateTime? day;
  final Serving? initialServing;
  final double? initialQuantity;
  final LogEntry? entry;
  final String? pickLabel;

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late final FoodItem _food;
  late Serving _serving;
  late Meal _meal;
  late DateTime _day;
  final _quantity = TextEditingController();

  bool get _editing => widget.entry != null;
  bool get _picking => widget.pickLabel != null;

  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    _food = e?.food ?? widget.food!;
    _meal = e?.meal ?? widget.meal ?? Meal.snacks;
    _day = e?.day ?? widget.day ?? DateTime.now();

    final wanted = e?.serving ?? widget.initialServing;
    _serving = (wanted != null && _food.servings.contains(wanted))
        ? wanted
        : (wanted ?? _food.defaultServing);
    final q = e?.quantity ??
        widget.initialQuantity ??
        (_serving.isGram ? 100 : 1);
    _quantity.text = trimNumber(q, decimals: 2);
  }

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  double? get _qty {
    final v = double.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    return (v == null || v <= 0) ? null : v;
  }

  void _changeServing(Serving s) {
    if (s == _serving) return;
    // Keep the same total grams when switching to/from plain grams.
    final grams = (_qty ?? 1) * _serving.grams;
    setState(() {
      if (s.isGram) {
        _quantity.text = trimNumber(grams);
      } else if (_serving.isGram) {
        _quantity.text = trimNumber(grams / s.grams, decimals: 2);
      } else {
        _quantity.text = '1';
      }
      _serving = s;
    });
  }

  Future<void> _pickServing() async {
    final picked = await showModalBottomSheet<Serving>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in [
              ..._food.servings,
              if (!_food.servings.contains(_serving)) _serving,
            ])
              ListTile(
                title: Text(s.isGram ? 'Grams' : s.label),
                trailing: s == _serving ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (picked != null) _changeServing(picked);
  }

  Future<void> _save() async {
    final q = _qty;
    if (q == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount.')),
      );
      return;
    }
    if (_picking) {
      Navigator.of(context).pop(PickedFood(_food, _serving, q));
      return;
    }
    final repo = FoodLogRepository.instance;
    if (_editing) {
      await repo.save(widget.entry!.copyWith(
        serving: _serving,
        quantity: q,
        meal: _meal,
      ));
    } else {
      await repo.add(
        food: _food,
        serving: _serving,
        quantity: q,
        meal: _meal,
        day: _day,
      );
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleFavorite() async {
    final nowFavorite = await FavoritesRepository.instance
        .toggle(_food, _serving, _qty ?? 1);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(nowFavorite ? 'Added to favorites' : 'Removed from favorites'),
    ));
  }

  /// Turn this food into a meal she can add to or take things out of
  /// (e.g. a burger with no cheese and extra sauce).
  Future<void> _customize() async {
    final existing = RecipeRepository.instance.forFood(_food);
    final recipe = existing ??
        Recipe.draft(
          name: '${_food.name} (my way)',
          components: [
            RecipeComponent(
              food: _food,
              serving: _serving,
              quantity: _qty ?? 1,
            ),
          ],
        );
    final logged = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => RecipeEditorScreen(
        recipe: recipe,
        isNew: existing == null,
        logTo: (_meal, _day),
      ),
    ));
    if (logged == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    await FoodLogRepository.instance.delete(widget.entry!);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;
    final n = _food.nutrientsFor(_serving, _qty ?? 0);

    Widget macro(String label, double grams, Color color) => Expanded(
          child: Column(
            children: [
              Icon(Icons.circle, size: 10, color: color),
              const SizedBox(height: 4),
              Text('${trimNumber(grams)} g', style: text.titleMedium),
              Text(label, style: text.bodySmall),
            ],
          ),
        );

    return Scaffold(
      appBar: AppBar(
        title: Text(_picking
            ? 'Ingredient'
            : (_editing ? 'Edit food' : 'Add food')),
        actions: [
          if (!_picking)
            ListenableBuilder(
              listenable: FavoritesRepository.instance,
              builder: (context, _) {
                final fav = FavoritesRepository.instance.isFavorite(_food.id);
                return IconButton(
                  tooltip: fav ? 'Remove from favorites' : 'Add to favorites',
                  icon: Icon(fav ? Icons.star : Icons.star_border),
                  color: fav ? Colors.amber : null,
                  onPressed: _toggleFavorite,
                );
              },
            ),
          if (_editing)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(_food.name, style: text.headlineSmall),
            const SizedBox(height: 4),
            Text(
              [
                if (_food.brand != null) _food.brand!,
                _food.source.label,
              ].join('  ·  '),
              style: text.bodyMedium?.copyWith(color: colors.outline),
            ),
            const SizedBox(height: 20),

            // Amount and serving
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _serving.isGram ? 'Grams' : 'Amount',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _pickServing,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                      alignment: Alignment.centerLeft,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _serving.isGram ? 'grams' : _serving.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.expand_more),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Nutrition preview
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text('${n.calories.round()}',
                        style: text.displaySmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    Text('calories', style: text.bodyMedium),
                    const SizedBox(height: 16),
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
            ),
            const SizedBox(height: 20),

            if (!_picking) ...[
            // Meal
            Text('Meal', style: text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in Meal.values)
                  ChoiceChip(
                    avatar: Icon(m.icon, size: 18),
                    label: Text(m.label),
                    selected: m == _meal,
                    onSelected: (_) => setState(() => _meal = m),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(friendlyDay(_day), style: text.bodySmall),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(_picking
                    ? widget.pickLabel!
                    : (_editing ? 'Save changes' : 'Add to ${_meal.label}')),
              ),
            ),
            if (!_picking && !_editing) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _customize,
                icon: const Icon(Icons.tune),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_food.source == FoodSource.recipe
                      ? 'Edit this meal'
                      : 'Customize (add or remove ingredients)'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
