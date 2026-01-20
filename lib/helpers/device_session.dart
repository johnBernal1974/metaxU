
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceSession {
  static const _kDeviceId = 'device_id';
  static const _uuid = Uuid();

  static Future<String> getOrCreateDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kDeviceId);
    if (existing != null && existing.trim().isNotEmpty) return existing;

    final newId = _uuid.v4(); // id único
    await prefs.setString(_kDeviceId, newId);
    return newId;
  }
}
