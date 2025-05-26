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
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _createNewSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CameraService.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      CameraService.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final success = await CameraService.initializeController();
      if (success) {
        final controller = CameraService.controller!;
        _maxZoom = await controller.getMaxZoomLevel();
        _minZoom = await controller.getMinZoomLevel();
        setState(() {
          _isInitialized = true;
        });
      } else {
        _showErrorDialog('Failed to initialize camera');
      }
    } catch (e) {
      _showErrorDialog('Camera error: $e');
    }
  }

  Future<void> _createNewSession() async {
    _currentSessionId = const Uuid().v4();
    final session = ScanSessionModel(id: _currentSessionId!, createdAt: DateTime.now());
    await ref.read(scanSessionsProvider.notifier).addScanSession(session);
  }

  Future<void> _captureImage() async {
    if (!_isInitialized || _isCapturing) return;

    setState(() {
      _isCapturing = true;
    });

    try {
      final imagePath = await CameraService.takePicture();
      if (imagePath != null) {
        final processedImagePath = await _processImage(imagePath);
        if (processedImagePath != null) {
          setState(() {
            _capturedImages.add(processedImagePath);
          });
          await _updateSession();
        }
      }
    } catch (e) {
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
        debugPrint('Original image file does not exist: $originalPath');
        return null;
      }

      debugPrint('Processing image: $originalPath');

      try {
        // Try OpenCV document detection and cropping
        final processedData = await OpenCVService().detectAndCropDocument(file);
        if (processedData != null && await processedData.exists()) {
          final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.png';
          debugPrint('OpenCV processing successful, saving processed image: ${processedData.path}');
          final processedPath = await StorageService.saveImageFile(await processedData.readAsBytes(), fileName);

          // Clean up original file
          await file.delete();
          debugPrint('Processed image saved to: $processedPath');
          return processedPath;
        } else {
          debugPrint('OpenCV processing returned null or invalid file, using original image');
        }
      } catch (openCvError) {
        debugPrint('OpenCV processing failed: $openCvError');
        debugPrint('Falling back to original image without processing');
      }

      // Fallback: Use original image if OpenCV processing fails
      final fileName = 'scan_${DateTime.now().millisecondsSinceEpoch}.png';
      final imageBytes = await file.readAsBytes();
      final processedPath = await StorageService.saveImageFile(imageBytes, fileName);

      // Clean up original file
      await file.delete();
      debugPrint('Original image saved to: $processedPath');
      return processedPath;
    } catch (e) {
      debugPrint('Image processing error: $e');
      return null;
    }
  }

  Future<void> _updateSession() async {
    if (_currentSessionId == null) return;

    final session = ref.read(scanSessionsProvider.notifier).getScanSession(_currentSessionId!);
    if (session != null) {
      final updatedSession = session.copyWith(imagePaths: _capturedImages);
      await ref.read(scanSessionsProvider.notifier).updateScanSession(updatedSession);
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
    CameraService.setFlashMode(_flashMode);
  }

  Future<void> _switchCamera() async {
    final success = await CameraService.switchCamera();
    if (success) {
      final controller = CameraService.controller!;
      _maxZoom = await controller.getMaxZoomLevel();
      _minZoom = await controller.getMinZoomLevel();
      _zoomLevel = 1.0;
      setState(() {});
    }
  }

  void _onZoomChanged(double zoom) {
    setState(() {
      _zoomLevel = zoom.clamp(_minZoom, _maxZoom);
    });
    CameraService.setZoomLevel(_zoomLevel);
  }

  void _removeImage(int index) {
    if (index < _capturedImages.length) {
      final imagePath = _capturedImages[index];
      StorageService.deleteFile(imagePath);
      setState(() {
        _capturedImages.removeAt(index);
      });
      _updateSession();
    }
  }

  Future<void> _finishScanning() async {
    if (_capturedImages.isEmpty) {
      _showErrorDialog('No images captured');
      return;
    }

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
      }

      // Generate document name based on current date and time
      final now = DateTime.now();
      final documentName =
          'Scan_${now.day.toString().padLeft(2, '0')}'
          '${now.month.toString().padLeft(2, '0')}'
          '${now.year}_'
          '${now.hour.toString().padLeft(2, '0')}'
          '${now.minute.toString().padLeft(2, '0')}';

      debugPrint('Creating document: $documentName with ${_capturedImages.length} images');

      // Log all captured image paths before PDF generation
      for (int i = 0; i < _capturedImages.length; i++) {
        final imagePath = _capturedImages[i];
        final exists = await File(imagePath).exists();
        debugPrint('📸 Captured image $i: $imagePath (exists: $exists)');
      }

      // Generate PDF from captured images
      final pdfData = await PdfService.createPdfFromImages(_capturedImages, documentName);
      final pdfFileName = PdfService.generateFileName(documentName);
      final pdfPath = await StorageService.savePdfFile(pdfData, pdfFileName);

      debugPrint('PDF generated successfully at: $pdfPath');

      // Get storage location info for display
      final storageDisplayName = StorageService.getStorageLocationDisplayName(pdfPath);
      debugPrint('📁 Storage location: $storageDisplayName');

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
      await ref.read(documentsProvider.notifier).addDocument(document);
      debugPrint('Document saved successfully with ID: $documentId');

      // Mark session as completed (cleanup)
      if (_currentSessionId != null) {
        await ref.read(scanSessionsProvider.notifier).markSessionCompleted(_currentSessionId!);
        debugPrint('Scan session marked as completed: $_currentSessionId');
      }

      // Close loading dialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      // Show success message and navigate back
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Document "$documentName" created successfully with PDF!'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
        context.pop();
      }
    } catch (e) {
      debugPrint('Error finishing scan: $e');

      // Close loading dialog if open
      if (context.mounted) {
        Navigator.of(context).pop();
      }

      _showErrorDialog('Failed to create document: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(title: const Text('Error'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
          Positioned.fill(
            child:
                CameraService.controller != null
                    ? CameraPreview(CameraService.controller!)
                    : Container(color: Colors.black, child: const Center(child: Text('Camera not available', style: TextStyle(color: Colors.white)))),
          ),

          if (_isCapturing) Container(color: Colors.black.withOpacity(0.3), child: const Center(child: CircularProgressIndicator(color: Colors.white))),

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
