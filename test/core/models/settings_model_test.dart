import 'package:flutter_test/flutter_test.dart';
import 'package:document_scanner/core/models/settings_model.dart';

void main() {
  group('DocumentProcessingSettings', () {
    group('defaults', () {
      test('has correct default values', () {
        const settings = DocumentProcessingSettings();

        expect(settings.enableFiltering, isTrue);
        expect(settings.blackWhiteThreshold, equals(0.65));
        expect(settings.sharpnessAmount, equals(1.8));
        expect(settings.sharpnessRadius, equals(1.5));
        expect(settings.sharpnessThreshold, equals(1));
        expect(settings.contrastLevel, equals(1.3));
        expect(settings.brightnessLevel, equals(1.1));
        expect(settings.gammaCorrection, equals(0.85));
      });
    });

    group('toJson/fromJson round-trip', () {
      test('preserves all fields', () {
        const original = DocumentProcessingSettings(
          enableFiltering: false,
          blackWhiteThreshold: 0.8,
          sharpnessAmount: 2.5,
          sharpnessRadius: 2.0,
          sharpnessThreshold: 5,
          contrastLevel: 1.5,
          brightnessLevel: 0.9,
          gammaCorrection: 1.2,
        );

        final json = original.toJson();
        final restored = DocumentProcessingSettings.fromJson(json);

        expect(restored, equals(original));
      });

      test('preserves default values through round-trip', () {
        const original = DocumentProcessingSettings();

        final json = original.toJson();
        final restored = DocumentProcessingSettings.fromJson(json);

        expect(restored, equals(original));
      });
    });

    group('fromJson defaults', () {
      test('uses defaults for missing fields', () {
        final restored = DocumentProcessingSettings.fromJson({});
        const defaults = DocumentProcessingSettings();

        expect(restored.enableFiltering, equals(defaults.enableFiltering));
        expect(restored.blackWhiteThreshold, equals(defaults.blackWhiteThreshold));
        expect(restored.sharpnessAmount, equals(defaults.sharpnessAmount));
        expect(restored.sharpnessRadius, equals(defaults.sharpnessRadius));
        expect(restored.sharpnessThreshold, equals(defaults.sharpnessThreshold));
        expect(restored.contrastLevel, equals(defaults.contrastLevel));
        expect(restored.brightnessLevel, equals(defaults.brightnessLevel));
        expect(restored.gammaCorrection, equals(defaults.gammaCorrection));
      });

      test('handles integer values for double fields', () {
        final json = {
          'blackWhiteThreshold': 1,
          'sharpnessAmount': 2,
          'contrastLevel': 1,
        };

        final restored = DocumentProcessingSettings.fromJson(json);

        expect(restored.blackWhiteThreshold, equals(1.0));
        expect(restored.sharpnessAmount, equals(2.0));
        expect(restored.contrastLevel, equals(1.0));
      });
    });

    group('copyWith', () {
      test('returns new instance with updated fields', () {
        const original = DocumentProcessingSettings();

        final updated = original.copyWith(
          enableFiltering: false,
          blackWhiteThreshold: 0.9,
        );

        expect(updated.enableFiltering, isFalse);
        expect(updated.blackWhiteThreshold, equals(0.9));
        // Unchanged fields preserved
        expect(updated.sharpnessAmount, equals(original.sharpnessAmount));
        expect(updated.contrastLevel, equals(original.contrastLevel));
      });

      test('preserves all fields when no arguments given', () {
        const original = DocumentProcessingSettings(
          enableFiltering: false,
          blackWhiteThreshold: 0.7,
          sharpnessAmount: 2.0,
        );

        final copy = original.copyWith();

        expect(copy, equals(original));
      });
    });

    group('equality', () {
      test('equal instances are equal', () {
        const a = DocumentProcessingSettings(
          enableFiltering: true,
          blackWhiteThreshold: 0.65,
        );
        const b = DocumentProcessingSettings(
          enableFiltering: true,
          blackWhiteThreshold: 0.65,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('different instances are not equal', () {
        const a = DocumentProcessingSettings(enableFiltering: true);
        const b = DocumentProcessingSettings(enableFiltering: false);

        expect(a, isNot(equals(b)));
      });

      test('identical instances are equal', () {
        const a = DocumentProcessingSettings();
        const b = a;

        expect(a, equals(b));
      });
    });

    group('toString', () {
      test('contains all field names', () {
        const settings = DocumentProcessingSettings();
        final str = settings.toString();

        expect(str, contains('enableFiltering'));
        expect(str, contains('blackWhiteThreshold'));
        expect(str, contains('sharpnessAmount'));
        expect(str, contains('sharpnessRadius'));
        expect(str, contains('sharpnessThreshold'));
        expect(str, contains('contrastLevel'));
        expect(str, contains('brightnessLevel'));
        expect(str, contains('gammaCorrection'));
      });
    });
  });
}
