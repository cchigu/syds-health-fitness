import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_keys.dart';
import '../models/food.dart';
import 'custom_food_repository.dart';
import 'food_search_service.dart';

/// Thrown when neither database could be reached (as opposed to "not found").
class BarcodeLookupException implements Exception {
  const BarcodeLookupException();
}

/// Finds the food for a barcode.
///
/// Order: Syd's own foods first, then USDA's US branded-food labels, then
/// Open Food Facts (worldwide). Both databases are asked at the same time.
class BarcodeLookupService {
  BarcodeLookupService._();

  static final http.Client _client = http.Client();
  static const Duration _timeout = Duration(seconds: 12);
  static const String _userAgent =
      'SydsHealthFitness/1.0 (github.com/cchigu/syds-health-fitness)';

  /// Returns null when the barcode isn't in any database.
  static Future<FoodItem?> lookup(String code) async {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return null;

    final mine = CustomFoodRepository.instance.byBarcode(digits);
    if (mine != null) return mine;

    var failures = 0;
    final results = await Future.wait([
      _usda(digits).catchError((Object e) {
        failures++;
        debugPrint('USDA barcode lookup failed: $e');
        return null;
      }),
      _off(digits).catchError((Object e) {
        failures++;
        debugPrint('Open Food Facts barcode lookup failed: $e');
        return null;
      }),
    ]);

    final found = results[0] ?? results[1];
    if (found == null && failures == 2) throw const BarcodeLookupException();
    return found;
  }

  static Future<FoodItem?> _usda(String digits) async {
    final uri = Uri.https('api.nal.usda.gov', '/fdc/v1/foods/search', {
      'api_key': ApiKeys.usda,
      'query': digits,
      'dataType': 'Branded',
      'pageSize': '10',
    });
    final res = await _client.get(uri).timeout(_timeout);
    if (res.statusCode != 200) throw Exception('USDA ${res.statusCode}');
    return matchUsdaBarcode(
        jsonDecode(res.body) as Map<String, dynamic>, digits);
  }

  /// Picks the USDA result whose UPC matches the scanned barcode.
  @visibleForTesting
  static FoodItem? matchUsdaBarcode(Map<String, dynamic> json, String code) {
    final wanted = normalizeBarcode(code);
    final matches = [
      for (final f in (json['foods'] as List?) ?? const [])
        if (f is Map && normalizeBarcode('${f['gtinUpc'] ?? ''}') == wanted) f,
    ];
    if (matches.isEmpty) return null;
    final foods = FoodSearchService.parseUsda({'foods': matches.take(1).toList()});
    return foods.isEmpty ? null : foods.first;
  }

  static Future<FoodItem?> _off(String digits) async {
    final uri = Uri.https(
      'world.openfoodfacts.org',
      '/api/v2/product/$digits.json',
      {
        'fields': 'code,product_name,brands,nutriments,serving_size,'
            'serving_quantity,countries_tags',
      },
    );
    final res = await _client
        .get(uri, headers: {'User-Agent': _userAgent})
        .timeout(_timeout);
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw Exception('OFF ${res.statusCode}');
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final product = body['product'];
    if (body['status'] != 1 || product is! Map) return null;
    final p = Map<String, dynamic>.from(product);
    p['code'] ??= body['code'] ?? digits;
    return FoodSearchService.parseOffProduct(p);
  }
}
