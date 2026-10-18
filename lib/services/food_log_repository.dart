import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food.dart';
import '../models/log_entry.dart';
import '../models/meal.dart';
import '../models/nutrients.dart';
import '../utils/dates.dart';
import 'energy_history.dart';
import 'profile_repository.dart';

/// Every food Syd has logged, on the phone and (when signed in) in the cloud
/// at users/{uid}/foodLog/{entryId}.
///
/// Sync works like the profile: on sign-in each entry's newest copy wins,
/// and anything logged while signed out is uploaded.
class FoodLogRepository extends ChangeNotifier {
  FoodLogRepository._();
  static final FoodLogRepository instance = FoodLogRepository._();

  static const String _prefsKey = 'food_log_v1';

  final Map<String, LogEntry> _all = {};
  String? _uid;
  StreamSubscription<User?>? _authSub;

  Iterable<LogEntry> get _live => _all.values.where((e) => !e.deleted);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        for (final m in jsonDecode(raw) as List) {
          final e = LogEntry.fromMap(Map<String, dynamic>.from(m as Map));
          if (e != null) _all[e.id] = e;
        }
      } catch (e) {
        debugPrint('Could not read saved food log: $e');
      }
    }
    _publishHistory();
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  // ---------------------------------------------------------------- reading

  List<LogEntry> entriesFor(DateTime day, Meal meal) => _live
      .where((e) => e.meal == meal && isSameDay(e.day, day))
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Nutrients totalFor(DateTime day, [Meal? meal]) => _live
      .where((e) => isSameDay(e.day, day) && (meal == null || e.meal == meal))
      .fold(Nutrients.zero, (sum, e) => sum + e.nutrients);

  /// Calories logged per day, for the maintenance estimate.
  Map<DateTime, double> get caloriesByDay {
    final map = <DateTime, double>{};
    for (final e in _live) {
      final d = dayOnly(e.day);
      map[d] = (map[d] ?? 0) + e.nutrients.calories;
    }
    return map;
  }

  /// Most recently logged foods (newest first, no repeats), with the
  /// serving and amount used last time.
  List<LogEntry> recent({int limit = 20}) {
    final sorted = _live.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final seen = <String>{};
    return [
      for (final e in sorted)
        if (seen.add(e.food.id)) e,
    ].take(limit).toList();
  }

  // ---------------------------------------------------------------- writing

  Future<LogEntry> add({
    required FoodItem food,
    required Serving serving,
    required double quantity,
    required Meal meal,
    required DateTime day,
  }) async {
    final now = DateTime.now();
    final entry = LogEntry(
      id: _newId(now),
      day: dayOnly(day),
      meal: meal,
      food: food,
      serving: serving,
      quantity: quantity,
      createdAt: now,
      updatedAt: now,
    );
    await _put(entry);
    return entry;
  }

  Future<void> save(LogEntry entry) =>
      _put(entry.copyWith(updatedAt: DateTime.now()));

  Future<void> delete(LogEntry entry) =>
      _put(entry.copyWith(deleted: true, updatedAt: DateTime.now()));

  Future<void> restore(LogEntry entry) =>
      _put(entry.copyWith(deleted: false, updatedAt: DateTime.now()));

  Future<void> _put(LogEntry entry) async {
    _all[entry.id] = entry;
    notifyListeners();
    _publishHistory();
    await _saveLocal();
    final uid = _uid;
    if (uid != null) {
      try {
        await _collection(uid).doc(entry.id).set(entry.toMap());
      } catch (e) {
        debugPrint('Cloud save failed (will sync on next sign-in): $e');
      }
    }
  }

  // ------------------------------------------------------------------- sync

  Future<void> _onAuthChanged(User? user) async {
    _uid = user?.uid;
    if (user == null) return;
    try {
      final snap = await _collection(user.uid).get();
      final cloud = <String, LogEntry>{};
      for (final doc in snap.docs) {
        final e = LogEntry.fromMap(doc.data());
        if (e != null) cloud[e.id] = e;
      }

      var changedLocally = false;
      cloud.forEach((id, c) {
        final local = _all[id];
        if (local == null || c.updatedAt.isAfter(local.updatedAt)) {
          _all[id] = c;
          changedLocally = true;
        }
      });

      final toUpload = [
        for (final e in _all.values)
          if (cloud[e.id] == null || e.updatedAt.isAfter(cloud[e.id]!.updatedAt))
            e,
      ];
      for (var i = 0; i < toUpload.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final e in toUpload.skip(i).take(400)) {
          batch.set(_collection(user.uid).doc(e.id), e.toMap());
        }
        await batch.commit();
      }

      if (changedLocally) {
        await _saveLocal();
        notifyListeners();
        _publishHistory();
      }
    } catch (e) {
      debugPrint('Food log sync failed: $e');
    }
  }

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('foodLog');

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final e in _all.values) e.toMap()]),
    );
  }

  /// Hands daily calories to the goals so maintenance can learn from them.
  void _publishHistory() {
    final profile = ProfileRepository.instance;
    profile.history = EnergyHistory(
      caloriesByDay: caloriesByDay,
      weights: profile.history.weights,
    );
  }

  static final Random _random = Random();
  static String _newId(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}'
      '${_random.nextInt(1 << 32).toRadixString(36)}';

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
