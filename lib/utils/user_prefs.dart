import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserPrefs {
  static const _keyName = "user_name";
  static const _keyEmail = "user_email";
  static const _keyPhoto = "user_photo";

  /// Save user info (name, email, photo)
  static Future<void> saveUserInfo(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, user.displayName ?? "");
    await prefs.setString(_keyEmail, user.email ?? "");
    await prefs.setString(_keyPhoto, user.photoURL ?? "");
  }

  /// Get last saved user info
  static Future<Map<String, String?>> getLastUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      "name": prefs.getString(_keyName),
      "email": prefs.getString(_keyEmail),
      "photo": prefs.getString(_keyPhoto),
    };
  }

  /// Clear saved user info
  static Future<void> clearUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyName);
    await prefs.remove(_keyEmail);
    await prefs.remove(_keyPhoto);
  }
}
