import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Something that can be saved on the phone and synced to the cloud.
abstract class Syncable {
  String get id;
  DateTime get updatedAt;
  bool get deleted;
  Map<String, dynamic> toMap();
}

/// A list of items kept on the phone and, when signed in, in
/// users/{uid}/{collection}. Same rules as the food log: the newest copy of
/// each item wins on sign-in, and deletes are kept (hidden) so they sync.
class SyncedStore<T extends Syncable> extends ChangeNotifier {
  SyncedStore({
    required this.prefsKey,
    required this.collection,
    required this.fromMap,
  });

  final String prefsKey;
  final String collection;
  final T? Function(Map<String, dynamic>) fromMap;

  final Map<String, T> _all = {};
  String? _uid;
  StreamSubscription<User?>? _authSub;

  /// Items that haven't been deleted, newest first.
  List<T> get items => _all.values.where((e) => !e.deleted).toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  T? byId(String id) {
    final item = _all[id];
    return (item == null || item.deleted) ? null : item;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(prefsKey);
    if (raw != null) {
      try {
        for (final m in jsonDecode(raw) as List) {
          final item = fromMap(Map<String, dynamic>.from(m as Map));
          if (item != null) _all[item.id] = item;
        }
      } catch (e) {
        debugPrint('Could not read $prefsKey: $e');
      }
    }
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
  }

  Future<void> put(T item) async {
    _all[item.id] = item;
    notifyListeners();
    await _saveLocal();
    final uid = _uid;
    if (uid != null) {
      try {
        await _col(uid).doc(_docId(item.id)).set(item.toMap());
      } catch (e) {
        debugPrint('Cloud save to $collection failed: $e');
      }
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    _uid = user?.uid;
    if (user == null) return;
    try {
      final snap = await _col(user.uid).get();
      final cloud = <String, T>{};
      for (final doc in snap.docs) {
        final item = fromMap(doc.data());
        if (item != null) cloud[item.id] = item;
      }

      var changed = false;
      cloud.forEach((id, c) {
        final local = _all[id];
        if (local == null || c.updatedAt.isAfter(local.updatedAt)) {
          _all[id] = c;
          changed = true;
        }
      });

      final toUpload = [
        for (final item in _all.values)
          if (cloud[item.id] == null ||
              item.updatedAt.isAfter(cloud[item.id]!.updatedAt))
            item,
      ];
      for (var i = 0; i < toUpload.length; i += 400) {
        final batch = FirebaseFirestore.instance.batch();
        for (final item in toUpload.skip(i).take(400)) {
          batch.set(_col(user.uid).doc(_docId(item.id)), item.toMap());
        }
        await batch.commit();
      }

      if (changed) {
        await _saveLocal();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Sync of $collection failed: $e');
    }
  }

  static String _docId(String id) => id.replaceAll('/', '_');

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection(collection);

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      prefsKey,
      jsonEncode([for (final item in _all.values) item.toMap()]),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
