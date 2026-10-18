import '../models/treadmill_session.dart';
import '../utils/dates.dart';
import 'synced_store.dart';

/// Treadmill sessions she logged (users/{uid}/treadmill).
class TreadmillRepository extends SyncedStore<TreadmillSession> {
  TreadmillRepository._()
      : super(
          prefsKey: 'treadmill_v1',
          collection: 'treadmill',
          fromMap: TreadmillSession.fromMap,
        );
  static final TreadmillRepository instance = TreadmillRepository._();

  List<TreadmillSession> onDay(DateTime day) =>
      items.where((s) => isSameDay(s.day, day)).toList()
        ..sort((a, b) => a.updatedAt.compareTo(b.updatedAt));

  /// Monday–Sunday of the week containing [day].
  List<TreadmillSession> inWeekOf(DateTime day) {
    final monday = dayOnly(day).subtract(Duration(days: day.weekday - 1));
    final next = monday.add(const Duration(days: 7));
    return items
        .where((s) => !s.day.isBefore(monday) && s.day.isBefore(next))
        .toList();
  }

  /// The most recent session (to pre-fill the next one).
  TreadmillSession? get latest {
    final all = items..sort((a, b) => b.day.compareTo(a.day));
    return all.isEmpty ? null : all.first;
  }

  Future<void> save(TreadmillSession s) =>
      put(s.copyWith(updatedAt: DateTime.now()));

  Future<void> delete(TreadmillSession s) =>
      put(s.copyWith(deleted: true, updatedAt: DateTime.now()));

  Future<void> restore(TreadmillSession s) =>
      put(s.copyWith(deleted: false, updatedAt: DateTime.now()));
}
