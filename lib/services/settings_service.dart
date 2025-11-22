import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Service voor het beheren van gebruikersinstellingen
class SettingsService {
  static const String _userNameKey = 'user_display_name';

  static String? _cachedUserName;
  static String? _cachedDeviceName;

  /// Haal of genereer de gebruikersnaam
  /// Standaard wordt de apparaatnaam gebruikt
  static Future<String> getUserName() async {
    if (_cachedUserName != null) {
      return _cachedUserName!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString(_userNameKey);

    if (savedName == null || savedName.isEmpty) {
      // Gebruik apparaatnaam als standaard
      savedName = await _getDeviceName();
      await prefs.setString(_userNameKey, savedName);
    }

    _cachedUserName = savedName;
    return savedName;
  }

  /// Stel een aangepaste gebruikersnaam in
  static Future<void> setUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();

    if (name.trim().isEmpty) {
      // Als naam leeg is, ga terug naar apparaatnaam
      final deviceName = await _getDeviceName();
      await prefs.setString(_userNameKey, deviceName);
      _cachedUserName = deviceName;
    } else {
      await prefs.setString(_userNameKey, name.trim());
      _cachedUserName = name.trim();
    }
  }

  /// Reset naar apparaatnaam
  static Future<void> resetToDeviceName() async {
    final deviceName = await _getDeviceName();
    await setUserName(deviceName);
  }

  /// Haal de apparaatnaam op
  static Future<String> _getDeviceName() async {
    if (_cachedDeviceName != null) {
      return _cachedDeviceName!;
    }

    try {
      final deviceInfo = DeviceInfoPlugin();

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        _cachedDeviceName = androidInfo.model;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        _cachedDeviceName = iosInfo.name;
      } else {
        _cachedDeviceName = 'Onbekend Apparaat';
      }

      return _cachedDeviceName!;
    } catch (e) {
      // Fallback voor als device info niet beschikbaar is
      _cachedDeviceName = 'Mijn Apparaat';
      return _cachedDeviceName!;
    }
  }

  /// Haal de apparaatnaam op (voor weergave in settings)
  static Future<String> getDeviceName() async {
    return await _getDeviceName();
  }

  /// Check of de huidige naam de apparaatnaam is
  static Future<bool> isUsingDeviceName() async {
    final userName = await getUserName();
    final deviceName = await getDeviceName();
    return userName == deviceName;
  }

  /// Clear cache (voor testing)
  static void clearCache() {
    _cachedUserName = null;
    _cachedDeviceName = null;
  }
}
