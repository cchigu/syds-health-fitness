import 'dart:math';

import 'package:flutter/material.dart';

import '../models/food.dart';
import '../models/meal.dart';
import '../models/nutrients.dart';
import '../services/custom_food_repository.dart';
import '../utils/units.dart';
import '../widgets/daily_progress_card.dart';
import 'food_detail_screen.dart';

/// Type a food in from its nutrition label. Saved to Syd's own foods (tied
/// to the barcode if there is one), then opened to log.
/// Pops with true when it was logged.
class CustomFoodScreen extends StatefulWidget {
  const CustomFoodScreen({
    super.key,
    required this.meal,
    required this.day,
    this.barcode,
  });

  final Meal meal;
  final DateTime day;
  final String? barcode;

  @override
  State<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends State<CustomFoodScreen> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _servingName = TextEditingController(text: '1 serving');
  final _servingGrams = TextEditingController();
  final _calories = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  final _fiber = TextEditingController();

  @override
  void dispose() {
    for (final c in [
      _name, _brand, _servingName, _servingGrams,
      _calories, _protein, _carbs, _fat, _fiber,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final name = _name.text.trim();
    final kcal = _num(_calories);
    if (name.isEmpty || kcal == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please enter at least a name and calories.'),
      ));
      return;
    }

    // Labels give nutrition per serving; store it per 100 g like every other
    // food. With no serving weight, treat one serving as 100 g.
    final gramsTyped = _num(_servingGrams);
    final grams = (gramsTyped == null || gramsTyped <= 0) ? 100.0 : gramsTyped;
    final perServing = Nutrients(
      calories: kcal,
      protein: _num(_protein) ?? 0,
      carbs: _num(_carbs) ?? 0,
      fat: _num(_fat) ?? 0,
      fiber: _num(_fiber) ?? 0,
    );
    final servingName =
        _servingName.text.trim().isEmpty ? '1 serving' : _servingName.text.trim();
    final serving = Serving(
      gramsTyped == null ? servingName : '$servingName (${trimNumber(grams)} g)',
      grams,
    );

    final barcode = widget.barcode;
    final id = barcode != null && barcode.isNotEmpty
        ? 'custom:${normalizeBarcode(barcode)}'
        : 'custom:${DateTime.now().microsecondsSinceEpoch}${Random().nextInt(9999)}';
    final brand = _brand.text.trim();

    final food = FoodItem(
      id: id,
      name: name,
      brand: brand.isEmpty ? null : brand,
      source: FoodSource.custom,
      per100g: perServing.scaled(100 / grams),
      servings: [serving],
    );
    await CustomFoodRepository.instance.save(food, barcode: barcode);
    if (!mounted) return;

    final added = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => FoodDetailScreen.add(
        food: food,
        meal: widget.meal,
        day: widget.day,
        initialServing: serving,
        initialQuantity: 1,
      ),
    ));
    if (mounted) Navigator.of(context).pop(added == true);
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? suffix,
    bool number = false,
    Color? dot,
    TextCapitalization caps = TextCapitalization.none,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          textCapitalization: caps,
          keyboardType: number
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            border: const OutlineInputBorder(),
            prefixIcon:
                dot == null ? null : Icon(Icons.circle, size: 12, color: dot),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Add a food')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.barcode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Barcode ${widget.barcode}',
                    style: text.bodySmall),
              ),
            _field(_name, 'Name', caps: TextCapitalization.sentences),
            _field(_brand, 'Brand (optional)', caps: TextCapitalization.words),
            const SizedBox(height: 4),
            Text('Serving size (from the label)', style: text.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _field(_servingName, 'Serving',
                      caps: TextCapitalization.sentences),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: _field(_servingGrams, 'Weight',
                      suffix: 'g', number: true),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Nutrition per serving', style: text.titleSmall),
            const SizedBox(height: 8),
            _field(_calories, 'Calories', suffix: 'kcal', number: true),
            _field(_protein, 'Protein',
                suffix: 'g', number: true, dot: MacroColors.protein),
            _field(_carbs, 'Total carbs',
                suffix: 'g', number: true, dot: MacroColors.carbs),
            _field(_fat, 'Total fat',
                suffix: 'g', number: true, dot: MacroColors.fat),
            _field(_fiber, 'Fiber',
                suffix: 'g', number: true, dot: MacroColors.fiber),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _save,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Save and log it'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
