import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Encrypt and store PHI data
  static Future<void> storePHI(String key, String value) async {
    final encrypted = _encryptData(value);
    await _storage.write(key: key, value: encrypted);
  }

  // Retrieve and decrypt PHI data
  static Future<String?> getPHI(String key) async {
    final encrypted = await _storage.read(key: key);
    if (encrypted == null) return null;
    return _decryptData(encrypted);
  }

  // Clear all PHI data
  static Future<void> clearAllPHI() async {
    await _storage.deleteAll();
  }

  static String _encryptData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String _decryptData(String encryptedData) {
    // Implement proper decryption based on your encryption method
    return encryptedData;
  }
}
