import '../models/weigh_in.dart';
import '../utils/dates.dart';
import 'energy_history.dart';
import 'profile_repository.dart';
import 'synced_store.dart';

/// Syd's weigh-ins (users/{uid}/weights), one per day.
///
/// Whenever they change, the latest weight is copied into her profile (so
/// the goals use her current weight) and every weigh-in is handed to the
/// maintenance estimate.
class WeightRepository extends SyncedStore<WeighIn> {
  WeightRepository._()
      : super(
          prefsKey: 'weights_v1',
          collection: 'weights',
          fromMap: WeighIn.fromMap,
        ) {
    addListener(_publish);
  }

  static final WeightRepository instance = WeightRepository._();

  @override
  Future<void> init() async {
    await super.init();
    _publish();
  }

  /// Oldest first.
  List<WeighIn> get entries =>
      items..sort((a, b) => a.day.compareTo(b.day));

  WeighIn? get latest {
    final e = entries;
    return e.isEmpty ? null : e.last;
  }

  List<TrendPoint> get trend => weightTrend(entries);

  WeighIn? onDay(DateTime day) => byId(dayKey(day));

  Future<void> log(DateTime day, double kg) => put(WeighIn(
        day: dayOnly(day),
        kg: kg,
        updatedAt: DateTime.now(),
      ));

  Future<void> remove(WeighIn w) => put(WeighIn(
        day: w.day,
        kg: w.kg,
        updatedAt: DateTime.now(),
        deleted: true,
      ));

  /// Change in the trend over the last [days] days (null without data).
  double? trendChange(int days) {
    final t = trend;
    if (t.length < 2) return null;
    final cutoff = t.last.day.subtract(Duration(days: days));
    TrendPoint? start;
    for (final p in t) {
      if (!p.day.isAfter(cutoff)) start = p;
    }
    start ??= t.first;
    if (identical(start, t.last)) return null;
    return t.last.kg - start.kg;
  }

  void _publish() {
    final profile = ProfileRepository.instance;
    final all = entries;
    profile.history = EnergyHistory(
      caloriesByDay: profile.history.caloriesByDay,
      weights: [for (final w in all) WeightEntry(w.day, w.kg)],
    );

    // Keep the profile's "current weight" in step with the newest weigh-in.
    final newest = all.isEmpty ? null : all.last;
    final current = profile.profile.weightKg;
    if (newest != null &&
        (current == null || (current - newest.kg).abs() > 0.01)) {
      profile.update(profile.profile.copyWith(weightKg: newest.kg));
    }
  }
}
