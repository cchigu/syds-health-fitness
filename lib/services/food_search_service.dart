import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../config/api_keys.dart';
import '../models/food.dart';
import '../models/nutrients.dart';
import '../utils/units.dart';
import 'http_helper.dart';

enum SourceStatus { loading, done, failed }

/// How one database is doing for the current search.
class SourceResult {
  const SourceResult.loading()
      : status = SourceStatus.loading,
        foods = const [],
        error = null,
        offline = false;
  const SourceResult.done(this.foods)
      : status = SourceStatus.done,
        error = null,
        offline = false;
  const SourceResult.failed(String this.error, {this.offline = false})
      : status = SourceStatus.failed,
        foods = const [];

  final SourceStatus status;
  final List<FoodItem> foods;

  /// What went wrong, in plain words.
  final String? error;
  final bool offline;
}

class FoodSearchResult {
  const FoodSearchResult({required this.usda, required this.off});

  static const empty = FoodSearchResult(
    usda: SourceResult.done([]),
    off: SourceResult.done([]),
  );

  final SourceResult usda;
  final SourceResult off;

  bool get stillLoading =>
      usda.status == SourceStatus.loading || off.status == SourceStatus.loading;
  bool get bothFailed =>
      usda.status == SourceStatus.failed && off.status == SourceStatus.failed;
  bool get offline => bothFailed && usda.offline && off.offline;

  /// USDA first, then Open Food Facts products sold in the US, then the
  /// rest of the world; near-duplicates removed.
  List<FoodItem> get foods {
    final ordered = [
      ...usda.foods,
      ...off.foods.where((f) => f.fromUs),
      ...off.foods.where((f) => !f.fromUs),
    ];
    final seen = <String>{};
    return [
      for (final f in ordered)
        if (seen.add('${f.name.toLowerCase()}|${(f.brand ?? '').toLowerCase()}'))
          f,
    ];
  }
}

/// Searches USDA FoodData Central and Open Food Facts at the same time.
///
/// Reliability:
/// - Each database is asked separately and its results show up as soon as
///   they arrive, so a slow one never holds up the other.
/// - Every request gets one automatic retry (timeouts, dropped connections,
///   "too many requests", server errors).
/// - Open Food Facts uses its fast new search service, falling back to the
///   classic one if that fails.
/// - Recent searches are remembered, so retyping a word is instant and
///   doesn't use up the databases' limits.
/// - Errors say what actually happened instead of always "no internet".
class FoodSearchService {
  FoodSearchService._();

  static const String _userAgent =
      'SydsHealthFitness/1.0 (github.com/cchigu/syds-health-fitness)';

  static final _usdaCache = _Cache();
  static final _offCache = _Cache();

