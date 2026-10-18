import '../services/synced_store.dart';
import '../utils/dates.dart';

/// One weigh-in. There's at most one per day (logging again replaces it).
class WeighIn implements Syncable {
  const WeighIn({
    required this.day,
    required this.kg,
    required this.updatedAt,
    this.deleted = false,
  });

  final DateTime day;
  final double kg;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  @override
  String get id => dayKey(day);

  @override
  Map<String, dynamic> toMap() => {
        'day': dayKey(day),
        'kg': kg,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static WeighIn? fromMap(Map<String, dynamic> m) {
    final day = parseDayKey(m['day'] as String?);
    final kg = (m['kg'] as num?)?.toDouble();
    if (day == null || kg == null) return null;
    return WeighIn(
      day: day,
      kg: kg,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}

/// A point on the smoothed trend line.
class TrendPoint {
  const TrendPoint(this.day, this.kg);
  final DateTime day;
  final double kg;
}

/// Exponentially smoothed trend through the weigh-ins (oldest first).
///
/// Each new weigh-in moves the trend 10% of the way toward it per day since
/// the last one, so daily water swings barely move it while real change
/// shows up within a week or two.
List<TrendPoint> weightTrend(List<WeighIn> sortedOldestFirst,
    {double dailySmoothing = 0.1}) {
  final out = <TrendPoint>[];
  double? trend;
  DateTime? lastDay;
  for (final w in sortedOldestFirst) {
    if (trend == null || lastDay == null) {
      trend = w.kg;
    } else {
      final gap = w.day.difference(lastDay).inDays.clamp(1, 60);
      final keep = _pow(1 - dailySmoothing, gap);
      trend = trend * keep + w.kg * (1 - keep);
    }
    lastDay = w.day;
    out.add(TrendPoint(w.day, trend));
  }
  return out;
}

double _pow(double base, int exp) {
  var r = 1.0;
  for (var i = 0; i < exp; i++) {
    r *= base;
  }
  return r;
}
