import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  // 🔹 Save user info
  static Future<void> saveUserInfo(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('name', user.displayName ?? '');
    await prefs.setString('email', user.email ?? '');
    await prefs.setString('photo', user.photoURL ?? '');
  }

  // 🔹 Save login provider (email or google)
  static Future<void> setProvider(String provider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('provider', provider);
  }

  // 🔹 Load last user info
  static Future<Map<String, String?>> getLastUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "name": prefs.getString('name'),
      "email": prefs.getString('email'),
      "photo": prefs.getString('photo'),
      "provider": prefs.getString('provider'),
    };
  }

  // 🔹 Clear all user data (e.g. on logout)
  static Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('name');
    await prefs.remove('email');
    await prefs.remove('photo');
    await prefs.remove('provider');
  }
}
