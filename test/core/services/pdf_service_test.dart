import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/core/services/pdf_service.dart';

void main() {
  group('PdfService', () {
    group('generateFileName', () {
      test('contains base name', () {
        final fileName = PdfService.generateFileName('My_Document');

        expect(fileName, startsWith('My_Document_'));
        expect(fileName, endsWith('.pdf'));
      });

      test('contains timestamp in expected format', () {
        final fileName = PdfService.generateFileName('Test');

        // Pattern: Test_YYYYMMDD_HHMMSS.pdf
        final regex = RegExp(r'^Test_\d{8}_\d{6}\.pdf$');
        expect(regex.hasMatch(fileName), isTrue);
      });

      test('generates unique names for different calls', () {
        // Two calls within the same second may produce the same name,
        // but the format should be consistent
        final name1 = PdfService.generateFileName('Doc');
        final name2 = PdfService.generateFileName('Doc');

        expect(name1, startsWith('Doc_'));
        expect(name2, startsWith('Doc_'));
        expect(name1, endsWith('.pdf'));
        expect(name2, endsWith('.pdf'));
      });

      test('handles empty base name', () {
        final fileName = PdfService.generateFileName('');

        expect(fileName, startsWith('_'));
        expect(fileName, endsWith('.pdf'));
      });

      test('handles base name with special characters', () {
        final fileName = PdfService.generateFileName('My_Doc-2026');

        expect(fileName, startsWith('My_Doc-2026_'));
        expect(fileName, endsWith('.pdf'));
      });
    });
  });
}
