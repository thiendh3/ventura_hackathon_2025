import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdService {
  static const String _deviceIdKey = 'device_id';
  static final DeviceIdService _instance = DeviceIdService._internal();
  factory DeviceIdService() => _instance;
  DeviceIdService._internal();

  String? _cachedDeviceId;

  /// Get or create a unique device ID for this device
  /// This ID will be consistent across app restarts
  Future<String> getDeviceId() async {
    // Return cached ID if available
    if (_cachedDeviceId != null) {
      return _cachedDeviceId!;
    }

    // Try to get existing ID from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final existingId = prefs.getString(_deviceIdKey);

    if (existingId != null && existingId.isNotEmpty) {
      _cachedDeviceId = existingId;
      return existingId;
    }

    // Generate new UUID and save it
    const uuid = Uuid();
    final newDeviceId = uuid.v4();

    // Save to SharedPreferences
    await prefs.setString(_deviceIdKey, newDeviceId);
    _cachedDeviceId = newDeviceId;
    
    return newDeviceId;
  }
}
