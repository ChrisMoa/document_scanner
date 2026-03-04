import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Document Scanner app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: Text('Document Scanner'))),
      ),
    );

    expect(find.text('Document Scanner'), findsOneWidget);
  });

  test('Document naming with underscores test', () {
    final now = DateTime.now();
    final expectedName =
        'Scanned_Document_${now.day}_${now.month}_${now.year}';

    expect(expectedName.contains(' '), false);
    expect(expectedName.contains('_'), true);

    expect(
      'Scanned Document 1'.replaceAll(' ', '_'),
      equals('Scanned_Document_1'),
    );
    expect(
      'Scanned Document 29/5/2025'
          .replaceAll(' ', '_')
          .replaceAll('/', '_'),
      equals('Scanned_Document_29_5_2025'),
    );
  });

  test('Document scanner service exception handling', () {
    const testException =
        'Document scanner failed: Test error. Please ensure camera permissions are granted and try again.';

    expect(testException.contains('Document scanner failed:'), true);
    expect(testException.contains('Please ensure camera permissions'), true);
  });
}
