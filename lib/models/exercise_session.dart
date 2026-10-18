import '../services/synced_store.dart';
import '../utils/dates.dart';

/// One set she actually did.
class ExerciseSet {
  const ExerciseSet({this.weightLb, this.reps, this.seconds});

  /// Dumbbell weight (null = bodyweight).
  final double? weightLb;
  final int? reps;

  /// For timed exercises like planks.
  final int? seconds;

  Map<String, dynamic> toMap() =>
      {'weightLb': weightLb, 'reps': reps, 'seconds': seconds};

  static ExerciseSet fromMap(Map<String, dynamic> m) => ExerciseSet(
        weightLb: (m['weightLb'] as num?)?.toDouble(),
        reps: (m['reps'] as num?)?.toInt(),
        seconds: (m['seconds'] as num?)?.toInt(),
      );
}

/// Everything she did for one exercise on one day.
class ExerciseSession implements Syncable {
  const ExerciseSession({
    required this.day,
    required this.exerciseId,
    required this.sets,
    required this.updatedAt,
    this.deleted = false,
  });

  final DateTime day;
  final String exerciseId;
  final List<ExerciseSet> sets;
  @override
  final DateTime updatedAt;
  @override
  final bool deleted;

  static String idFor(DateTime day, String exerciseId) =>
      '${dayKey(day)}_$exerciseId';

  @override
  String get id => idFor(day, exerciseId);

  /// Heaviest weight used (null if all bodyweight).
  double? get topWeight {
    double? top;
    for (final s in sets) {
      final w = s.weightLb;
      if (w != null && (top == null || w > top)) top = w;
    }
    return top;
  }

  int? get maxReps {
    int? best;
    for (final s in sets) {
      final r = s.reps;
      if (r != null && (best == null || r > best)) best = r;
    }
    return best;
  }

  int? get maxSeconds {
    int? best;
    for (final s in sets) {
      final x = s.seconds;
      if (x != null && (best == null || x > best)) best = x;
    }
    return best;
  }

  int get totalReps => sets.fold(0, (t, s) => t + (s.reps ?? 0));
  int get totalSeconds => sets.fold(0, (t, s) => t + (s.seconds ?? 0));

  /// Total weight moved (weight × reps, summed).
  double get volume =>
      sets.fold(0.0, (t, s) => t + (s.weightLb ?? 0) * (s.reps ?? 0));

  /// Which of two sessions was better: heaviest weight first, then total
  /// weight moved, then total reps, then total time held.
  static int compare(ExerciseSession a, ExerciseSession b) {
    var c = (a.topWeight ?? 0).compareTo(b.topWeight ?? 0);
    if (c != 0) return c;
    c = a.volume.compareTo(b.volume);
    if (c != 0) return c;
    c = a.totalReps.compareTo(b.totalReps);
    if (c != 0) return c;
    return a.totalSeconds.compareTo(b.totalSeconds);
  }

  @override
  Map<String, dynamic> toMap() => {
        'day': dayKey(day),
        'exerciseId': exerciseId,
        'sets': [for (final s in sets) s.toMap()],
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static ExerciseSession? fromMap(Map<String, dynamic> m) {
    final day = parseDayKey(m['day'] as String?);
    final id = m['exerciseId'] as String?;
    if (day == null || id == null) return null;
    return ExerciseSession(
      day: day,
      exerciseId: id,
      sets: [
        for (final s in (m['sets'] as List?) ?? const [])
          if (s is Map) ExerciseSet.fromMap(Map<String, dynamic>.from(s)),
      ],
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}
