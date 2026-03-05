import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for encryption helper logic extracted from EncryptionService.
/// The actual EncryptionService methods depend on StorageService (Hive),
/// so we test the pure cryptographic functions directly here.

/// Derive encryption key from password using iterated SHA-256 (matches EncryptionService._deriveKeyFromPassword)
List<int> deriveKeyFromPassword(String password, List<int> salt) {
  final passwordBytes = utf8.encode(password);
  const iterations = 10000;

  var result = passwordBytes + salt;
  for (int i = 0; i < iterations; i++) {
    result = sha256.convert(result).bytes;
  }

  return result.take(32).toList();
}

/// XOR encryption (matches EncryptionService._xorEncrypt)
List<int> xorEncrypt(List<int> data, List<int> key, List<int> iv) {
  final result = <int>[];
  for (int i = 0; i < data.length; i++) {
    final keyByte = key[i % key.length];
    final ivByte = iv[i % iv.length];
    result.add(data[i] ^ keyByte ^ ivByte);
  }
  return result;
}

/// Constant-time comparison (matches EncryptionService._constantTimeEquals)
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  int result = 0;
  for (int i = 0; i < a.length; i++) {
    result |= a[i] ^ b[i];
  }
  return result == 0;
}

void main() {
  group('Key derivation', () {
    test('produces 32-byte key', () {
      final salt = List<int>.generate(32, (i) => i);
      final key = deriveKeyFromPassword('testpassword', salt);

      expect(key.length, equals(32));
    });

    test('same password and salt produce same key', () {
      final salt = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32];
      final key1 = deriveKeyFromPassword('mypassword', salt);
      final key2 = deriveKeyFromPassword('mypassword', salt);

      expect(key1, equals(key2));
    });

    test('different passwords produce different keys', () {
      final salt = List<int>.generate(32, (i) => i);
      final key1 = deriveKeyFromPassword('password1', salt);
      final key2 = deriveKeyFromPassword('password2', salt);

      expect(key1, isNot(equals(key2)));
    });

    test('different salts produce different keys', () {
      final salt1 = List<int>.generate(32, (i) => i);
      final salt2 = List<int>.generate(32, (i) => i + 100);
      final key1 = deriveKeyFromPassword('samepassword', salt1);
      final key2 = deriveKeyFromPassword('samepassword', salt2);

      expect(key1, isNot(equals(key2)));
    });
  });

  group('XOR encryption', () {
    test('encrypt then decrypt returns original data', () {
      final key = List<int>.generate(32, (i) => i + 1);
      final iv = List<int>.generate(16, (i) => i * 2);
      final data = utf8.encode('Hello, World! This is a test message.');

      final encrypted = xorEncrypt(data, key, iv);
      final decrypted = xorEncrypt(encrypted, key, iv);

      expect(decrypted, equals(data));
      expect(utf8.decode(decrypted), equals('Hello, World! This is a test message.'));
    });

    test('encrypted data differs from original', () {
      final key = List<int>.generate(32, (i) => i + 1);
      final iv = List<int>.generate(16, (i) => i * 3);
      final data = utf8.encode('Secret data');

      final encrypted = xorEncrypt(data, key, iv);

      expect(encrypted, isNot(equals(data)));
      expect(encrypted.length, equals(data.length));
    });

    test('different keys produce different encrypted data', () {
      final key1 = List<int>.generate(32, (i) => i + 1);
      final key2 = List<int>.generate(32, (i) => i + 50);
      final iv = List<int>.generate(16, (i) => i);
      final data = utf8.encode('Same data');

      final encrypted1 = xorEncrypt(data, key1, iv);
      final encrypted2 = xorEncrypt(data, key2, iv);

      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('different IVs produce different encrypted data', () {
      final key = List<int>.generate(32, (i) => i + 1);
      final iv1 = List<int>.generate(16, (i) => i);
      final iv2 = List<int>.generate(16, (i) => i + 100);
      final data = utf8.encode('Same data');

      final encrypted1 = xorEncrypt(data, key, iv1);
      final encrypted2 = xorEncrypt(data, key, iv2);

      expect(encrypted1, isNot(equals(encrypted2)));
    });

    test('handles empty data', () {
      final key = List<int>.generate(32, (i) => i);
      final iv = List<int>.generate(16, (i) => i);

      final encrypted = xorEncrypt([], key, iv);

      expect(encrypted, isEmpty);
    });

    test('handles single byte', () {
      final key = [42, ...List<int>.generate(31, (i) => 0)];
      final iv = [7, ...List<int>.generate(15, (i) => 0)];
      final data = [100];

      final encrypted = xorEncrypt(data, key, iv);
      final decrypted = xorEncrypt(encrypted, key, iv);

      expect(decrypted, equals(data));
    });
  });

  group('Constant-time comparison', () {
    test('equal lists return true', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 5];

      expect(constantTimeEquals(a, b), isTrue);
    });

    test('different lists return false', () {
      final a = [1, 2, 3, 4, 5];
      final b = [1, 2, 3, 4, 6];

      expect(constantTimeEquals(a, b), isFalse);
    });

    test('different length lists return false', () {
      final a = [1, 2, 3];
      final b = [1, 2, 3, 4];

      expect(constantTimeEquals(a, b), isFalse);
    });

    test('empty lists return true', () {
      expect(constantTimeEquals([], []), isTrue);
    });

    test('one empty one non-empty return false', () {
      expect(constantTimeEquals([], [1]), isFalse);
    });

    test('single element equal lists return true', () {
      expect(constantTimeEquals([255], [255]), isTrue);
    });

    test('single element different lists return false', () {
      expect(constantTimeEquals([0], [1]), isFalse);
    });
  });

  group('Full encrypt/decrypt flow', () {
    test('password-derived key encrypts and decrypts correctly', () {
      final salt = List<int>.generate(32, (i) => (i * 7 + 3) % 256);
      final key = deriveKeyFromPassword('my-secure-password-123', salt);
      final iv = List<int>.generate(16, (i) => (i * 13 + 5) % 256);

      final original = utf8.encode('This is sensitive document data that must be protected.');

      final encrypted = xorEncrypt(original, key, iv);
      expect(encrypted, isNot(equals(original)));

      final decrypted = xorEncrypt(encrypted, key, iv);
      expect(decrypted, equals(original));
      expect(utf8.decode(decrypted), equals('This is sensitive document data that must be protected.'));
    });

    test('wrong password fails to decrypt correctly', () {
      final salt = List<int>.generate(32, (i) => (i * 7 + 3) % 256);
      final correctKey = deriveKeyFromPassword('correct-password', salt);
      final wrongKey = deriveKeyFromPassword('wrong-password', salt);
      final iv = List<int>.generate(16, (i) => i);

      final original = utf8.encode('Secret message');
      final encrypted = xorEncrypt(original, correctKey, iv);
      final badDecrypt = xorEncrypt(encrypted, wrongKey, iv);

      expect(badDecrypt, isNot(equals(original)));
      expect(constantTimeEquals(correctKey, wrongKey), isFalse);
    });
  });
}
