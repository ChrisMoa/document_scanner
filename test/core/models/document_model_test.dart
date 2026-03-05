import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/core/models/document_model.dart';

void main() {
  group('DocumentModel', () {
    late DocumentModel document;
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 3, 5, 12, 0, 0);
      document = DocumentModel(
        id: 'test-id-123',
        name: 'Test_Document',
        imagePaths: ['/path/to/image1.jpg', '/path/to/image2.jpg'],
        pdfPath: '/path/to/document.pdf',
        createdAt: now,
        updatedAt: now,
        isUploaded: true,
        cloudUrl: 'https://cloud.example.com/doc.pdf',
        isEncrypted: true,
        encryptionKeyId: 'key-456',
        storageLocation: '/storage/docs',
        isDownloaded: true,
      );
    });

    group('toJson/fromJson round-trip', () {
      test('preserves all fields', () {
        final json = document.toJson();
        final restored = DocumentModel.fromJson(json);

        expect(restored.id, equals(document.id));
        expect(restored.name, equals(document.name));
        expect(restored.imagePaths, equals(document.imagePaths));
        expect(restored.pdfPath, equals(document.pdfPath));
        expect(restored.createdAt, equals(document.createdAt));
        expect(restored.updatedAt, equals(document.updatedAt));
        expect(restored.isUploaded, equals(document.isUploaded));
        expect(restored.cloudUrl, equals(document.cloudUrl));
        expect(restored.isEncrypted, equals(document.isEncrypted));
        expect(restored.encryptionKeyId, equals(document.encryptionKeyId));
        expect(restored.storageLocation, equals(document.storageLocation));
        expect(restored.isDownloaded, equals(document.isDownloaded));
      });

      test('handles null optional fields', () {
        final minimal = DocumentModel(
          id: 'min-id',
          name: 'Minimal_Doc',
          createdAt: now,
          updatedAt: now,
        );

        final json = minimal.toJson();
        final restored = DocumentModel.fromJson(json);

        expect(restored.id, equals('min-id'));
        expect(restored.name, equals('Minimal_Doc'));
        expect(restored.imagePaths, isEmpty);
        expect(restored.pdfPath, isNull);
        expect(restored.cloudUrl, isNull);
        expect(restored.encryptionKeyId, isNull);
        expect(restored.storageLocation, isNull);
      });

      test('handles empty imagePaths list', () {
        final doc = DocumentModel(
          id: 'empty-imgs',
          name: 'No_Images',
          imagePaths: [],
          createdAt: now,
          updatedAt: now,
        );

        final json = doc.toJson();
        final restored = DocumentModel.fromJson(json);

        expect(restored.imagePaths, isEmpty);
      });

      test('serializes dates as ISO 8601 strings', () {
        final json = document.toJson();

        expect(json['createdAt'], equals(now.toIso8601String()));
        expect(json['updatedAt'], equals(now.toIso8601String()));
      });
    });

    group('fromJson defaults', () {
      test('defaults isUploaded to false when missing', () {
        final json = {
          'id': 'id-1',
          'name': 'Doc',
          'imagePaths': <String>[],
          'pdfPath': null,
          'createdAt': now.toIso8601String(),
          'updatedAt': now.toIso8601String(),
          'cloudUrl': null,
          'encryptionKeyId': null,
          'storageLocation': null,
        };

        final restored = DocumentModel.fromJson(json);

        expect(restored.isUploaded, isFalse);
        expect(restored.isEncrypted, isFalse);
        expect(restored.isDownloaded, isFalse);
      });
    });

    group('copyWith', () {
      test('returns new instance with updated fields', () {
        final updated = document.copyWith(
          name: 'Updated_Name',
          isUploaded: false,
        );

        expect(updated.name, equals('Updated_Name'));
        expect(updated.isUploaded, isFalse);
        // Unchanged fields preserved
        expect(updated.id, equals(document.id));
        expect(updated.imagePaths, equals(document.imagePaths));
        expect(updated.pdfPath, equals(document.pdfPath));
        expect(updated.isEncrypted, equals(document.isEncrypted));
      });

      test('preserves all fields when no arguments given', () {
        final copy = document.copyWith();

        expect(copy.id, equals(document.id));
        expect(copy.name, equals(document.name));
        expect(copy.imagePaths, equals(document.imagePaths));
        expect(copy.pdfPath, equals(document.pdfPath));
        expect(copy.createdAt, equals(document.createdAt));
        expect(copy.updatedAt, equals(document.updatedAt));
        expect(copy.isUploaded, equals(document.isUploaded));
        expect(copy.cloudUrl, equals(document.cloudUrl));
        expect(copy.isEncrypted, equals(document.isEncrypted));
        expect(copy.encryptionKeyId, equals(document.encryptionKeyId));
        expect(copy.storageLocation, equals(document.storageLocation));
        expect(copy.isDownloaded, equals(document.isDownloaded));
      });

      test('can update imagePaths', () {
        final updated = document.copyWith(
          imagePaths: ['/new/path.jpg'],
        );

        expect(updated.imagePaths, equals(['/new/path.jpg']));
      });
    });

    group('constructor defaults', () {
      test('sets correct default values', () {
        final doc = DocumentModel(
          id: 'def-id',
          name: 'Default_Doc',
          createdAt: now,
          updatedAt: now,
        );

        expect(doc.imagePaths, equals(const []));
        expect(doc.pdfPath, isNull);
        expect(doc.isUploaded, isFalse);
        expect(doc.cloudUrl, isNull);
        expect(doc.isEncrypted, isFalse);
        expect(doc.encryptionKeyId, isNull);
        expect(doc.storageLocation, isNull);
        expect(doc.isDownloaded, isFalse);
      });
    });
  });
}
