import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:document_scanner/core/services/opencv_service.dart';
import 'package:document_scanner/core/providers/document_settings_provider.dart';
import 'package:document_scanner/features/camera/presentation/widgets/document_corner_adjuster.dart';

class DocumentCropPage extends ConsumerStatefulWidget {
  final String imagePath;
  final List<Offset>? initialCorners;
  final int imageWidth;
  final int imageHeight;

  const DocumentCropPage({super.key, required this.imagePath, this.initialCorners, required this.imageWidth, required this.imageHeight});

  @override
  ConsumerState<DocumentCropPage> createState() => _DocumentCropPageState();
}

class _DocumentCropPageState extends ConsumerState<DocumentCropPage> {
  late List<Offset> currentCorners;
  bool isProcessing = false;
  File? processedImage;
  bool showingPreview = false;

  @override
  void initState() {
    super.initState();
    _initializeCorners();
  }

  void _initializeCorners() {
    if (widget.initialCorners != null) {
      currentCorners = List.from(widget.initialCorners!);
    } else {
      // Default corners with 10% inset
      final inset = (widget.imageWidth * 0.1);
      currentCorners = [
        Offset(inset, inset), // top-left
        Offset(widget.imageWidth - inset, inset), // top-right
        Offset(widget.imageWidth - inset, widget.imageHeight - inset), // bottom-right
        Offset(inset, widget.imageHeight - inset), // bottom-left
      ];
    }
  }

  void _onCornersChanged(List<Offset> newCorners) {
    setState(() {
      currentCorners = newCorners;
    });
  }

  Future<void> _cropDocument() async {
    setState(() {
      isProcessing = true;
    });

    try {
      // Get current document processing settings
      final settings = ref.read(documentSettingsProvider);
      debugPrint('🎛️ Using document settings: $settings');

      // Crop the document using the current corners and settings
      final croppedFile = await OpenCVService().cropDocumentWithCorners(File(widget.imagePath), currentCorners, settings);

      if (croppedFile != null && mounted) {
        setState(() {
          processedImage = croppedFile;
          showingPreview = true;
        });
        debugPrint('✅ Document processed, showing preview');
      } else {
        _showErrorDialog('Failed to crop document');
      }
    } catch (e) {
      debugPrint('Error cropping document: $e');
      _showErrorDialog('Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  Future<void> _confirmAndSave() async {
    if (processedImage != null) {
      // Return the processed image path
      context.pop(processedImage!.path);
    }
  }

  void _backToEdit() {
    setState(() {
      processedImage = null;
      showingPreview = false;
    });
  }

  void _showFullScreenPreview() {
    if (processedImage != null) {
      Navigator.of(context).push(MaterialPageRoute(builder: (context) => _FullScreenImagePreview(imagePath: processedImage!.path)));
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(title: const Text('Error'), content: Text(message), actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))]),
    );
  }

  void _resetCorners() {
    setState(() {
      _initializeCorners();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close), tooltip: 'Cancel'),
        title: Text(showingPreview ? 'Document Preview' : 'Adjust Document Corners'),
        actions: showingPreview ? _buildPreviewActions() : _buildEditActions(),
      ),
      body: showingPreview ? _buildPreviewBody() : _buildEditBody(),
    );
  }

  List<Widget> _buildEditActions() {
    return [
      IconButton(onPressed: _resetCorners, icon: const Icon(Icons.refresh), tooltip: 'Reset corners'),
      IconButton(
        onPressed: isProcessing ? null : _cropDocument,
        icon: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.edit),
        tooltip: isProcessing ? 'Processing...' : 'Edit Image',
      ),
    ];
  }

  List<Widget> _buildPreviewActions() {
    return [IconButton(onPressed: _backToEdit, icon: const Icon(Icons.edit), tooltip: 'Back to Edit'), IconButton(onPressed: _confirmAndSave, icon: const Icon(Icons.check), tooltip: 'Save Document')];
  }

  Widget _buildEditBody() {
    return DocumentCornerAdjuster(imagePath: widget.imagePath, initialCorners: currentCorners, imageWidth: widget.imageWidth, imageHeight: widget.imageHeight, onCornersChanged: _onCornersChanged);
  }

  Widget _buildPreviewBody() {
    if (processedImage == null) return const SizedBox();

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GestureDetector(
                onTap: _showFullScreenPreview,
                child: Container(
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.white.withOpacity(0.1), blurRadius: 10, spreadRadius: 2)]),
                  child: ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(processedImage!, fit: BoxFit.contain)),
                ),
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [Icon(Icons.touch_app, color: Colors.white54, size: 20), SizedBox(width: 8), Text('Tap image for full-screen preview', style: TextStyle(color: Colors.white54, fontSize: 14))],
          ),
        ),
      ],
    );
  }
}

// Full-screen image preview widget
class _FullScreenImagePreview extends StatelessWidget {
  final String imagePath;

  const _FullScreenImagePreview({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Document Preview'),
        leading: IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close)),
      ),
      body: Center(child: InteractiveViewer(minScale: 0.5, maxScale: 4.0, child: Image.file(File(imagePath), fit: BoxFit.contain))),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.black,
        child: const Row(
          children: [Icon(Icons.zoom_in, color: Colors.white54, size: 20), SizedBox(width: 8), Text('Pinch to zoom, drag to pan', style: TextStyle(color: Colors.white54, fontSize: 14))],
        ),
      ),
    );
  }
}
