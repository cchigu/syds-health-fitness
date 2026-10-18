import 'package:flutter_test/flutter_test.dart';

import 'package:syds_health_fitness/models/treadmill_session.dart';
import 'package:syds_health_fitness/models/user_profile.dart';
import 'package:syds_health_fitness/screens/treadmill_log_sheet.dart';

void main() {
  test('calorie estimate is sensible', () {
    // 65 kg walking 3 mph, flat, 30 min: about 110-130 kcal.
    expect(estimateCalories(3, 0, 30, 65), inInclusiveRange(100, 140));
    // Incline makes it noticeably harder.
    expect(estimateCalories(3, 8, 30, 65),
        greaterThan(estimateCalories(3, 0, 30, 65) * 1.5));
    // Jogging 5 mph burns more than walking 3 mph.
    expect(estimateCalories(5, 0, 30, 65),
        greaterThan(estimateCalories(3, 0, 30, 65)));
  });

  test('distance and summaries in both units', () {
    final s = TreadmillSession(
      id: 'x',
      day: DateTime(2026, 10, 18),
      minutes: 30,
      speedMph: 3,
      inclinePct: 6,
      updatedAt: DateTime(2026),
    );
    expect(s.miles, 1.5);
    expect(distanceText(s.miles, Units.imperial), '1.5 mi');
    expect(distanceText(s.miles, Units.metric), '2.41 km');
    expect(treadmillSummary(s, Units.imperial), '30 min · 3 mph · 6% incline');
    expect(TreadmillSession.fromMap(s.toMap())!.inclinePct, 6);
  });
}
