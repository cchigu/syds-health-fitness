import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/services/barcode_lookup_service.dart';
import 'package:syds_health_fitness/services/custom_food_repository.dart';

void main() {
  test('UPC-A and EAN-13 versions of a barcode match', () {
    expect(normalizeBarcode('049000028911'),
        normalizeBarcode('0049000028911'));
    expect(normalizeBarcode('0 49000 02891 1'), '49000028911');
  });

  test('picks the USDA result whose UPC matches the scan', () {
    final food = BarcodeLookupService.matchUsdaBarcode({
      'foods': [
        {
          'fdcId': 1,
          'gtinUpc': '000000000001',
          'description': 'WRONG ONE',
          'foodNutrients': [
            {'nutrientId': 1008, 'unitName': 'KCAL', 'value': 1},
          ],
        },
        {
          'fdcId': 2,
          'gtinUpc': '049000028911',
          'description': 'COCA-COLA',
          'foodNutrients': [
            {'nutrientId': 1008, 'unitName': 'KCAL', 'value': 42},
          ],
        },
      ],
    }, '0049000028911');
    expect(food?.id, 'usda:2');
    expect(food?.per100g.calories, 42);
  });

  test('no match returns null', () {
    expect(
      BarcodeLookupService.matchUsdaBarcode({'foods': []}, '123'),
      isNull,
    );
  });
}
