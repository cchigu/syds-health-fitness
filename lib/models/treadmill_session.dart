import 'dart:math';

import '../services/synced_store.dart';
import '../utils/dates.dart';

/// A treadmill session she logged herself (any day).
class TreadmillSession implements Syncable {
  const TreadmillSession({
    required this.id,
    required this.day,
    required this.minutes,
    required this.speedMph,
    required this.inclinePct,
    required this.updatedAt,
    this.note = '',
    this.deleted = false,
  });

  @override
  final String id;
  final DateTime day;
  final double minutes;

  /// Average speed (stored in mph; shown in km/h for metric).
  final double speedMph;

  /// Average incline, percent.
  final double inclinePct;
  final String note;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  static String newId() =>
      '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
      '${Random().nextInt(1 << 20).toRadixString(36)}';

  double get miles => speedMph * minutes / 60;

  /// Above about 3.8 mph most people jog rather than walk.
  bool get isRunning => speedMph >= 3.8;

  /// Estimated calories burned (ACSM walking/running equations).
  double caloriesFor(double weightKg) =>
      estimateCalories(speedMph, inclinePct, minutes, weightKg);

  TreadmillSession copyWith({
    DateTime? day,
    double? minutes,
    double? speedMph,
    double? inclinePct,
    String? note,
    DateTime? updatedAt,
    bool? deleted,
  }) =>
      TreadmillSession(
        id: id,
        day: day ?? this.day,
        minutes: minutes ?? this.minutes,
        speedMph: speedMph ?? this.speedMph,
        inclinePct: inclinePct ?? this.inclinePct,
        note: note ?? this.note,
        updatedAt: updatedAt ?? this.updatedAt,
        deleted: deleted ?? this.deleted,
      );

  @override
  Map<String, dynamic> toMap() => {
        'id': id,
        'day': dayKey(day),
        'minutes': minutes,
        'speedMph': speedMph,
        'inclinePct': inclinePct,
        'note': note,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static TreadmillSession? fromMap(Map<String, dynamic> m) {
    final day = parseDayKey(m['day'] as String?);
    final id = m['id'] as String?;
    if (day == null || id == null) return null;
    double n(String k) => (m[k] as num?)?.toDouble() ?? 0;
    return TreadmillSession(
      id: id,
      day: day,
      minutes: n('minutes'),
      speedMph: n('speedMph'),
      inclinePct: n('inclinePct'),
      note: (m['note'] as String?) ?? '',
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}

/// ACSM metabolic equations (oxygen cost of walking / running on a
/// treadmill), turned into calories: about 5 kcal per litre of oxygen.
double estimateCalories(
    double speedMph, double inclinePct, double minutes, double weightKg) {
  if (speedMph <= 0 || minutes <= 0 || weightKg <= 0) return 0;
  final metersPerMin = speedMph * 26.8224;
  final grade = inclinePct / 100;
  final vo2 = speedMph >= 3.8
      ? 0.2 * metersPerMin + 0.9 * metersPerMin * grade + 3.5
      : 0.1 * metersPerMin + 1.8 * metersPerMin * grade + 3.5;
  return vo2 * weightKg / 1000 * 5 * minutes;
}
