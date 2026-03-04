import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'dart:math' as math;

class DocumentCornerAdjuster extends StatefulWidget {
  final String imagePath;
  final List<Offset> initialCorners;
  final int imageWidth;
  final int imageHeight;
  final Function(List<Offset>) onCornersChanged;

  const DocumentCornerAdjuster({super.key, required this.imagePath, required this.initialCorners, required this.imageWidth, required this.imageHeight, required this.onCornersChanged});

  @override
  State<DocumentCornerAdjuster> createState() => _DocumentCornerAdjusterState();
}

class _DocumentCornerAdjusterState extends State<DocumentCornerAdjuster> {
  late List<Offset> corners;
  ui.Image? _image;
  int? _draggingCornerIndex;
  double _scaleFactor = 1.0;
  Offset _imagePosition = Offset.zero;

  @override
  void initState() {
    super.initState();
    _initializeCorners();
    _loadImage();
  }

  void _initializeCorners() {
    // Ensure we always have exactly 4 corners
    if (widget.initialCorners.length == 4) {
      corners = List.from(widget.initialCorners);
    } else {
      // Create default 4 corners if not provided
      final inset = math.min(widget.imageWidth, widget.imageHeight) * 0.1;
      corners = [
        Offset(inset, inset), // top-left
        Offset(widget.imageWidth.toDouble() - inset, inset), // top-right
        Offset(widget.imageWidth.toDouble() - inset, widget.imageHeight.toDouble() - inset), // bottom-right
        Offset(inset, widget.imageHeight.toDouble() - inset), // bottom-left
      ];
    }
    debugPrint('📍 Initialized exactly ${corners.length} corners: ${corners.map((c) => '(${c.dx.toInt()}, ${c.dy.toInt()})')}');
  }

  Future<void> _loadImage() async {
    try {
      final file = File(widget.imagePath);
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      setState(() {
        _image = frame.image;
      });
      debugPrint('✅ Image loaded: ${_image?.width}x${_image?.height}');
    } catch (e) {
      debugPrint('❌ Error loading image: $e');
    }
  }

  void _calculateImageLayout(Size containerSize) {
    if (_image == null) return;

    final imageAspectRatio = widget.imageWidth / widget.imageHeight;
    final containerAspectRatio = containerSize.width / containerSize.height;

    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container - fit to width
      _scaleFactor = containerSize.width / widget.imageWidth;
      final scaledHeight = widget.imageHeight * _scaleFactor;
      _imagePosition = Offset(0, (containerSize.height - scaledHeight) / 2);
    } else {
      // Image is taller than container - fit to height
      _scaleFactor = containerSize.height / widget.imageHeight;
      final scaledWidth = widget.imageWidth * _scaleFactor;
      _imagePosition = Offset((containerSize.width - scaledWidth) / 2, 0);
    }

