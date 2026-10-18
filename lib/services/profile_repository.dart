import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';

/// Keeps the profile on the phone and, when signed in, in the cloud.
///
/// - Signed out: the profile is saved only on the phone.
/// - On sign-in: whichever copy (phone or cloud) was edited most recently wins,
///   so anything set up before signing in gets uploaded.
/// - Signed in: every save goes to both places.
class ProfileRepository extends ChangeNotifier {
  ProfileRepository._();
  static final ProfileRepository instance = ProfileRepository._();

  static const String _prefsKey = 'user_profile';

  UserProfile _profile = UserProfile.empty();
  UserProfile get profile => _profile;

  User? _user;
  User? get user => _user;
  bool get isSignedIn => _user != null;

  StreamSubscription<User?>? _authSub;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw != null) {
      try {
        _profile = UserProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (e) {
        debugPrint('Could not read saved profile: $e');
      }
    }
    _user = FirebaseAuth.instance.currentUser;
    _authSub = FirebaseAuth.instance.authStateChanges().listen(_onAuthChanged);
    notifyListeners();
  }

  Future<void> update(UserProfile updated) async {
    _profile = updated.copyWith(updatedAt: DateTime.now());
    notifyListeners();
    await _saveLocal();
    if (_user != null) {
      try {
        await _saveCloud(_user!.uid);
      } catch (e) {
        debugPrint('Cloud save failed (will retry on next sign-in): $e');
      }
    }
  }

  Future<void> _onAuthChanged(User? user) async {
    _user = user;
    notifyListeners();
    if (user == null) return;

    try {
      final snap = await _doc(user.uid).get();
      final cloudRaw = snap.data()?['profile'];

      if (cloudRaw is Map) {
        final cloud = UserProfile.fromMap(Map<String, dynamic>.from(cloudRaw));
        if (cloud.updatedAt.isAfter(_profile.updatedAt)) {
          _profile = cloud;
          await _saveLocal();
          notifyListeners();
        } else if (_profile.updatedAt.isAfter(cloud.updatedAt)) {
          await _saveCloud(user.uid);
        }
      } else if (_profile.hasBeenEdited) {
        // First sign-in on this account: upload what was set up offline.
        await _saveCloud(user.uid);
      }
    } catch (e) {
      debugPrint('Profile sync failed: $e');
    }
  }

  DocumentReference<Map<String, dynamic>> _doc(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> _saveLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(_profile.toMap()));
  }

  Future<void> _saveCloud(String uid) async {
    await _doc(uid).set(
      {'profile': _profile.toMap()},
      SetOptions(merge: true),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
