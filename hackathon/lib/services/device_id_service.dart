import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  String? _cachedDeviceId;

  Future<String> getDeviceId() async {
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    final prefs = await SharedPreferences.getInstance();
    final existingId = prefs.getString(_deviceIdKey);

    if (existingId != null && existingId.isNotEmpty) {
      _cachedDeviceId = existingId;
      return existingId;
    }

    const uuid = Uuid();
    final newDeviceId = uuid.v4();

    await prefs.setString(_deviceIdKey, newDeviceId);
    _cachedDeviceId = newDeviceId;
    
    return newDeviceId;
  }
}