    debugPrint('📐 Image layout calculated:');
    debugPrint('   Container: ${containerSize.width.toInt()}x${containerSize.height.toInt()}');
    debugPrint('   Image: ${widget.imageWidth}x${widget.imageHeight}');
    debugPrint('   Scale factor: ${_scaleFactor.toStringAsFixed(3)}');
    debugPrint('   Image position: (${_imagePosition.dx.toInt()}, ${_imagePosition.dy.toInt()})');
  }

  Offset _imageToDisplay(Offset imagePoint) {
    final displayPoint = Offset(_imagePosition.dx + imagePoint.dx * _scaleFactor, _imagePosition.dy + imagePoint.dy * _scaleFactor);
    return displayPoint;
  }

  Offset _displayToImage(Offset displayPoint) {
    final imagePoint = Offset((displayPoint.dx - _imagePosition.dx) / _scaleFactor, (displayPoint.dy - _imagePosition.dy) / _scaleFactor);
    return imagePoint;
  }

  int? _getClosestCorner(Offset position) {
    const touchRadius = 50.0; // Larger touch radius for better UX
    int? closestIndex;
    double minDistance = touchRadius;

    debugPrint('🎯 Touch at: (${position.dx.toInt()}, ${position.dy.toInt()})');

    for (int i = 0; i < corners.length; i++) {
      final displayCorner = _imageToDisplay(corners[i]);
      final distance = (displayCorner - position).distance;
      debugPrint('   Corner $i at display (${displayCorner.dx.toInt()}, ${displayCorner.dy.toInt()}) - distance: ${distance.toInt()}px');

      if (distance < minDistance) {
        minDistance = distance;
        closestIndex = i;
      }
    }

    if (closestIndex != null) {
      debugPrint('✅ Selected corner $closestIndex at distance ${minDistance.toInt()}px');
    } else {
      debugPrint('❌ No corner found within ${touchRadius}px radius');
    }
    return closestIndex;
  }

  void _updateCorner(int index, Offset newPosition) {
    if (index < 0 || index >= corners.length) {
      debugPrint('❌ Invalid corner index: $index');
      return;
    }

    final imageCoords = _displayToImage(newPosition);

    // Clamp to image boundaries with some margin
    final margin = 10.0;
    final clampedX = imageCoords.dx.clamp(margin, widget.imageWidth.toDouble() - margin);
    final clampedY = imageCoords.dy.clamp(margin, widget.imageHeight.toDouble() - margin);

    final newCornerPosition = Offset(clampedX, clampedY);

    setState(() {
      corners[index] = newCornerPosition;
    });

    debugPrint('🔄 Updated corner $index: image(${clampedX.toInt()}, ${clampedY.toInt()}) display(${newPosition.dx.toInt()}, ${newPosition.dy.toInt()})');

    // Notify parent of changes
    widget.onCornersChanged(List.from(corners));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = constraints.biggest;
        _calculateImageLayout(containerSize);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onPanStart: (details) {
            final touchPos = details.localPosition;
            debugPrint('👆 Pan start at: (${touchPos.dx.toInt()}, ${touchPos.dy.toInt()})');

            final cornerIndex = _getClosestCorner(touchPos);
            if (cornerIndex != null) {
              setState(() {
                _draggingCornerIndex = cornerIndex;
              });
              debugPrint('🎯 Started dragging corner: $cornerIndex');
            } else {
              debugPrint('⚠️ No corner selected for dragging');
            }
          },
          onPanUpdate: (details) {
            if (_draggingCornerIndex != null) {
              final touchPos = details.localPosition;
              debugPrint('🔄 Pan update for corner $_draggingCornerIndex at: (${touchPos.dx.toInt()}, ${touchPos.dy.toInt()})');
              _updateCorner(_draggingCornerIndex!, touchPos);
            }
          },
          onPanEnd: (details) {
            if (_draggingCornerIndex != null) {
              debugPrint('✋ Pan end for corner: $_draggingCornerIndex');
            }
            setState(() {
              _draggingCornerIndex = null;
            });
          },
          onTapDown: (details) {
            final touchPos = details.localPosition;
            debugPrint('👇 Tap down at: (${touchPos.dx.toInt()}, ${touchPos.dy.toInt()})');
            final cornerIndex = _getClosestCorner(touchPos);
            if (cornerIndex != null) {
              debugPrint('🎯 Tap detected on corner: $cornerIndex');
            }
          },
          child: CustomPaint(
            painter: _DocumentAdjusterPainter(
              image: _image,
              corners: corners,
              imageWidth: widget.imageWidth,
              imageHeight: widget.imageHeight,
              containerSize: containerSize,
              draggingIndex: _draggingCornerIndex,
              scaleFactor: _scaleFactor,
              imagePosition: _imagePosition,
            ),
            size: containerSize,
          ),
        );
      },
    );
  }
}

class _DocumentAdjusterPainter extends CustomPainter {
  final ui.Image? image;
  final List<Offset> corners;
  final int imageWidth;
  final int imageHeight;
  final Size containerSize;
  final int? draggingIndex;
  final double scaleFactor;
  final Offset imagePosition;

