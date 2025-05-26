import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:document_scanner/core/services/storage_service.dart';

class EncryptionService {
  static const String _keyPrefix = 'enc_key_';
  static const String _masterKeyKey = 'master_key';

  static late Encrypter? _encrypter;

  static Future<void> initialize() async {
    await _initializeMasterKey();
  }

  static Future<void> _initializeMasterKey() async {
    final prefs = await SharedPreferences.getInstance();
    String? masterKeyString = prefs.getString(_masterKeyKey);

    if (masterKeyString == null) {
      final random = Random.secure();
      final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
      masterKeyString = base64Encode(keyBytes);
      await prefs.setString(_masterKeyKey, masterKeyString);
    }

    final masterKey = Key(base64Decode(masterKeyString));
    _encrypter = Encrypter(AES(masterKey));
  }

  static String generateKeyId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static Future<String> createEncryptionKey() async {
    final keyId = generateKeyId();
    final random = Random.secure();
    final keyBytes = List<int>.generate(32, (i) => random.nextInt(256));
    final keyString = base64Encode(keyBytes);

    await StorageService.settingsBox.put('$_keyPrefix$keyId', keyString);
    return keyId;
  }

  static String? getEncryptionKey(String keyId) {
    return StorageService.settingsBox.get('$_keyPrefix$keyId');
  }

  static Future<void> deleteEncryptionKey(String keyId) async {
    await StorageService.settingsBox.delete('$_keyPrefix$keyId');
  }

  static Future<Uint8List> encryptData(Uint8List data, String keyId) async {
    if (_encrypter == null) await initialize();

    final keyString = getEncryptionKey(keyId);
    if (keyString == null) {
      throw Exception('Encryption key not found for ID: $keyId');
    }

    final key = Key(base64Decode(keyString));
    final encrypter = Encrypter(AES(key));
    final iv = IV.fromSecureRandom(16);

    final encrypted = encrypter.encryptBytes(data, iv: iv);

    final result = BytesBuilder();
    result.add(iv.bytes);
    result.add(encrypted.bytes);

    return result.toBytes();
  }

  static Future<Uint8List> decryptData(Uint8List encryptedData, String keyId) async {
    if (_encrypter == null) await initialize();

    final keyString = getEncryptionKey(keyId);
    if (keyString == null) {
      throw Exception('Encryption key not found for ID: $keyId');
    }

    final key = Key(base64Decode(keyString));
    final encrypter = Encrypter(AES(key));

    final iv = IV(encryptedData.sublist(0, 16));
    final encrypted = Encrypted(encryptedData.sublist(16));

    return Uint8List.fromList(encrypter.decryptBytes(encrypted, iv: iv));
  }

  static String hashPassword(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  static String generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  static Future<bool> verifyIntegrity(Uint8List data, String expectedHash) async {
    final actualHash = sha256.convert(data).toString();
    return actualHash == expectedHash;
  }

  static String calculateHash(Uint8List data) {
    return sha256.convert(data).toString();
  }
}
