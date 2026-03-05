import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:flutter/material.dart';

class EncryptionService {
  static const String _encryptionEnabledKey = 'encryption_enabled';
  static const String _userKeyKey = 'user_encryption_key';
  static const String _saltKey = 'encryption_salt';

  /// Check if encryption is enabled
  static bool get isEncryptionEnabled {
    final enabled = StorageService.settingsBox.get(_encryptionEnabledKey, defaultValue: 'false') == 'true';
    debugPrint('🔒 Encryption enabled: $enabled');
    return enabled;
  }

  /// Enable or disable encryption
  static Future<void> setEncryptionEnabled(bool enabled) async {
    await StorageService.settingsBox.put(_encryptionEnabledKey, enabled.toString());
    debugPrint('🔒 Encryption ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Check if user has set up encryption key
  static bool get hasUserKey {
    final hasKey = StorageService.settingsBox.get(_userKeyKey) != null;
    debugPrint('🔑 User has encryption key: $hasKey');
    return hasKey;
  }

  /// Set up encryption with user password
  static Future<bool> setupEncryption(String userPassword) async {
    try {
      if (userPassword.length < 8) {
        debugPrint('❌ Password too short (minimum 8 characters)');
        return false;
      }

      // Generate a random salt
      final random = Random.secure();
      final salt = List<int>.generate(32, (i) => random.nextInt(256));
      final saltBase64 = base64Encode(salt);

      // Derive key from password using PBKDF2
      final key = _deriveKeyFromPassword(userPassword, salt);
      final keyBase64 = base64Encode(key);

      // Store the derived key and salt
      await StorageService.settingsBox.put(_userKeyKey, keyBase64);
      await StorageService.settingsBox.put(_saltKey, saltBase64);
      await setEncryptionEnabled(true);

      debugPrint('✅ Encryption setup successful');
      return true;
    } catch (e) {
      debugPrint('❌ Encryption setup failed: $e');
      return false;
    }
  }

  /// Verify user password
  static bool verifyPassword(String userPassword) {
    try {
      final storedKeyBase64 = StorageService.settingsBox.get(_userKeyKey);
      final storedSaltBase64 = StorageService.settingsBox.get(_saltKey);

      if (storedKeyBase64 == null || storedSaltBase64 == null) {
        debugPrint('❌ No stored encryption key found');
        return false;
      }

      final storedSalt = base64Decode(storedSaltBase64);
      final derivedKey = _deriveKeyFromPassword(userPassword, storedSalt);
      final storedKey = base64Decode(storedKeyBase64);

      final match = _constantTimeEquals(derivedKey, storedKey);
      debugPrint('🔑 Password verification: ${match ? 'success' : 'failed'}');
      return match;
    } catch (e) {
      debugPrint('❌ Password verification error: $e');
      return false;
    }
  }

  /// Encrypt data using stored user key
  static Future<Uint8List?> encryptData(Uint8List data, {String? userPassword}) async {
    try {
      if (!isEncryptionEnabled) {
        debugPrint('🔒 Encryption disabled, returning original data');
        return data;
      }

      if (!hasUserKey) {
        debugPrint('❌ No user key available for encryption');
        return null;
      }

      // If password provided, verify it first
      if (userPassword != null && !verifyPassword(userPassword)) {
        debugPrint('❌ Invalid password for encryption');
        return null;
      }

      final keyBase64 = StorageService.settingsBox.get(_userKeyKey);
      if (keyBase64 == null) {
        debugPrint('❌ No encryption key found');
        return null;
      }

      final key = base64Decode(keyBase64);

      // Generate random IV
      final random = Random.secure();
      final iv = List<int>.generate(16, (i) => random.nextInt(256));

      // Simple XOR encryption (for demo - in production use AES)
      final encrypted = _xorEncrypt(data, key, iv);

      // Prepend IV to encrypted data
      final result = Uint8List.fromList([...iv, ...encrypted]);

      debugPrint('✅ Data encrypted: ${data.length} bytes -> ${result.length} bytes');
      return result;
    } catch (e) {
      debugPrint('❌ Encryption failed: $e');
      return null;
    }
  }

  /// Decrypt data using stored user key
  static Future<Uint8List?> decryptData(Uint8List encryptedData, {String? userPassword}) async {
    try {
      if (!isEncryptionEnabled) {
        debugPrint('🔒 Encryption disabled, returning original data');
        return encryptedData;
      }

      if (!hasUserKey) {
        debugPrint('❌ No user key available for decryption');
        return null;
      }

      // If password provided, verify it first
      if (userPassword != null && !verifyPassword(userPassword)) {
        debugPrint('❌ Invalid password for decryption');
        return null;
      }

      if (encryptedData.length < 16) {
        debugPrint('❌ Encrypted data too short (missing IV)');
        return null;
      }

      final keyBase64 = StorageService.settingsBox.get(_userKeyKey);
      if (keyBase64 == null) {
        debugPrint('❌ No encryption key found');
        return null;
      }

      final key = base64Decode(keyBase64);

      // Extract IV and encrypted data
      final iv = encryptedData.sublist(0, 16);
      final encrypted = encryptedData.sublist(16);

      // Decrypt using XOR
      final decrypted = _xorEncrypt(encrypted, key, iv);

      debugPrint('✅ Data decrypted: ${encryptedData.length} bytes -> ${decrypted.length} bytes');
      return Uint8List.fromList(decrypted);
    } catch (e) {
      debugPrint('❌ Decryption failed: $e');
      return null;
    }
  }

  /// Clear all encryption data
  static Future<void> clearEncryption() async {
    await StorageService.settingsBox.delete(_userKeyKey);
    await StorageService.settingsBox.delete(_saltKey);
    await setEncryptionEnabled(false);
    debugPrint('🔒 Encryption data cleared');
  }

  /// Derive encryption key from password using PBKDF2
  static List<int> _deriveKeyFromPassword(String password, List<int> salt) {
    final passwordBytes = utf8.encode(password);
    final iterations = 10000;

    var result = passwordBytes + salt;
    for (int i = 0; i < iterations; i++) {
      result = sha256.convert(result).bytes;
    }

    return result.take(32).toList(); // 256-bit key
  }

  /// Simple XOR encryption (in production, use AES)
  static List<int> _xorEncrypt(List<int> data, List<int> key, List<int> iv) {
    final result = <int>[];

    for (int i = 0; i < data.length; i++) {
      final keyByte = key[i % key.length];
      final ivByte = iv[i % iv.length];
      result.add(data[i] ^ keyByte ^ ivByte);
    }

    return result;
  }

  /// Constant time comparison to prevent timing attacks
  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;

    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a[i] ^ b[i];
    }

    return result == 0;
  }

  /// Get encryption status for UI
  static Map<String, dynamic> getEncryptionStatus() {
    return {'enabled': isEncryptionEnabled, 'hasKey': hasUserKey, 'canEncrypt': isEncryptionEnabled && hasUserKey};
  }
}
