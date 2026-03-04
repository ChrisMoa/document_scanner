import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:document_scanner/core/services/document_scanner_service.dart';
import 'package:document_scanner/core/services/permission_service.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
import 'package:document_scanner/core/models/scan_session_model.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class EnhancedCameraPage extends ConsumerStatefulWidget {
  const EnhancedCameraPage({super.key});

  @override
  ConsumerState<EnhancedCameraPage> createState() => _EnhancedCameraPageState();
}

class _EnhancedCameraPageState extends ConsumerState<EnhancedCameraPage> {
  bool _isScanning = false;
  String? _currentSessionId;
  final List<DocumentModel> _scannedDocuments = [];

  @override
  void initState() {
    super.initState();
    debugPrint('📸 EnhancedCameraPage initialized');
    _createNewSession();
  }

  Future<void> _createNewSession() async {
    _currentSessionId = const Uuid().v4();
    debugPrint('📝 Created new scan session: $_currentSessionId');
    final session = ScanSessionModel(id: _currentSessionId!, createdAt: DateTime.now());
    await ref.read(scanSessionsProvider.notifier).addScanSession(session);
  }

  Future<void> _scanDocuments() async {
    if (_isScanning) return;

    // Check permissions before scanning
    final hasPermissions = await PermissionService.checkStoragePermissions();
    if (!hasPermissions) {
      debugPrint('⚠️ Storage permissions not granted, requesting...');
      final granted = await PermissionService.requestStoragePermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Storage permissions are required to save scanned documents'), backgroundColor: Colors.orange, duration: Duration(seconds: 3)));
        }
        // Continue anyway - files will be saved to app storage
      }
    }

    setState(() {
      _isScanning = true;
    });

    try {
      debugPrint('📄 Starting document scan...');

      // Use cunning_document_scanner to scan documents
      final documents = await DocumentScannerService.scanDocuments(maxPages: 5);

      if (documents.isNotEmpty) {
        debugPrint('✅ Successfully scanned ${documents.length} documents');

        // Add documents to storage
        for (final document in documents) {
          await ref.read(documentsProvider.notifier).addDocument(document);
          setState(() {
            _scannedDocuments.add(document);
          });
        }

        await _updateSession();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Successfully scanned ${documents.length} document(s)'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
        }
      } else {
        debugPrint('⚠️ No documents were scanned');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No documents were scanned'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
        }
      }
    } catch (e) {
      debugPrint('❌ Error during document scanning: $e');
      if (mounted) {
        String errorMessage = 'Error scanning documents';
        if (e.toString().contains('permissions')) {
          errorMessage = 'Permission error - please grant storage permissions in settings';
        } else if (e.toString().contains('camera')) {
          errorMessage = 'Camera error - please check camera permissions';
        } else {
          errorMessage = 'Error scanning documents: ${e.toString().split(':').last.trim()}';
        }

        _showError(errorMessage);
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _scanAsPdf() async {
    if (_isScanning) return;

    // Check permissions before scanning
    final hasPermissions = await PermissionService.checkStoragePermissions();
    if (!hasPermissions) {
      debugPrint('⚠️ Storage permissions not granted, requesting...');
      final granted = await PermissionService.requestStoragePermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Storage permissions are required to save scanned documents'), backgroundColor: Colors.orange, duration: Duration(seconds: 3)));
        }
        // Continue anyway - files will be saved to app storage
      }
    }

    setState(() {
      _isScanning = true;
    });

    try {
      debugPrint('📄 Starting PDF scan...');

      // STEP 1: Scan as images first to capture actual content
      debugPrint('📄 Step 1: Scanning documents as images to capture content');
      final imagePaths = await DocumentScannerService.scanDocumentsAsImages(maxPages: 5);

      if (imagePaths.isEmpty) {
        debugPrint('❌ No images captured during PDF scan');
        if (mounted) {
          _showError('No documents were scanned. Please try again.');
        }
        return;
      }

      debugPrint('✅ Successfully captured ${imagePaths.length} document images');
      debugPrint('📄 Total images for PDF: ${imagePaths.length}');

      // STEP 2: Create PDF from the captured images
      debugPrint('📄 Step 2: Creating PDF from captured images');
      final pdfData = await DocumentScannerService.createPdfFromImagePaths(imagePaths);

      if (pdfData == null) {
        debugPrint('❌ Failed to create PDF from images');
        if (mounted) {
          _showError('Failed to create PDF from scanned images.');
        }
        return;
      }

      // STEP 3: Save the PDF
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = 'scanned_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfPath = '${appDocDir.path}/$fileName';
      final pdfFile = File(pdfPath);

      await pdfFile.writeAsBytes(pdfData);

      final fileSize = await pdfFile.length();
      debugPrint('✅ PDF created successfully: $pdfPath (${fileSize} bytes)');

      // Create document model with both images and PDF
      final document = DocumentModel(
        id: const Uuid().v4(),
        name:
            'Scanned_Document_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}_${DateTime.now().hour.toString().padLeft(2, '0')}_${DateTime.now().minute.toString().padLeft(2, '0')}',
        imagePaths: imagePaths, // Include all the image paths
        pdfPath: pdfPath,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint('📄 Saving document model with ${document.imagePaths.length} images and PDF');

      // Save to storage
      await ref.read(documentsProvider.notifier).addDocument(document);

      setState(() {
        _scannedDocuments.add(document);
      });

      debugPrint('✅ PDF scanning completed successfully with content!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF created with ${imagePaths.length} page(s)'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
      }
    } catch (e) {
      debugPrint('❌ Error during PDF scanning: $e');
      if (mounted) {
        _showError('PDF scanning failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<void> _scanAsImages() async {
    if (_isScanning) return;

    // Check permissions before scanning
    final hasPermissions = await PermissionService.checkStoragePermissions();
    if (!hasPermissions) {
      debugPrint('⚠️ Storage permissions not granted, requesting...');
      final granted = await PermissionService.requestStoragePermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Storage permissions are required to save scanned images'), backgroundColor: Colors.orange, duration: Duration(seconds: 3)));
        }
        // Continue anyway - files will be saved to app storage
      }
    }

    setState(() {
      _isScanning = true;
    });

    try {
      debugPrint('📄 Starting image document scan...');

      // Use cunning_document_scanner to scan as images
      final imagePaths = await DocumentScannerService.scanDocumentsAsImages(maxPages: 5);

      if (imagePaths.isNotEmpty) {
        debugPrint('✅ Successfully scanned ${imagePaths.length} images');

        // Create document models for the images
        for (int i = 0; i < imagePaths.length; i++) {
          final document = DocumentModel(
            id: 'img_scan_${DateTime.now().millisecondsSinceEpoch}_$i',
            name: 'Scanned Image ${i + 1}',
            imagePaths: [imagePaths[i]],
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Add document to storage
          await ref.read(documentsProvider.notifier).addDocument(document);
          setState(() {
            _scannedDocuments.add(document);
          });
        }

        await _updateSession();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Successfully scanned ${imagePaths.length} image(s)'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
        }
      } else {
        debugPrint('⚠️ No images were scanned');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No images were scanned'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
        }
      }
    } catch (e) {
      debugPrint('❌ Error during image scanning: $e');
      if (mounted) {
        String errorMessage = 'Error scanning images';
        if (e.toString().contains('permissions')) {
          errorMessage = 'Permission error - please grant storage permissions in settings';
        } else if (e.toString().contains('camera')) {
          errorMessage = 'Camera error - please check camera permissions';
        } else {
          errorMessage = 'Error scanning images: ${e.toString().split(':').last.trim()}';
        }

        _showError(errorMessage);
      }
    } finally {
      setState(() {
        _isScanning = false;
      });
    }
  }

  Future<void> _updateSession() async {
    if (_currentSessionId != null) {
      final session = ScanSessionModel(id: _currentSessionId!, createdAt: DateTime.now(), isCompleted: false);
      await ref.read(scanSessionsProvider.notifier).updateScanSession(session);
    }
  }

  void _finishScanning() {
    if (_scannedDocuments.isNotEmpty) {
      // Navigate back to home with scanned documents
      context.go('/');
    } else {
      // Just go back if no documents were scanned
      context.pop();
    }
  }

  void _showError(String message) {
    if (!mounted) return;

    debugPrint('🚨 Error: $message');

    // Check if it's a Google Play Services issue
    final isGooglePlayServicesIssue =
        message.contains('Google Play Services') || message.contains('IllegalStateException') || message.contains('ML Kit') || message.contains('Failed to handle result');

    if (isGooglePlayServicesIssue) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              title: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Text('Google Play Services Issue')]),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The document scanner requires an updated version of Google Play Services. Please follow these steps:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Text('1. Open Google Play Store'),
                  const SizedBox(height: 8),
                  const Text('2. Search for "Google Play Services"'),
                  const SizedBox(height: 8),
                  const Text('3. Tap "Update" if available'),
                  const SizedBox(height: 8),
                  const Text('4. Restart this app after updating'),
                  const SizedBox(height: 16),
                  Text('Technical Details: $message', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Try to open Google Play Store
                    // Note: This would need url_launcher package to be fully functional
                  },
                  child: const Text('Open Play Store'),
                ),
              ],
            ),
      );
    } else {
      // Regular error dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(label: 'Dismiss', textColor: Colors.white, onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Document Scanner'),
        actions: [
          if (_scannedDocuments.isNotEmpty) TextButton(onPressed: _finishScanning, child: const Text('Done', style: TextStyle(color: Colors.blue, fontSize: 16))),
          // Debug button for testing
          IconButton(onPressed: () => context.push('/scanner-test'), icon: const Icon(Icons.bug_report, color: Colors.orange), tooltip: 'Scanner Diagnostics'),
        ],
      ),
      body: Column(
        children: [
          // Scanned documents preview
          if (_scannedDocuments.isNotEmpty) ...[
            Container(
              height: 120,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scanned Documents (${_scannedDocuments.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _scannedDocuments.length,
                      itemBuilder: (context, index) {
                        final doc = _scannedDocuments[index];
                        return Container(
                          width: 80,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(8)),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(doc.pdfPath != null ? Icons.picture_as_pdf : Icons.image, color: Colors.white, size: 32),
                              const SizedBox(height: 4),
                              Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.grey),
          ],

          // Main scanning area
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isScanning) ...[
                    const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.blue)),
                    const SizedBox(height: 20),
                    const Text('Scanning documents...', style: TextStyle(color: Colors.white, fontSize: 18)),
                  ] else ...[
                    const Icon(Icons.document_scanner, size: 120, color: Colors.blue),
                    const SizedBox(height: 20),
                    const Text('Professional Document Scanner', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'High-quality document scanning with automatic edge detection, perspective correction, and image enhancement',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Scanning options
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          // Auto Scan (Smart)
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton.icon(
                              onPressed: _scanDocuments,
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                              icon: const Icon(Icons.auto_awesome),
                              label: const Text('Smart Scan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Scan as PDF
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _scanAsPdf,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.blue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.picture_as_pdf),
                              label: const Text('Scan as PDF'),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Scan as Images
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: _scanAsImages,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.blue),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.image),
                              label: const Text('Scan as Images'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
