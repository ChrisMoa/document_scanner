import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:document_scanner/core/services/opencv_service.dart';
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
      // Crop the document using the current corners
      final croppedFile = await OpenCVService().cropDocumentWithCorners(File(widget.imagePath), currentCorners);

      if (croppedFile != null && mounted) {
        // Return the cropped image path
        context.pop(croppedFile.path);
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
        title: const Text('Adjust Document Corners'),
        actions: [IconButton(onPressed: _resetCorners, icon: const Icon(Icons.refresh), tooltip: 'Reset corners')],
      ),
      body: Stack(
        children: [
          // Document corner adjuster
          DocumentCornerAdjuster(imagePath: widget.imagePath, initialCorners: currentCorners, imageWidth: widget.imageWidth, imageHeight: widget.imageHeight, onCornersChanged: _onCornersChanged),

          // Instructions overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black54, Colors.transparent])),
              child: Column(
                children: [
                  const Text('Drag the corner points to adjust the document boundaries', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildCornerLegend('TL', 'Top-Left'),
                      const SizedBox(width: 16),
                      _buildCornerLegend('TR', 'Top-Right'),
                      const SizedBox(width: 16),
                      _buildCornerLegend('BR', 'Bottom-Right'),
                      const SizedBox(width: 16),
                      _buildCornerLegend('BL', 'Bottom-Left'),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black54])),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(heroTag: "cancel", onPressed: () => context.pop(), backgroundColor: Colors.red, child: const Icon(Icons.close)),
                  FloatingActionButton.extended(
                    heroTag: "crop",
                    onPressed: isProcessing ? null : _cropDocument,
                    backgroundColor: Colors.green,
                    icon: isProcessing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.crop),
                    label: Text(isProcessing ? 'Processing...' : 'Crop Document'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerLegend(String label, String description) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle, border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2))),
          child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(height: 4),
        Text(description, style: const TextStyle(color: Colors.white, fontSize: 10), textAlign: TextAlign.center),
      ],
    );
  }
}
