import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/user_prefs.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// AuthService isolates all login/signup logic away from the UI.
/// Screens will call these methods instead of talking to Firebase directly.
class AuthService {
  static final _auth = FirebaseAuth.instance;
  static final _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);

  // ────────────────────────────────────────────────
  //  LOGIN WITH EMAIL & PASSWORD
  // ────────────────────────────────────────────────
  static Future<UserCredential> login({
    required String email,
    required String password,
    bool rememberMe = true,
  }) async {
    // Remember credentials
    final prefs = await SharedPreferences.getInstance();
    if (rememberMe) {
      await prefs.setString('email', email);
      await prefs.setString('password', password);
    } else {
      await prefs.remove('email');
      await prefs.remove('password');
    }

    // Set persistence (Web only)
    if (kIsWeb) {
      await _auth.setPersistence(
        rememberMe ? Persistence.LOCAL : Persistence.SESSION,
      );
    }

    // Login
    final cred = await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    await UserPrefs.saveUserInfo(cred.user!);
    await UserPrefs.setProvider("email");
    return cred;
  }

  // ────────────────────────────────────────────────
  //  SIGNUP (EMAIL & PASSWORD)
  // ────────────────────────────────────────────────
  static Future<UserCredential> signup({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await UserPrefs.saveUserInfo(cred.user!);
    await UserPrefs.setProvider("email");
    return cred;
  }

  // ────────────────────────────────────────────────
  //  LOGIN WITH GOOGLE
  // ────────────────────────────────────────────────
  static Future<UserCredential> signInWithGoogle({
    bool rememberMe = true,
  }) async {
    if (kIsWeb) {
      if (rememberMe) {
        await _auth.setPersistence(Persistence.LOCAL);
      } else {
        await _auth.setPersistence(Persistence.SESSION);
      }

      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..addScope('profile');
      final cred = await _auth.signInWithPopup(provider);
      await UserPrefs.saveUserInfo(cred.user!);
      await UserPrefs.setProvider("google");
      return cred;
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) throw Exception("Google login cancelled.");

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final cred = await _auth.signInWithCredential(credential);
      await UserPrefs.saveUserInfo(cred.user!);
      await UserPrefs.setProvider("google");
      return cred;
    }
  }

  // ────────────────────────────────────────────────
  //  LOGOUT
  // ────────────────────────────────────────────────
  static Future<void> logout() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  static User? get currentUser => _auth.currentUser;
}
