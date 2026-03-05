import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/core/models/scan_session_model.dart';

void main() {
  group('ScanSessionModel', () {
    late ScanSessionModel session;
    late DateTime now;

    setUp(() {
      now = DateTime(2026, 3, 5, 14, 30, 0);
      session = ScanSessionModel(
        id: 'session-abc',
        imagePaths: ['/img/scan1.jpg', '/img/scan2.jpg', '/img/scan3.jpg'],
        createdAt: now,
        isCompleted: true,
      );
    });

    group('toJson/fromJson round-trip', () {
      test('preserves all fields', () {
        final json = session.toJson();
        final restored = ScanSessionModel.fromJson(json);

        expect(restored.id, equals(session.id));
        expect(restored.imagePaths, equals(session.imagePaths));
        expect(restored.createdAt, equals(session.createdAt));
        expect(restored.isCompleted, equals(session.isCompleted));
      });

      test('handles empty imagePaths', () {
        final empty = ScanSessionModel(
          id: 'empty-session',
          imagePaths: [],
          createdAt: now,
        );

        final json = empty.toJson();
        final restored = ScanSessionModel.fromJson(json);

        expect(restored.imagePaths, isEmpty);
        expect(restored.isCompleted, isFalse);
      });

      test('serializes createdAt as ISO 8601', () {
        final json = session.toJson();
        expect(json['createdAt'], equals(now.toIso8601String()));
      });
    });

    group('fromJson defaults', () {
      test('defaults isCompleted to false when missing', () {
        final json = {
          'id': 'sess-1',
          'imagePaths': <String>[],
          'createdAt': now.toIso8601String(),
        };

        final restored = ScanSessionModel.fromJson(json);
        expect(restored.isCompleted, isFalse);
      });
    });

    group('copyWith', () {
      test('returns new instance with updated fields', () {
        final updated = session.copyWith(isCompleted: false);

        expect(updated.isCompleted, isFalse);
        expect(updated.id, equals(session.id));
        expect(updated.imagePaths, equals(session.imagePaths));
        expect(updated.createdAt, equals(session.createdAt));
      });

      test('preserves all fields when no arguments given', () {
        final copy = session.copyWith();

        expect(copy.id, equals(session.id));
        expect(copy.imagePaths, equals(session.imagePaths));
        expect(copy.createdAt, equals(session.createdAt));
        expect(copy.isCompleted, equals(session.isCompleted));
      });

      test('can update imagePaths', () {
        final updated = session.copyWith(
          imagePaths: ['/new/scan.jpg'],
        );

        expect(updated.imagePaths, equals(['/new/scan.jpg']));
        expect(updated.imagePaths.length, equals(1));
      });

      test('can update id', () {
        final updated = session.copyWith(id: 'new-id');
        expect(updated.id, equals('new-id'));
      });
    });

    group('constructor defaults', () {
      test('sets correct default values', () {
        final s = ScanSessionModel(
          id: 'new-session',
          createdAt: now,
        );

        expect(s.imagePaths, equals(const []));
        expect(s.isCompleted, isFalse);
      });
    });
  });
}
