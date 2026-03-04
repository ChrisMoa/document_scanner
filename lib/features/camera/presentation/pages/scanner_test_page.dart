import 'package:flutter/material.dart';
import 'package:document_scanner/core/services/document_scanner_service.dart';

/// Test page for document scanner functionality
class ScannerTestPage extends StatefulWidget {
  const ScannerTestPage({super.key});

  @override
  State<ScannerTestPage> createState() => _ScannerTestPageState();
}

class _ScannerTestPageState extends State<ScannerTestPage> {
  String _testResults = '';
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runTests();
  }

  Future<void> _runTests() async {
    setState(() {
      _isRunning = true;
      _testResults = '';
    });

    debugPrint('🧪 Starting cunning_document_scanner diagnostic tests...');

    try {
      final buffer = StringBuffer();
      buffer.writeln('=== Cunning Document Scanner Test Results ===\n');

      // Test 1: Single document scan
      buffer.writeln('Test 1: Single Document Scan');
      try {
        debugPrint('🔍 Testing single document scan...');
        final document = await DocumentScannerService.scanSingleDocument();
        if (document != null) {
          buffer.writeln('✅ Single document scan: SUCCESS');
          buffer.writeln('   Document ID: ${document.id}');
          buffer.writeln('   Image paths: ${document.imagePaths.length}');
        } else {
          buffer.writeln('❌ Single document scan: FAILED (returned null)');
        }
      } catch (e) {
        buffer.writeln('❌ Single document scan: ERROR - $e');
      }

      buffer.writeln();

      // Test 2: Manual camera capture
      buffer.writeln('Test 2: Manual Camera Capture');
      try {
        debugPrint('📷 Testing manual camera capture...');
        final document = await DocumentScannerService.captureDocumentManually();
        if (document != null) {
          buffer.writeln('✅ Manual camera capture: SUCCESS');
          buffer.writeln('   Document ID: ${document.id}');
        } else {
          buffer.writeln('❌ Manual camera capture: FAILED (returned null)');
        }
      } catch (e) {
        buffer.writeln('❌ Manual camera capture: ERROR - $e');
      }

      buffer.writeln();

      setState(() {
        _testResults = buffer.toString();
        _isRunning = false;
      });
    } catch (e) {
      setState(() {
        _testResults = 'Error running tests: $e';
        _isRunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scanner Test Page'), backgroundColor: Colors.blue, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This page helps test the cunning_document_scanner functionality.', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 20),

            Row(children: [ElevatedButton(onPressed: _isRunning ? null : _runTests, child: const Text('Run Tests')), const SizedBox(width: 16), if (_isRunning) const CircularProgressIndicator()]),

            const SizedBox(height: 20),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(color: Colors.grey[100], border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8.0)),
              child: Text(_testResults.isEmpty ? 'No test results yet...' : _testResults, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