  /// Emits a new result each time one of the databases answers.
  static Stream<FoodSearchResult> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.length < 2) return Stream.value(FoodSearchResult.empty);

    final controller = StreamController<FoodSearchResult>();
    var usda = _usdaCache[q] != null
        ? SourceResult.done(_usdaCache[q]!)
        : const SourceResult.loading();
    var off = _offCache[q] != null
        ? SourceResult.done(_offCache[q]!)
        : const SourceResult.loading();

    void emit() {
      if (!controller.isClosed) {
        controller.add(FoodSearchResult(usda: usda, off: off));
      }
    }

    emit();
    final pending = <Future<void>>[];

    if (usda.status == SourceStatus.loading) {
      pending.add(_searchUsda(q).then((foods) {
        _usdaCache[q] = foods;
        usda = SourceResult.done(foods);
      }).catchError((Object e) {
        debugPrint('USDA search failed: $e');
        usda = SourceResult.failed(
          ApiKeys.usingDemoUsdaKey && e is HttpStatusError && e.statusCode == 429
              ? 'USDA\'s shared demo key has run out of searches for the hour. '
                  'Add your own free key in secrets.json.'
              : describeError(e, source: 'USDA'),
          offline: looksOffline(e),
        );
      }).whenComplete(emit));
    }

    if (off.status == SourceStatus.loading) {
      pending.add(_searchOff(q).then((foods) {
        _offCache[q] = foods;
        off = SourceResult.done(foods);
      }).catchError((Object e) {
        debugPrint('Open Food Facts search failed: $e');
        off = SourceResult.failed(
          describeError(e, source: 'Open Food Facts'),
          offline: looksOffline(e),
        );
      }).whenComplete(emit));
    }

    Future.wait(pending).whenComplete(controller.close);
    return controller.stream;
  }

  // ------------------------------------------------------------------ USDA

  static Future<List<FoodItem>> _searchUsda(String q) async {
    final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'api_key': ApiKeys.usda,
      'query': q,
      'pageSize': '25',
      'dataType': 'Foundation,SR Legacy,Survey (FNDDS),Branded',
    });
    final res = await getWithRetry(uri, timeout: const Duration(seconds: 10));
    if (res.statusCode != 200) throw HttpStatusError(res.statusCode);
    return parseUsda(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Turns a USDA search response into foods. Values are per 100 g.
  @visibleForTesting
  static List<FoodItem> parseUsda(Map<String, dynamic> json) {
    final foods = <FoodItem>[];
    for (final raw in (json['foods'] as List?) ?? const []) {
      if (raw is! Map) continue;
      final f = Map<String, dynamic>.from(raw);

      final byId = <int, double>{};
      double? kcalFromKj;
      for (final n in (f['foodNutrients'] as List?) ?? const []) {
        if (n is! Map) continue;
        final id = (n['nutrientId'] as num?)?.toInt();
        final value = (n['value'] as num?)?.toDouble();
        final unit = (n['unitName'] as String?)?.toUpperCase() ?? '';
        if (id == null || value == null) continue;
        if (id == 1008 && unit == 'KJ') {
          kcalFromKj = value / 4.184;
        } else if (id == 1062) {
          kcalFromKj ??= value / 4.184;
        } else {
          byId[id] = value;
        }
      }

      // Energy: label calories, else Atwater calories, else from kJ.
      final kcal = byId[1008] ?? byId[2047] ?? byId[2048] ?? kcalFromKj;
      if (kcal == null) continue;

      final servings = <Serving>[];
      final size = (f['servingSize'] as num?)?.toDouble();
      final unit = (f['servingSizeUnit'] as String?)?.toLowerCase() ?? '';
      if (size != null && size > 0 &&
          const ['g', 'grm', 'ml', 'mlt'].contains(unit)) {
        final unitLabel = unit.startsWith('m') ? 'ml' : 'g';
        final household = (f['householdServingFullText'] as String?)?.trim();
        servings.add(Serving(
          (household != null && household.isNotEmpty)
              ? '${_tidy(household)} (${trimNumber(size)} $unitLabel)'
              : '1 serving (${trimNumber(size)} $unitLabel)',
          size,
        ));
      }
      for (final m in ((f['foodMeasures'] as List?) ?? const []).take(5)) {
        if (m is! Map) continue;
        final text = (m['disseminationText'] as String?)?.trim() ?? '';
        final grams = (m['gramWeight'] as num?)?.toDouble();
        if (text.isEmpty ||
            text.toLowerCase() == 'quantity not specified' ||
            grams == null ||
            grams <= 0) {
          continue;
        }
        servings.add(Serving('$text (${trimNumber(grams)} g)', grams));
      }

      final brand = (f['brandName'] as String?) ?? (f['brandOwner'] as String?);
      foods.add(FoodItem(
        id: 'usda:${f['fdcId']}',
        name: _tidy((f['description'] as String?) ?? 'Food'),
        brand: brand == null || brand.trim().isEmpty ? null : _tidy(brand),
        source: FoodSource.usda,
        fromUs: true,
        servings: servings,
        per100g: Nutrients(
          calories: kcal,
          protein: byId[1003] ?? 0,
          fat: byId[1004] ?? 0,
          carbs: byId[1005] ?? 0,
          fiber: byId[1079] ?? 0,
        ),
      ));
    }
    return foods;
  }

  // -------------------------------------------------------- Open Food Facts

  static const _offFields = 'code,product_name,brands,nutriments,'
      'serving_size,serving_quantity,countries_tags';

  /// Fast search first; the classic search if that fails or finds nothing.
  static Future<List<FoodItem>> _searchOff(String q) async {
    Object? firstError;
    try {
      final fast = await _searchOffFast(q);
      if (fast.isNotEmpty) return fast;
    } catch (e) {
      firstError = e;
      debugPrint('Open Food Facts fast search failed, trying classic: $e');
    }
    try {
      return await _searchOffClassic(q);
    } catch (e) {
      throw firstError ?? e;
    }
  }

  static Future<List<FoodItem>> _searchOffFast(String q) async {
    final uri = Uri.https('search.openfoodfacts.org', '/search', {
      'q': q,
      'page_size': '24',
      'fields': _offFields,
    });
    final res = await getWithRetry(
      uri,
      headers: {'User-Agent': _userAgent},
      timeout: const Duration(seconds: 8),
    );
    if (res.statusCode != 200) throw HttpStatusError(res.statusCode);
    return parseOff(jsonDecode(res.body) as Map<String, dynamic>);
  }

  static Future<List<FoodItem>> _searchOffClassic(String q) async {
    final uri = Uri.https('world.openfoodfacts.org', '/cgi/search.pl', {
      'search_terms': q,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page_size': '24',
      'fields': _offFields,
    });
    final res = await getWithRetry(
      uri,
      headers: {'User-Agent': _userAgent},
      timeout: const Duration(seconds: 15),
    );
    if (res.statusCode != 200) throw HttpStatusError(res.statusCode);
    return parseOff(jsonDecode(res.body) as Map<String, dynamic>);
  }

  /// Turns an Open Food Facts search response into foods.
  @visibleForTesting
  static List<FoodItem> parseOff(Map<String, dynamic> json) {
    final foods = <FoodItem>[];
    final list = (json['hits'] as List?) ?? (json['products'] as List?) ?? const [];
    for (final raw in list) {
      if (raw is! Map) continue;
      final p = Map<String, dynamic>.from(raw);
      final product = parseOffProduct(p);
      if (product != null) foods.add(product);
    }
    return foods;
  }

  /// One Open Food Facts product (also used by barcode scanning later).
  static FoodItem? parseOffProduct(Map<String, dynamic> p) {
    final name = '${p['product_name'] ?? ''}'.trim();
    final code = (p['code'] ?? '').toString();
    if (name.isEmpty || code.isEmpty) return null;

    final n = p['nutriments'] is Map
        ? Map<String, dynamic>.from(p['nutriments'] as Map)
        : <String, dynamic>{};
    final kj = _num(n['energy_100g']);
    final kcal = _num(n['energy-kcal_100g']) ?? (kj == null ? null : kj / 4.184);
    if (kcal == null) return null;

    final servings = <Serving>[];
    final qty = _num(p['serving_quantity']);
    final sizeText = (p['serving_size'] as String?)?.trim() ?? '';
    if (qty != null && qty > 0) {
      final label = sizeText.isEmpty
          ? '1 serving (${trimNumber(qty)} g)'
          : (RegExp(r'\d').hasMatch(sizeText)
              ? sizeText
              : '$sizeText (${trimNumber(qty)} g)');
      servings.add(Serving(label, qty));
    }

    final rawBrands = p['brands'];
    final brands = (rawBrands is List
            ? (rawBrands.isEmpty ? null : '${rawBrands.first}')
            : (rawBrands as String?)?.split(',').first)
        ?.trim();
    final countries = (p['countries_tags'] as List?) ?? const [];

    return FoodItem(
      id: 'off:$code',
      name: name,
      brand: brands == null || brands.isEmpty ? null : brands,
      source: FoodSource.openFoodFacts,
      fromUs: countries.contains('en:united-states'),
      servings: servings,
      per100g: Nutrients(
        calories: kcal,
        protein: _num(n['proteins_100g']) ?? 0,
        carbs: _num(n['carbohydrates_100g']) ?? 0,
        fat: _num(n['fat_100g']) ?? 0,
        fiber: _num(n['fiber_100g']) ?? 0,
      ),
    );
  }

  /// Open Food Facts sometimes sends numbers as text.
  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.replaceAll(',', '.'));
    return null;
  }

  /// "McDONALD'S, BIG MAC" -> "McDonald's, Big Mac". Leaves mixed case alone.
  static String _tidy(String s) {
    final t = s.trim();
    final letters = t.replaceAll(RegExp(r'[^A-Za-z]'), '');
    final mostlyUpper = letters.isNotEmpty &&
        letters.replaceAll(RegExp(r'[^A-Z]'), '').length / letters.length > 0.7;
    if (!mostlyUpper) return t;
    return t.toLowerCase().replaceAllMapped(
          RegExp(r"(^|[\s,(/-])([a-z])"),
          (m) => '${m[1]}${m[2]!.toUpperCase()}',
        ).replaceAllMapped(
          RegExp(r"\bMc([a-z])"),
          (m) => 'Mc${m[1]!.toUpperCase()}',
        );
  }
}

/// Remembers the last 60 searches per database.
class _Cache {
  final _map = <String, List<FoodItem>>{};

  List<FoodItem>? operator [](String key) => _map[key];

  void operator []=(String key, List<FoodItem> value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > 60) _map.remove(_map.keys.first);
  }
}
