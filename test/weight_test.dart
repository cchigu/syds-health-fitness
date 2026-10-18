import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/models/weigh_in.dart';

WeighIn _w(int day, double kg) =>
    WeighIn(day: DateTime(2026, 10, day), kg: kg, updatedAt: DateTime(2026));

void main() {
  test('trend smooths out a one-day water spike', () {
    final trend = weightTrend([
      _w(1, 65), _w(2, 65), _w(3, 66.5), // salty dinner
      _w(4, 65), _w(5, 65),
    ]);
    // A 1.5 kg spike moves the trend only ~0.15 kg.
    expect(trend[2].kg, closeTo(65.15, 0.01));
    expect(trend.last.kg, lessThan(65.15));
  });

  test('trend follows real, steady change', () {
    final days = [for (var d = 1; d <= 28; d++) _w(d, 65 - 0.05 * d)];
    final trend = weightTrend(days);
    // Real loss of 1.35 kg over 4 weeks shows up in the trend.
    expect(trend.first.kg - trend.last.kg, greaterThan(0.8));
  });

  test('gaps between weigh-ins count as more days of smoothing', () {
    final trend = weightTrend([_w(1, 65), _w(11, 64)]);
    // 10 days apart: 1 - 0.9^10 ≈ 65% of the way to the new weight.
    expect(trend.last.kg, closeTo(65 - 0.651, 0.01));
  });

  test('weigh-ins survive saving and loading, one per day', () {
    final w = _w(18, 64.2);
    final back = WeighIn.fromMap(w.toMap())!;
    expect(back.kg, 64.2);
    expect(back.id, '2026-10-18');
  });
}
