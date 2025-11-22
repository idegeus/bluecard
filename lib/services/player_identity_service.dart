import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Service voor het beheren van unieke speler identiteit
/// Genereert en bewaart een UUID per device en gebruikt een digest voor communicatie
class PlayerIdentityService {
  static const String _playerUuidKey = 'player_uuid';
  static const String _playerDigestKey = 'player_digest';
  static const Uuid _uuid = Uuid();

  static String? _cachedUuid;
  static String? _cachedDigest;

  /// Haal of genereer de unieke UUID voor deze speler
  static Future<String> getOrCreatePlayerUuid() async {
    if (_cachedUuid != null) {
      return _cachedUuid!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? existingUuid = prefs.getString(_playerUuidKey);

    if (existingUuid == null) {
      // Genereer nieuwe UUID
      existingUuid = _uuid.v4();
      await prefs.setString(_playerUuidKey, existingUuid);

      // Genereer en bewaar digest
      final digest = _generateDigest(existingUuid);
      await prefs.setString(_playerDigestKey, digest);

      print(
        '🆔 Nieuwe speler UUID gegenereerd: ${existingUuid.substring(0, 8)}...',
      );
      print('🔐 Digest voor communicatie: $digest');
    }

    _cachedUuid = existingUuid;
    return existingUuid;
  }

  /// Haal de digest van de UUID op voor communicatie over Bluetooth
  /// Dit is korter dan de volledige UUID en daarmee efficiënter voor BLE
  static Future<String> getPlayerDigest() async {
    if (_cachedDigest != null) {
      return _cachedDigest!;
    }

    final prefs = await SharedPreferences.getInstance();
    String? existingDigest = prefs.getString(_playerDigestKey);

    if (existingDigest == null) {
      // Regenereer digest van bestaande UUID
      final uuid = await getOrCreatePlayerUuid();
      existingDigest = _generateDigest(uuid);
      await prefs.setString(_playerDigestKey, existingDigest);
    }

    _cachedDigest = existingDigest;
    return existingDigest;
  }

  /// Genereer een korte digest van de UUID voor efficiënte BLE communicatie
  /// Gebruikt SHA-256 hash en neemt eerste 8 karakters
  static String _generateDigest(String uuid) {
    final bytes = utf8.encode(uuid);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8);
  }

  /// Haal de volledige UUID op (voor debugging/logging)
  static Future<String?> getFullUuid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_playerUuidKey);
  }

  /// Reset de speler identiteit (voor testing/debugging)
  static Future<void> resetIdentity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_playerUuidKey);
    await prefs.remove(_playerDigestKey);
    _cachedUuid = null;
    _cachedDigest = null;
    print('🔄 Speler identiteit gereset');
  }

  /// Haal een leesbare naam op gebaseerd op de digest
  static String getReadableName(String digest) {
    return 'speler_$digest';
  }

  /// Check of twee digests hetzelfde apparaat representeren
  static bool isSamePlayer(String digest1, String digest2) {
    return digest1.toLowerCase() == digest2.toLowerCase();
  }
}
