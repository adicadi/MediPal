import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  static const String _sessionKey = 'auth_session_v1';
  static const String _guestKey = 'auth_guest_mode_v1';

  Future<void> saveSession(Map<String, dynamic> session) async {
    await _storage.write(key: _sessionKey, value: jsonEncode(session));
    await _storage.write(key: _guestKey, value: 'false');
  }

  Future<Map<String, dynamic>?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return null;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
  }

  Future<void> setGuestMode(bool enabled) async {
    await _storage.write(key: _guestKey, value: enabled ? 'true' : 'false');
    if (enabled) {
      await clearSession();
    }
  }

  Future<bool> isGuestMode() async {
    final value = await _storage.read(key: _guestKey);
    return value == 'true';
  }
}
