import 'dart:async';

import 'package:flutter/material.dart';

import '../config/api_keys.dart';
import '../models/food.dart';
import '../models/meal.dart';
import '../services/food_log_repository.dart';
import '../services/food_search_service.dart';
import 'food_detail_screen.dart';

/// Search the food databases (or pick a recent food) to add to a meal.
/// Pops with true when something was added.
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key, required this.meal, required this.day});

  final Meal meal;
  final DateTime day;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _query = TextEditingController();
  Timer? _debounce;
  int _searchId = 0;

  bool _loading = false;
  FoodSearchResult? _result;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    setState(() {});
    if (value.trim().length < 2) {
      setState(() {
        _result = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 600), _search);
  }

  Future<void> _search() async {
    final id = ++_searchId;
    setState(() => _loading = true);
    final result = await FoodSearchService.search(_query.text);
    if (!mounted || id != _searchId) return; // a newer search started
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  Future<void> _open(FoodItem food, {Serving? serving, double? quantity}) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodDetailScreen.add(
          food: food,
          meal: widget.meal,
          day: widget.day,
          initialServing: serving,
          initialQuantity: quantity,
        ),
      ),
    );
    if (added == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final searching = _query.text.trim().length >= 2;

    return Scaffold(
      appBar: AppBar(title: Text('Add to ${widget.meal.label}')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: true,
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
            Expanded(child: searching ? _results() : _recent()),
          ],
        ),
      ),
    );
  }

  Widget _recent() {
    final recent = FoodLogRepository.instance.recent();
    if (recent.isEmpty) {
      return const _Message(
        icon: Icons.search,
        text: 'Search for a food to get started.\n'
            'Try "banana", "greek yogurt" or "big mac".',
      );
    }
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text('Recent'),
        ),
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

  Widget _results() {
    final r = _result;
    if (r == null) return const SizedBox.shrink();
    if (r.bothFailed) {
      return const _Message(
        icon: Icons.wifi_off,
        text: 'Couldn\'t reach the food databases.\n'
            'Check your internet connection and try again.',
      );
    }
    if (r.foods.isEmpty && !_loading) {
      return const _Message(
        icon: Icons.search_off,
        text: 'No foods found. Try fewer or different words.',
      );
    }
    return ListView(
      children: [
        if (r.usdaError != null)
          _Banner(
            ApiKeys.usingDemoUsdaKey
                ? 'USDA search is busy (shared demo key). Showing Open Food '
                    'Facts results only.'
                : 'USDA search is unavailable right now. Showing Open Food '
                    'Facts results only.',
          ),
        if (r.offError != null)
          const _Banner('Open Food Facts is unavailable right now. '
              'Showing USDA results only.'),
        for (final f in r.foods)
          _FoodTile(food: f, onTap: () => _open(f)),
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
  const _Banner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(message,
          style: TextStyle(color: colors.onSecondaryContainer)),
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
