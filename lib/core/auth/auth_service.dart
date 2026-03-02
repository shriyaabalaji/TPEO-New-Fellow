import 'package:firebase_auth/firebase_auth.dart' as fb;

class AuthService {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;

  Stream<fb.User?> authStateChanges() => _auth.authStateChanges();

  Future<fb.UserCredential?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<fb.UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reloads the current user from the server (e.g. to refresh emailVerified after they clicked the link).
  /// Returns true if the user is now verified.
  Future<bool> reloadUser() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final updated = _auth.currentUser;
    return updated?.emailVerified ?? false;
  }

  /// Reloads user and forces a fresh ID token so Firestore sees email_verified and email.
  /// Call this before Firestore writes right after email verification.
  Future<void> reloadUserAndRefreshToken() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await user.reload();
    final updated = _auth.currentUser;
    await updated?.getIdToken(true);
  }

  /// Deletes the current user. Requires [password] for reauthentication.
  Future<void> deleteAccount({required String password}) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw Exception('Not signed in');
    final cred = fb.EmailAuthProvider.credential(
      email: user.email!,
      password: password,
    );
    await user.reauthenticateWithCredential(cred);
    await user.delete();
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
