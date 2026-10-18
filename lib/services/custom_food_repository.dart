import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/food.dart';

/// A food Syd typed in herself, optionally tied to a barcode so the next
/// scan finds it instantly.
class CustomFood {
  const CustomFood({
    required this.food,
    required this.updatedAt,
    this.barcode,
    this.deleted = false,
  });

  final FoodItem food;
  final String? barcode;
  final DateTime updatedAt;
  final bool deleted;

  String get id => food.id;

  Map<String, dynamic> toMap() => {
        'food': food.toMap(),
        'barcode': barcode,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
        'deleted': deleted,
      };

  static CustomFood? fromMap(Map<String, dynamic> m) {
    final raw = m['food'];
    if (raw is! Map) return null;
    return CustomFood(
      food: FoodItem.fromMap(Map<String, dynamic>.from(raw)),
      barcode: m['barcode'] as String?,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
          (m['updatedAt'] as num?)?.toInt() ?? 0),
      deleted: m['deleted'] == true,
    );
  }
}

/// Barcodes can be written with or without leading zeros
/// (UPC-A "049000028911" is EAN-13 "0049000028911").
String normalizeBarcode(String code) =>
    code.replaceAll(RegExp(r'\D'), '').replaceFirst(RegExp(r'^0+'), '');

/// Syd's own foods, on the phone and in the cloud at
/// users/{uid}/customFoods/{id}. Same sync rules as the food log.
class CustomFoodRepository extends ChangeNotifier {
  CustomFoodRepository._();
  static final CustomFoodRepository instance = CustomFoodRepository._();

  static const String _prefsKey = 'custom_foods_v1';

  final Map<String, CustomFood> _all = {};
  String? _uid;
  StreamSubscription<User?>? _authSub;

  Iterable<CustomFood> get _live => _all.values.where((c) => !c.deleted);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        for (final m in jsonDecode(raw) as List) {
          final c = CustomFood.fromMap(Map<String, dynamic>.from(m as Map));
          if (c != null) _all[c.id] = c;
        }
      } catch (e) {
        debugPrint('Could not read custom foods: $e');
      }
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  FoodItem? byBarcode(String code) {
    final wanted = normalizeBarcode(code);
    if (wanted.isEmpty) return null;
    for (final c in _live) {
      if (c.barcode != null && normalizeBarcode(c.barcode!) == wanted) {
        return c.food;
      }
    }
    return null;
  }

  /// Custom foods whose name or brand contains every word of the query.
  List<FoodItem> search(String query) {
    final words = query.toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isEmpty) return const [];
    return [
      for (final c in _live)
        if (words.every((w) =>
            '${c.food.name} ${c.food.brand ?? ''}'.toLowerCase().contains(w)))
          c.food,
    ];
  }

  Future<void> save(FoodItem food, {String? barcode}) => _put(CustomFood(
        food: food,
        barcode: barcode,
        updatedAt: DateTime.now(),
      ));

  Future<void> _put(CustomFood c) async {
    _all[c.id] = c;
    notifyListeners();
    await _saveLocal();
    final uid = _uid;
    if (uid != null) {
      try {
        await _collection(uid).doc(_docId(c.id)).set(c.toMap());
      } catch (e) {
        debugPrint('Cloud save failed (will sync on next sign-in): $e');
      }
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    _uid = user?.uid;
    if (user == null) return;
    try {
      final snap = await _collection(user.uid).get();
      final cloud = <String, CustomFood>{};
      for (final doc in snap.docs) {
        final c = CustomFood.fromMap(doc.data());
        if (c != null) cloud[c.id] = c;
      }
      var changed = false;
      cloud.forEach((id, c) {
        final local = _all[id];
        if (local == null || c.updatedAt.isAfter(local.updatedAt)) {
          _all[id] = c;
          changed = true;
        }
      });
      final batch = FirebaseFirestore.instance.batch();
      var uploads = 0;
      for (final c in _all.values) {
        final remote = cloud[c.id];
        if (remote == null || c.updatedAt.isAfter(remote.updatedAt)) {
          batch.set(_collection(user.uid).doc(_docId(c.id)), c.toMap());
          uploads++;
        }
      }
      if (uploads > 0) await batch.commit();
      if (changed) {
        await _saveLocal();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Custom food sync failed: $e');
    }
  }

  /// Firestore document IDs can't contain "/", so keep them simple.
  static String _docId(String id) => id.replaceAll('/', '_');

  CollectionReference<Map<String, dynamic>> _collection(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('customFoods');

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode([for (final c in _all.values) c.toMap()]),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
