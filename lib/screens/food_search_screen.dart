import 'dart:async';

import 'package:flutter/material.dart';

import '../models/food.dart';
import '../models/meal.dart';
import '../models/recipe.dart';
import '../services/custom_food_repository.dart';
import '../services/food_log_repository.dart';
import '../services/food_search_service.dart';
import '../services/saved_meals.dart';
import 'barcode_scan_screen.dart';
import 'custom_food_screen.dart';
import 'food_detail_screen.dart';
import 'recipe_editor_screen.dart';

enum _Tab { recent, favorites, meals }

/// Search the food databases, or pick from recent foods, favorites and
/// saved meals.
///
/// Normal mode adds to a meal and pops with true when something was added.
/// Pick mode ([FoodSearchScreen.pick]) chooses an ingredient for a saved
/// meal and pops with a [PickedFood].
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key, required Meal this.meal, required DateTime this.day})
      : pickTitle = null,
        pickAction = null;

  const FoodSearchScreen.pick({
    super.key,
    required String title,
    required String actionLabel,
  })  : meal = null,
        day = null,
        pickTitle = title,
        pickAction = actionLabel;

  final Meal? meal;
  final DateTime? day;
  final String? pickTitle;
  final String? pickAction;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  int _searchId = 0;

  bool _loading = false;
  FoodSearchResult? _result;
  StreamSubscription<FoodSearchResult>? _sub;
  _Tab _tab = _Tab.recent;

  bool get _picking => widget.pickAction != null;

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    if (value.trim().length < 2) {
      _sub?.cancel();
      setState(() {
        _result = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 700), _search);
  }

  /// Results arrive per database, so whichever answers first shows first.
  void _search() {
    final id = ++_searchId;
    _sub?.cancel();
    setState(() => _loading = true);
    _sub = FoodSearchService.search(_query.text).listen(
      (result) {
        if (!mounted || id != _searchId) return; // a newer search started
        setState(() {
          _result = result;
          _loading = result.stillLoading;
        });
      },
      onDone: () {
        if (mounted && id == _searchId) setState(() => _loading = false);
      },
    );
  }

  /// Open a food: to log it (normal) or to choose an amount (pick mode).
  Future<void> _open(FoodItem food, {Serving? serving, double? quantity}) async {
    if (_picking) {
      final picked = await Navigator.of(context).push<PickedFood>(
        MaterialPageRoute(
          builder: (_) => FoodDetailScreen.pick(
            food: food,
            pickLabel: widget.pickAction!,
            initialServing: serving,
            initialQuantity: quantity,
          ),
        ),
      );
      if (picked != null && mounted) Navigator.of(context).pop(picked);
      return;
    }
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen.add(
          food: food,
          meal: widget.meal!,
          day: widget.day!,
          initialServing: serving,
          initialQuantity: quantity,
        ),
      ),
    );
    if (added == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _openScreen(Widget screen) async {
    final added = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => screen));
    if (added == true && mounted) Navigator.of(context).pop(true);
  }

  void _scan() => _openScreen(
      BarcodeScanScreen(meal: widget.meal!, day: widget.day!));

  void _create() => _openScreen(
      CustomFoodScreen(meal: widget.meal!, day: widget.day!));

  Future<void> _newMeal() => _editMeal(Recipe.draft(name: ''), isNew: true);

  Future<void> _editMeal(Recipe r, {bool isNew = false}) => _openScreen(
        RecipeEditorScreen(
          recipe: r,
          isNew: isNew,
          logTo: _picking ? null : (widget.meal!, widget.day!),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final searching = _query.text.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pickTitle ?? 'Add to ${widget.meal!.label}'),
        actions: [
          if (!_picking) ...[
            IconButton(
              tooltip: 'Scan barcode',
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: _scan,
            ),
            IconButton(
              tooltip: 'Add a food from its label',
              icon: const Icon(Icons.edit_note),
              onPressed: _create,
            ),
          ],
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: !_picking,
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (_) {
                  _debounce?.cancel();
                  if (searching) _search();
                },
                decoration: InputDecoration(
                  hintText: 'Search foods, brands, restaurants…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _query.clear();
                            _onChanged('');
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
            if (_loading) const LinearProgressIndicator(),
            if (!searching) _tabs(),
            Expanded(
              child: ListenableBuilder(
                listenable: Listenable.merge([
                  FavoritesRepository.instance,
                  RecipeRepository.instance,
                ]),
                builder: (context, _) => searching
                    ? _results()
                    : switch (_tab) {
                        _Tab.recent => _recent(),
                        _Tab.favorites => _favorites(),
                        _Tab.meals => _meals(),
                      },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabs() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: Wrap(
          spacing: 8,
          children: [
            for (final (tab, label, icon) in const [
              (_Tab.recent, 'Recent', Icons.history),
              (_Tab.favorites, 'Favorites', Icons.star_border),
              (_Tab.meals, 'My meals', Icons.restaurant_menu),
            ])
              ChoiceChip(
                avatar: Icon(icon, size: 18),
                label: Text(label),
                selected: _tab == tab,
                onSelected: (_) => setState(() => _tab = tab),
              ),
          ],
        ),
      );

  Widget _recent() {
    final recent = FoodLogRepository.instance.recent();
    if (recent.isEmpty) {
      return ListView(
        children: [
          const _Message(
            icon: Icons.search,
            text: 'Search for a food to get started.\n'
                'Try "banana", "greek yogurt" or "big mac".',
          ),
          if (!_picking)
            Center(
              child: FilledButton.tonalIcon(
                onPressed: _scan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan a barcode'),
              ),
            ),
        ],
      );
    }
    return ListView(
      children: [
        for (final e in recent)
          _FoodTile(
            food: e.food,
            serving: e.serving,
            quantity: e.quantity,
            onTap: () =>
                _open(e.food, serving: e.serving, quantity: e.quantity),
          ),
      ],
    );
  }

  Widget _favorites() {
    final favs = FavoritesRepository.instance.items;
    if (favs.isEmpty) {
      return const _Message(
        icon: Icons.star_border,
        text: 'No favorites yet.\n'
            'Tap the ☆ on any food to keep it here for quick logging.',
      );
    }
    return ListView(
      children: [
        for (final f in favs)
          _FoodTile(
            food: f.food,
            serving: f.serving,
            quantity: f.quantity,
            onTap: () =>
                _open(f.food, serving: f.serving, quantity: f.quantity),
          ),
      ],
    );
  }

  Widget _meals() {
    final meals = RecipeRepository.instance.items;
    final text = Theme.of(context).textTheme;
    return ListView(
      children: [
        if (!_picking)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: FilledButton.tonalIcon(
              onPressed: _newMeal,
              icon: const Icon(Icons.add),
              label: const Text('New meal or recipe'),
            ),
          ),
        if (meals.isEmpty)
          const _Message(
            icon: Icons.restaurant_menu,
            text: 'No saved meals yet.\n'
                'Build one here, tap "Customize" on any food (no cheese!), '
                'or save a whole meal from the Today tab.',
          ),
        for (final r in meals)
          ListTile(
            onTap: () => _open(r.toFoodItem()),
            leading: const Icon(Icons.restaurant_menu),
            title: Text(r.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              '${r.components.length} '
              '${r.components.length == 1 ? 'ingredient' : 'ingredients'}'
              '${r.servings > 1 ? ' · ${r.servings} servings' : ''}',
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${r.perServing.calories.round()} cal',
                    style: text.titleSmall),
                if (!_picking)
                  IconButton(
                    tooltip: 'Edit meal',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _editMeal(r),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _results() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();
    final q = _query.text;
    final words = q.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    final mine = [
      ...RecipeRepository.instance.items
          .where((m) => words.every((w) => m.name.toLowerCase().contains(w)))
          .map((m) => m.toFoodItem()),
      ...CustomFoodRepository.instance.search(q),
    ];
    final foods = [...mine, ...r.foods];

    if (r.bothFailed && mine.isEmpty) {
      return ListView(
        children: [
          _Message(
            icon: r.offline ? Icons.wifi_off : Icons.cloud_off,
            text: r.offline
                ? 'No internet connection.\nCheck your Wi-Fi or data and '
                    'try again.'
                : '${r.usda.error}\n${r.off.error}',
          ),
          Center(
            child: FilledButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ),
          if (!_picking) _CantFind(onCreate: _create),
        ],
      );
    }

    if (foods.isEmpty && !r.stillLoading) {
      return ListView(
        children: [
          const _Message(
            icon: Icons.search_off,
            text: 'No foods found. Try fewer or different words.',
          ),
          if (!_picking) _CantFind(onCreate: _create),
        ],
      );
    }

    return ListView(
      children: [
        for (final (src, label) in [(r.usda, 'USDA'), (r.off, 'Open Food Facts')])
          if (src.status == SourceStatus.failed)
            _Banner(
              '${src.error} Showing the other database\'s results.',
              actionLabel: 'Retry',
              onAction: _search,
            )
          else if (src.status == SourceStatus.loading && foods.isNotEmpty)
            _Banner('Still searching $label…'),
        for (final f in foods) _FoodTile(food: f, onTap: () => _open(f)),
        if (!_picking && !r.stillLoading) _CantFind(onCreate: _create),
      ],
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.food,
    required this.onTap,
    this.serving,
    this.quantity,
  });

  final FoodItem food;
  final Serving? serving;
  final double? quantity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = serving ?? food.defaultServing;
    final q = quantity ?? (s.isGram ? 100 : 1);
    final kcal = food.nutrientsFor(s, q).calories.round();
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return ListTile(
      onTap: onTap,
      title: Text(food.name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        [
          if (food.brand != null) food.brand!,
          amountLabel(s, q),
        ].join('  ·  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('$kcal cal', style: text.titleSmall),
          Text(
            food.source.label,
            style: text.labelSmall?.copyWith(color: colors.outline),
          ),
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner(this.message, {this.actionLabel, this.onAction});
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(message,
                style: TextStyle(color: colors.onSecondaryContainer)),
          ),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: colors.outline),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CantFind extends StatelessWidget {
  const _CantFind({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: OutlinedButton.icon(
          onPressed: onCreate,
          icon: const Icon(Icons.edit_note),
          label: const Text("Can't find it? Add it from the label"),
        ),
      );
}
