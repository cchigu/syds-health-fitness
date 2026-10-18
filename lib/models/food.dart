import '../utils/units.dart';
import 'nutrients.dart';

enum FoodSource { usda, openFoodFacts, custom }

extension FoodSourceLabel on FoodSource {
  String get label => switch (this) {
        FoodSource.usda => 'USDA',
        FoodSource.openFoodFacts => 'Open Food Facts',
        FoodSource.custom => 'My food',
      };
}

/// A way of measuring a food, e.g. "1 sandwich (219 g)" or "100 g".
class Serving {
  const Serving(this.label, this.grams);

  final String label;
  final double grams;

  /// Lets the amount be typed directly in grams.
  static const Serving gram = Serving('g', 1);
  static const Serving hundredGrams = Serving('100 g', 100);

  bool get isGram => label == 'g' && grams == 1;

  Map<String, dynamic> toMap() => {'label': label, 'grams': grams};

  static Serving fromMap(Map<String, dynamic> m) => Serving(
        (m['label'] as String?) ?? 'g',
        (m['grams'] as num?)?.toDouble() ?? 1,
      );

  @override
  bool operator ==(Object other) =>
      other is Serving && other.label == label && other.grams == grams;

  @override
  int get hashCode => Object.hash(label, grams);
}

/// A food from a database (or typed in), with nutrition per 100 g.
class FoodItem {
  FoodItem({
    required this.id,
    required this.name,
    required this.source,
    required this.per100g,
    this.brand,
    List<Serving> servings = const [],
    this.fromUs = false,
  }) : servings = _withStandard(servings);

  /// e.g. "usda:2345678" or "off:0049000028911".
  final String id;
  final String name;
  final String? brand;
  final FoodSource source;
  final Nutrients per100g;

  /// The food's own servings first, then "100 g" and plain grams.
  final List<Serving> servings;

  /// Sold in / sourced from the US (used to rank search results).
  final bool fromUs;

  Serving get defaultServing => servings.first;

  Nutrients nutrientsFor(Serving serving, double quantity) =>
      per100g.scaled(serving.grams * quantity / 100);

  static List<Serving> _withStandard(List<Serving> own) {
    final list = <Serving>[];
    for (final s in own) {
      if (s.grams > 0 && !list.contains(s) && !s.isGram) list.add(s);
    }
    if (!list.contains(Serving.hundredGrams)) list.add(Serving.hundredGrams);
    list.add(Serving.gram);
    return list;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'brand': brand,
        'source': source.name,
        'per100g': per100g.toMap(),
        'servings': [for (final s in servings) s.toMap()],
        'fromUs': fromUs,
      };

  static FoodItem fromMap(Map<String, dynamic> m) => FoodItem(
        id: (m['id'] as String?) ?? '',
        name: (m['name'] as String?) ?? 'Food',
        brand: m['brand'] as String?,
        source: FoodSource.values.firstWhere(
          (s) => s.name == m['source'],
          orElse: () => FoodSource.custom,
        ),
        per100g: Nutrients.fromMap(
            Map<String, dynamic>.from((m['per100g'] as Map?) ?? const {})),
        servings: [
          for (final s in (m['servings'] as List?) ?? const [])
            if (s is Map) Serving.fromMap(Map<String, dynamic>.from(s)),
        ],
        fromUs: m['fromUs'] == true,
      );
}

/// "1.5 × 1 sandwich (219 g)", "1 sandwich (219 g)" or "150 g".
String amountLabel(Serving serving, double quantity) {
  if (serving.isGram) return '${trimNumber(quantity)} g';
  if (quantity == 1) return serving.label;
  return '${trimNumber(quantity, decimals: 2)} × ${serving.label}';
}
