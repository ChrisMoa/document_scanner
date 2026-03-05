import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:document_scanner/core/services/camera_service.dart';
import 'package:document_scanner/core/services/opencv_service.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/services/pdf_service.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
import 'package:document_scanner/core/models/scan_session_model.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/features/camera/presentation/widgets/camera_controls.dart';
import 'package:document_scanner/features/camera/presentation/widgets/captured_images_preview.dart';

class CameraPage extends ConsumerStatefulWidget {
  const CameraPage({super.key});

  @override
  ConsumerState<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends ConsumerState<CameraPage> with WidgetsBindingObserver {
  bool _isInitialized = false;
  bool _isCapturing = false;
  FlashMode _flashMode = FlashMode.off;
  double _zoomLevel = 1.0;
  double _maxZoom = 1.0;
  double _minZoom = 1.0;

  final List<String> _capturedImages = [];
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    debugPrint('📸 CameraPage initialized');
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _createNewSession();
  }

  @override
  void dispose() {
    debugPrint('📸 CameraPage disposing');
    WidgetsBinding.instance.removeObserver(this);
    CameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📱 App lifecycle state changed to: $state');
    if (state == AppLifecycleState.inactive) {
      CameraService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    debugPrint('📷 Initializing camera...');
    try {
      final success = await CameraService.initializeController();
      if (success) {
        final controller = CameraService.controller!;
        _maxZoom = await controller.getMaxZoomLevel();
        _minZoom = await controller.getMinZoomLevel();
        debugPrint('📷 Camera initialized successfully (zoom: $_minZoom - $_maxZoom)');
        setState(() {
          _isInitialized = true;
        });
      } else {
        debugPrint('❌ Failed to initialize camera');
        _showErrorDialog('Failed to initialize camera');
      }
    } catch (e) {
      debugPrint('❌ Camera initialization error: $e');
      _showErrorDialog('Camera error: $e');
    }
  }

  Future<void> _createNewSession() async {
    _currentSessionId = const Uuid().v4();
    debugPrint('📝 Created new scan session: $_currentSessionId');
    final session = ScanSessionModel(id: _currentSessionId!, createdAt: DateTime.now());
    await ref.read(scanSessionsProvider.notifier).addScanSession(session);
  }

  Future<void> _captureImage() async {
    if (!_isInitialized || _isCapturing) {
      debugPrint('⚠️ Cannot capture - camera not ready or already capturing');
      return;
    }

    debugPrint('📸 Starting image capture...');
    setState(() {
      _isCapturing = true;
    });

    try {
      final imagePath = await CameraService.takePicture();
      if (imagePath != null) {
        debugPrint('📸 Image captured: $imagePath');
        final processedImagePath = await _processImage(imagePath);
        if (processedImagePath != null) {
          debugPrint('✅ Image processed and saved: $processedImagePath');
          setState(() {
            _capturedImages.add(processedImagePath);
          });
          await _updateSession();
        } else {
          debugPrint('❌ Image processing failed');
        }
      } else {
        debugPrint('❌ Failed to capture image');
      }
    } catch (e) {
      debugPrint('❌ Image capture error: $e');
      _showErrorDialog('Failed to capture image: $e');
    } finally {
      setState(() {
        _isCapturing = false;
      });
    }
  }

  Future<String?> _processImage(String originalPath) async {
    try {
      final file = File(originalPath);
      if (!await file.exists()) {
        debugPrint('❌ Original image file does not exist: $originalPath');
        return null;
      }

      debugPrint('🔄 Processing captured image: $originalPath');

      try {
        // Try OpenCV document corner detection
        debugPrint('🔍 Attempting OpenCV document corner detection...');
        final documentCorners = await OpenCVService().detectDocumentCorners(file);

        if (documentCorners != null) {
          debugPrint('✅ Document corners detected successfully');

          // Navigate to manual adjustment page
          if (context.mounted) {
            final croppedImagePath = await context.push<String>(
              '/document-crop',
              extra: {'imagePath': originalPath, 'initialCorners': documentCorners.corners, 'imageWidth': documentCorners.imageWidth, 'imageHeight': documentCorners.imageHeight},
            );

            if (croppedImagePath != null) {
              final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.png';
              debugPrint('✅ Manual adjustment completed, saving processed image...');

              // Read the cropped file and save to user's preferred location
              final croppedFile = File(croppedImagePath);
              final croppedBytes = await croppedFile.readAsBytes();
              final processedPath = await StorageService.saveImageFile(croppedBytes, fileName);

              // Clean up temporary files
              await file.delete();
              await croppedFile.delete();

              debugPrint('✅ Processed image saved to: $processedPath');
              return processedPath;
            } else {
              // User cancelled the manual adjustment
              debugPrint('⚠️ User cancelled manual adjustment');
              await file.delete();
              return null;
            }
          }
        } else {
          debugPrint('⚠️ Document corner detection failed, using original image');
        }
      } catch (openCvError) {
        debugPrint('⚠️ OpenCV processing failed: $openCvError');
        debugPrint('🔄 Falling back to original image without processing');
      }

      // Fallback: Use original image and save to user's preferred location
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageBytes = await file.readAsBytes();

      // Save to user's preferred location automatically
      final processedPath = await StorageService.saveImageFile(imageBytes, fileName);

      // Clean up original file
      await file.delete();

      debugPrint('✅ Original image saved to user location: $processedPath');
      return processedPath;
    } catch (e) {
      debugPrint('❌ Image processing error: $e');
      return null;
    }
  }

  Future<void> _updateSession() async {
    if (_currentSessionId == null) {
      debugPrint('⚠️ No current session to update');
      return;
    }

    debugPrint('🔄 Updating scan session with ${_capturedImages.length} images');
    final session = ref.read(scanSessionsProvider.notifier).getScanSession(_currentSessionId!);
    if (session != null) {
      final updatedSession = session.copyWith(imagePaths: _capturedImages);
      await ref.read(scanSessionsProvider.notifier).updateScanSession(updatedSession);
      debugPrint('✅ Scan session updated');
    }
  }

  void _toggleFlash() {
    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.auto;
          break;
        case FlashMode.auto:
          _flashMode = FlashMode.always;
          break;
        case FlashMode.always:
          _flashMode = FlashMode.off;
          break;
        case FlashMode.torch:
          _flashMode = FlashMode.off;
          break;
      }
    });
    debugPrint('💡 Flash mode changed to: $_flashMode');
    CameraService.setFlashMode(_flashMode);
  }

  Future<void> _switchCamera() async {
    debugPrint('🔄 Switching camera...');
    final success = await CameraService.switchCamera();
    if (success) {
      final controller = CameraService.controller!;
      _maxZoom = await controller.getMaxZoomLevel();
      _minZoom = await controller.getMinZoomLevel();
      _zoomLevel = 1.0;
      debugPrint('✅ Camera switched successfully');
      setState(() {});
    } else {
      debugPrint('❌ Failed to switch camera');
    }
  }

  void _onZoomChanged(double zoom) {
    setState(() {
      _zoomLevel = zoom.clamp(_minZoom, _maxZoom);
    });
    CameraService.setZoomLevel(_zoomLevel);
    debugPrint('🔍 Zoom level changed to: $_zoomLevel');
  }

  void _removeImage(int index) {
    if (index < _capturedImages.length) {
      final imagePath = _capturedImages[index];
      debugPrint('🗑️ Removing captured image: $imagePath');
      StorageService.deleteFile(imagePath);
      setState(() {
        _capturedImages.removeAt(index);
      });
      _updateSession();
    }
  }

  Future<void> _finishScanning() async {
    if (_capturedImages.isEmpty) {
      debugPrint('⚠️ No images captured, cannot finish scanning');
      _showErrorDialog('No images captured');
      return;
    }

    debugPrint('🏁 Finishing scan with ${_capturedImages.length} images');
    _debugScanningState();

    // Keep track of loading dialog state
    bool loadingDialogShown = false;

    try {
      // Show loading dialog
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder:
              (context) =>
                  const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Creating document and generating PDF...')])),
        );
        loadingDialogShown = true;
      }

      // Generate document name based on current date and time
      final now = DateTime.now();
      final documentName =
          'Scan_${now.day.toString().padLeft(2, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.year}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';

      debugPrint('📄 Creating document: $documentName with ${_capturedImages.length} images');

      // Log all captured image paths before PDF generation
      for (int i = 0; i < _capturedImages.length; i++) {
        final imagePath = _capturedImages[i];
        final exists = await File(imagePath).exists();
        debugPrint('📸 Captured image $i: $imagePath (exists: $exists)');

        if (!exists) {
          throw Exception('Image file not found: $imagePath');
        }
      }

      // Generate PDF from captured images with timeout
      debugPrint('📄 Generating PDF from images...');
      final pdfData = await PdfService.createPdfFromImages(_capturedImages, documentName).timeout(const Duration(minutes: 2), onTimeout: () => throw Exception('PDF generation timed out'));

      final pdfFileName = PdfService.generateFileName(documentName);
      debugPrint('📄 PDF generated successfully, size: ${pdfData.length} bytes');

      // Close loading dialog before showing save dialog
      if (context.mounted && loadingDialogShown) {
        Navigator.of(context).pop();
        loadingDialogShown = false;
      }

      // Show user choice for PDF saving with timeout
      final saveChoice = await _showPdfSaveDialog().timeout(
        const Duration(minutes: 1),
        onTimeout: () {
          debugPrint('⚠️ PDF save dialog timed out, using app storage');
          return 'app';
        },
      );

      // Show loading dialog again for saving process
      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Saving PDF...')])),
        );
        loadingDialogShown = true;
      }

      String pdfPath;
      if (saveChoice == 'saf') {
        // Use SAF to let user choose location with timeout
        debugPrint('💾 User chose SAF for PDF saving');
        try {
          pdfPath = await StorageService.savePdfFile(pdfData, pdfFileName).timeout(const Duration(minutes: 2), onTimeout: () => throw Exception('File save operation timed out'));
        } catch (e) {
          debugPrint('❌ SAF save failed: $e, falling back to app storage');
          pdfPath = await StorageService.savePdfFileToAppStorage(pdfData, pdfFileName);
        }
      } else {
        // Save to app storage
        debugPrint('💾 User chose app storage for PDF saving');
        pdfPath = await StorageService.savePdfFileToAppStorage(pdfData, pdfFileName);
      }

      debugPrint('✅ PDF generated and saved successfully at: $pdfPath');

      // Verify the saved file exists
      final savedFile = File(pdfPath);
      if (!await savedFile.exists()) {
        throw Exception('PDF file was not saved properly');
      }

      final fileSize = await savedFile.length();
      debugPrint('✅ PDF file verified: $pdfPath (${fileSize} bytes)');

      // Get storage location info for display
      final storageDisplayName = StorageService.getStorageLocationDisplayName(pdfPath);
      debugPrint('📁 Storage location display name: $storageDisplayName');

      // Create document model
      final documentId = const Uuid().v4();
      final document = DocumentModel(
        id: documentId,
        name: documentName,
        imagePaths: List<String>.from(_capturedImages),
        pdfPath: pdfPath,
        createdAt: now,
        updatedAt: now,
        storageLocation: storageDisplayName,
      );

      // Save document to storage
      debugPrint('💾 Saving document to database...');
      await ref.read(documentsProvider.notifier).addDocument(document);
      debugPrint('✅ Document saved successfully with ID: $documentId');

      // Mark session as completed (cleanup)
      if (_currentSessionId != null) {
        await ref.read(scanSessionsProvider.notifier).markSessionCompleted(_currentSessionId!);
        debugPrint('✅ Scan session marked as completed: $_currentSessionId');
      }

      // Close loading dialog
      if (context.mounted && loadingDialogShown) {
        Navigator.of(context).pop();
        loadingDialogShown = false;
      }

      // Show success message and navigate back
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Document "$documentName" created successfully with PDF!'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
        if (context.mounted) {
          context.pop();
        }
      }
    } catch (e) {
      debugPrint('❌ Error finishing scan: $e');

      // Close loading dialog if open
      if (context.mounted && loadingDialogShown) {
        Navigator.of(context).pop();
      }

      _showErrorDialog('Failed to create document: $e');
    }
  }

  Future<String?> _showPdfSaveDialog() async {
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Save PDF'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose where to save your PDF:'),
                SizedBox(height: 12),
                Text('• Choose Location: Select any folder on your device'),
                Text('• App Storage: Save to app folder (accessible via file manager)'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop('app'), child: const Text('App Storage')),
              ElevatedButton(onPressed: () => Navigator.of(context).pop('saf'), child: const Text('Choose Location')),
            ],
          ),
    );
  }

  void _showErrorDialog(String message) {
    debugPrint('⚠️ Showing error dialog: $message');
    if (context.mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Error'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message),
                  const SizedBox(height: 16),
                  const Text('Troubleshooting tips:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('• Check if storage permissions are granted'),
                  const Text('• Ensure images were captured properly'),
                  const Text('• Try using "App Storage" option instead'),
                  const Text('• Restart the app if problem persists'),
                ],
              ),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
            ),
      );
    }
  }

  // Debug helper function to validate scanning state
  void _debugScanningState() {
    debugPrint('🔍 DEBUG: Current scanning state:');
    debugPrint('  - Captured images: ${_capturedImages.length}');
    debugPrint('  - Session ID: $_currentSessionId');
    debugPrint('  - Is capturing: $_isCapturing');

    for (int i = 0; i < _capturedImages.length; i++) {
      final imagePath = _capturedImages[i];
      File(imagePath).exists().then((exists) {
        debugPrint('  - Image $i: $imagePath (exists: $exists)');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: const Text('Camera')),
        body: const Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: Text('Scan Document (${_capturedImages.length})'),
        actions: [if (_capturedImages.isNotEmpty) TextButton(onPressed: _finishScanning, child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16)))],
      ),
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child:
                CameraService.controller != null
                    ? CameraPreview(CameraService.controller!)
                    : Container(color: Colors.black, child: const Center(child: Text('Camera not available', style: TextStyle(color: Colors.white)))),
          ),

          // Capture overlay
          if (_isCapturing) Container(color: Colors.black.withOpacity(0.3), child: const Center(child: CircularProgressIndicator(color: Colors.white))),

          // Top controls
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: _toggleFlash, icon: Icon(_getFlashIcon(), color: _flashMode != FlashMode.off ? Colors.yellow : Colors.white, size: 28)),
                if (CameraService.hasMultipleCameras) IconButton(onPressed: _switchCamera, icon: const Icon(Icons.flip_camera_android, color: Colors.white, size: 28)),
              ],
            ),
          ),

          // Zoom slider
          if (_maxZoom > _minZoom)
            Positioned(
              right: 16,
              top: 100,
              bottom: 200,
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(value: _zoomLevel, min: _minZoom, max: _maxZoom, onChanged: _onZoomChanged, activeColor: Colors.white, inactiveColor: Colors.white.withOpacity(0.3)),
              ),
            ),

          // Bottom controls
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 200,
              decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black.withOpacity(0.7), Colors.black])),
              child: Column(
                children: [
                  if (_capturedImages.isNotEmpty) ...[const SizedBox(height: 16), CapturedImagesPreview(imagePaths: _capturedImages, onRemove: _removeImage)],
                  Expanded(child: CameraControls(onCapture: _captureImage, isCapturing: _isCapturing, capturedCount: _capturedImages.length)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.auto:
        return Icons.flash_auto;
      case FlashMode.always:
        return Icons.flash_on;
      case FlashMode.torch:
        return Icons.flashlight_on;
    }
  }
}
