import 'package:firebase_auth/firebase_auth.dart';

/// Thin wrapper around Firebase Auth so the screens stay simple.
class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<void> signInWithEmail(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> createAccount(String email, String password) async {
    await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  static Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Opens Google's sign-in page through Firebase (no extra package needed).
  static Future<void> signInWithGoogle() async {
    await _auth.signInWithProvider(GoogleAuthProvider());
  }

  static Future<void> signOut() => _auth.signOut();

  /// Turns Firebase error codes into messages Syd will understand.
  /// Returns null when the user simply cancelled.
  static String? friendlyError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          return 'That email and password don\'t match.';
        case 'invalid-email':
          return 'That email address doesn\'t look right.';
        case 'email-already-in-use':
          return 'There\'s already an account with that email. Try signing in.';
        case 'weak-password':
          return 'Please use a password with at least 6 characters.';
        case 'too-many-requests':
          return 'Too many tries. Please wait a minute and try again.';
        case 'network-request-failed':
          return 'No internet connection. Please check and try again.';
        case 'web-context-canceled':
        case 'canceled':
        case 'web-context-already-presented':
          return null;
      }
      return error.message ?? 'Something went wrong. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}
