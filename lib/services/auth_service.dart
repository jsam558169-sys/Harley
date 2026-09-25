import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import 'collections.dart';

/// Handles login/logout and resolving the logged-in Firebase Auth user
/// to an AppUser with a role (owner/employee), used to gate access levels.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentFirebaseUser => _auth.currentUser;

  Future<AppUser> login(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    return getUserProfile(uid);
  }

  Future<void> logout() => _auth.signOut();

  /// Owner/Admin-only: create a new employee (or owner) account.
  /// In production this should really be done via a Cloud Function using
  /// the Admin SDK so the owner's session isn't disturbed, but for a
  /// functionality-first pass, client-side creation is fine.
  Future<AppUser> registerUser({
    required String email,
    required String password,
    required UserRole role,
    String displayName = '',
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = cred.user!.uid;
    final appUser = AppUser(
      uid: uid,
      email: email,
      role: role,
      displayName: displayName,
    );
    await _db.collection(Collections.users).doc(uid).set(appUser.toMap());
    return appUser;
  }

  Future<AppUser> getUserProfile(String uid) async {
    final doc = await _db.collection(Collections.users).doc(uid).get();
    if (!doc.exists) {
      throw Exception('No user profile found for uid $uid');
    }
    return AppUser.fromMap(uid, doc.data()!);
  }
}