  _DocumentAdjusterPainter({
    required this.image,
    required this.corners,
    required this.imageWidth,
    required this.imageHeight,
    required this.containerSize,
    required this.draggingIndex,
    required this.scaleFactor,
    required this.imagePosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (image == null) return;

    // Calculate image display rect
    final imageRect = Rect.fromLTWH(imagePosition.dx, imagePosition.dy, imageWidth * scaleFactor, imageHeight * scaleFactor);

    // Draw the image
    canvas.drawImageRect(image!, Rect.fromLTWH(0, 0, imageWidth.toDouble(), imageHeight.toDouble()), imageRect, Paint()..filterQuality = FilterQuality.high);

    // Convert corners to display coordinates
    final displayCorners =
        corners.map((corner) {
          return Offset(imagePosition.dx + corner.dx * scaleFactor, imagePosition.dy + corner.dy * scaleFactor);
        }).toList();

    // Draw semi-transparent overlay outside the document area
    _drawOverlay(canvas, size, displayCorners);

    // Draw document outline
    _drawDocumentOutline(canvas, displayCorners);

    // Draw grid inside the document area
    _drawGrid(canvas, displayCorners);

    // Draw corner handles
    _drawCornerHandles(canvas, displayCorners);
  }

  void _drawOverlay(Canvas canvas, Size size, List<Offset> displayCorners) {
    final overlayPaint = Paint()..color = Colors.black.withOpacity(0.5);

    // Create path for the document area
    final documentPath = Path();
    if (displayCorners.isNotEmpty) {
      documentPath.moveTo(displayCorners[0].dx, displayCorners[0].dy);
      for (int i = 1; i < displayCorners.length; i++) {
        documentPath.lineTo(displayCorners[i].dx, displayCorners[i].dy);
      }
      documentPath.close();
    }

    // Create path for the entire canvas
    final fullPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    // Subtract document area from full canvas to create overlay
    final overlayPath = Path.combine(PathOperation.difference, fullPath, documentPath);
    canvas.drawPath(overlayPath, overlayPaint);
  }

  void _drawDocumentOutline(Canvas canvas, List<Offset> displayCorners) {
    if (displayCorners.length < 4) return;

    final outlinePaint =
        Paint()
          ..color = Colors.blue
          ..strokeWidth = 3
          ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(displayCorners[0].dx, displayCorners[0].dy);
    for (int i = 1; i < displayCorners.length; i++) {
      path.lineTo(displayCorners[i].dx, displayCorners[i].dy);
    }
    path.close();
    canvas.drawPath(path, outlinePaint);
  }

  void _drawGrid(Canvas canvas, List<Offset> displayCorners) {
    if (displayCorners.length < 4) return;

    final gridPaint =
        Paint()
          ..color = Colors.blue.withOpacity(0.3)
          ..strokeWidth = 1;

    // Draw horizontal grid lines
    for (int i = 1; i < 4; i++) {
      final t = i / 4.0;
      final leftPoint = Offset.lerp(displayCorners[0], displayCorners[3], t)!;
      final rightPoint = Offset.lerp(displayCorners[1], displayCorners[2], t)!;
      canvas.drawLine(leftPoint, rightPoint, gridPaint);
    }

    // Draw vertical grid lines
    for (int i = 1; i < 4; i++) {
      final t = i / 4.0;
      final topPoint = Offset.lerp(displayCorners[0], displayCorners[1], t)!;
      final bottomPoint = Offset.lerp(displayCorners[3], displayCorners[2], t)!;
      canvas.drawLine(topPoint, bottomPoint, gridPaint);
    }
  }

  void _drawCornerHandles(Canvas canvas, List<Offset> displayCorners) {
    final cornerLabels = ['TL', 'TR', 'BR', 'BL'];

    for (int i = 0; i < displayCorners.length; i++) {
      final corner = displayCorners[i];
      final isDragging = draggingIndex == i;

      // Corner circle paint
      final cornerPaint =
          Paint()
            ..color = isDragging ? Colors.orange : Colors.blue
            ..style = PaintingStyle.fill;

      final cornerBorderPaint =
          Paint()
            ..color = Colors.white
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke;

      final radius = isDragging ? 25.0 : 20.0;

      // Draw corner circle
      canvas.drawCircle(corner, radius, cornerPaint);
      canvas.drawCircle(corner, radius, cornerBorderPaint);

      // Draw corner label
      final textPainter = TextPainter(text: TextSpan(text: cornerLabels[i], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)), textDirection: TextDirection.ltr);
      textPainter.layout();
      textPainter.paint(canvas, corner - Offset(textPainter.width / 2, textPainter.height / 2));

      // Draw touch area indicator when dragging
      if (isDragging) {
        final touchAreaPaint =
            Paint()
              ..color = Colors.orange.withOpacity(0.2)
              ..style = PaintingStyle.fill;
        canvas.drawCircle(corner, 50, touchAreaPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
