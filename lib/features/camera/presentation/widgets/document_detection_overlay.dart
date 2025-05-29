import 'dart:io';
import 'package:flutter/material.dart';
import 'package:document_scanner/core/services/opencv_service.dart';

class DocumentDetectionOverlay extends StatefulWidget {
  final String? lastCapturedImage;
  final bool showDetection;

  const DocumentDetectionOverlay({super.key, this.lastCapturedImage, this.showDetection = true});

  @override
  State<DocumentDetectionOverlay> createState() => _DocumentDetectionOverlayState();
}

class _DocumentDetectionOverlayState extends State<DocumentDetectionOverlay> {
  List<Offset>? _detectedCorners;
  bool _isDetecting = false;

  @override
  void didUpdateWidget(DocumentDetectionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.lastCapturedImage != oldWidget.lastCapturedImage && widget.lastCapturedImage != null && widget.showDetection) {
      _detectDocument();
    }
  }

  Future<void> _detectDocument() async {
    if (_isDetecting || widget.lastCapturedImage == null) return;

    setState(() {
      _isDetecting = true;
    });

    try {
      final file = File(widget.lastCapturedImage!);
      if (await file.exists()) {
        final documentCorners = await OpenCVService().detectDocumentCorners(file);
        if (mounted) {
          setState(() {
            _detectedCorners = documentCorners?.corners;
          });
        }
      }
    } catch (e) {
      debugPrint('Error detecting document: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isDetecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showDetection || _detectedCorners == null) {
      return const SizedBox.shrink();
    }

    return Positioned.fill(child: CustomPaint(painter: _DocumentOverlayPainter(corners: _detectedCorners!, isDetecting: _isDetecting)));
  }
}

class _DocumentOverlayPainter extends CustomPainter {
  final List<Offset> corners;
  final bool isDetecting;

  _DocumentOverlayPainter({required this.corners, required this.isDetecting});

  @override
  void paint(Canvas canvas, Size size) {
    if (corners.isEmpty) return;

    // Convert corners to display coordinates (assuming full screen overlay)
    final displayCorners =
        corners.map((corner) {
          return Offset(
            (corner.dx / 100) * size.width, // Normalize to display size
            (corner.dy / 100) * size.height,
          );
        }).toList();

    // Draw document outline
    final outlinePaint =
        Paint()
          ..color = isDetecting ? Colors.orange : Colors.green
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    final path = Path();
    if (displayCorners.isNotEmpty) {
      path.moveTo(displayCorners[0].dx, displayCorners[0].dy);
      for (int i = 1; i < displayCorners.length; i++) {
        path.lineTo(displayCorners[i].dx, displayCorners[i].dy);
      }
      path.close();
      canvas.drawPath(path, outlinePaint);
    }

    // Draw corner points
    final cornerPaint =
        Paint()
          ..color = isDetecting ? Colors.orange : Colors.green
          ..style = PaintingStyle.fill;

    for (final corner in displayCorners) {
      canvas.drawCircle(corner, 8, cornerPaint);
    }

    // Draw detection status
    if (isDetecting) {
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'Detecting document...',
          style: TextStyle(color: Colors.orange, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black54)]),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, size.height - textPainter.height - 100));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
