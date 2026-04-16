import 'package:flutter/services.dart';

class SamsungHealthService {
  static const MethodChannel _channel =
      MethodChannel('sleepwell/samsung_health');

  static Future<bool> hasSleepPermission() async {
    final result = await _channel.invokeMethod<dynamic>('hasSleepPermission');
    if (result is bool) return result;
    return false;
  }

  static Future<bool> requestSleepPermission() async {
    final result =
        await _channel.invokeMethod<dynamic>('requestSleepPermission');
    if (result is Map) {
      return result['granted'] == true;
    }
    return false;
  }

  static Future<Map<String, dynamic>?> readLatestSleep() async {
    final result = await _channel.invokeMethod<dynamic>('readLatestSleep');
    if (result == null) return null;
    return Map<String, dynamic>.from(result as Map);
  }
}