import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class DocumentCorners {
  final List<Offset> corners;
  final int imageWidth;
  final int imageHeight;

  DocumentCorners({required this.corners, required this.imageWidth, required this.imageHeight});
}

class OpenCVService {
  /// Detects document corners from an image and returns them for manual adjustment
  Future<DocumentCorners?> detectDocumentCorners(File imageFile) async {
    try {
      debugPrint('🔍 Starting simple document corner detection...');

      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('❌ Failed to decode image');
        return null;
      }

      debugPrint('📏 Original image dimensions: ${image.width}x${image.height}');

      // Use simple edge-based detection
      final detectedCorners = await _detectDocumentCornersSimple(image);

      if (detectedCorners.isNotEmpty && detectedCorners.length == 4) {
        debugPrint('✅ Document corners detected successfully: ${detectedCorners.length} corners');
        debugPrint('📍 Detected corners:');
        for (int i = 0; i < detectedCorners.length; i++) {
          debugPrint('   Corner $i: (${detectedCorners[i].dx.toInt()}, ${detectedCorners[i].dy.toInt()})');
        }
        return DocumentCorners(corners: detectedCorners, imageWidth: image.width, imageHeight: image.height);
      } else {
        // Use smart default corners as fallback
        final defaultCorners = _getSmartDefaultCorners(image);
        debugPrint('⚠️ Corner detection failed, using smart default corners');
        debugPrint('📍 Default corners:');
        for (int i = 0; i < defaultCorners.length; i++) {
          debugPrint('   Corner $i: (${defaultCorners[i].dx.toInt()}, ${defaultCorners[i].dy.toInt()})');
        }
        return DocumentCorners(corners: defaultCorners, imageWidth: image.width, imageHeight: image.height);
      }
    } catch (e) {
      debugPrint('❌ Error in detectDocumentCorners: $e');
      // Return smart default corners as fallback
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image != null) {
        final defaultCorners = _getSmartDefaultCorners(image);
        debugPrint('🔄 Using smart default corners as error fallback');
        return DocumentCorners(corners: defaultCorners, imageWidth: image.width, imageHeight: image.height);
      }
      return null;
    }
  }

  /// Simple and reliable document corner detection
  Future<List<Offset>> _detectDocumentCornersSimple(img.Image image) async {
    debugPrint('🔍 Performing simple document corner detection...');

    try {
      // Resize image for processing
      final maxDimension = 400;
      final scale = math.min(maxDimension / image.width, maxDimension / image.height);
      final resized = img.copyResize(image, width: (image.width * scale).round(), height: (image.height * scale).round());

      debugPrint('📏 Processing resized image: ${resized.width}x${resized.height} (scale: ${scale.toStringAsFixed(2)})');

      // Convert to grayscale
      final gray = img.grayscale(resized);

      // Find edges using simple threshold
      final edges = _findEdgesSimple(gray);

      // Find document boundary
      final corners = _findDocumentBoundarySimple(edges, resized.width, resized.height);

      // Scale corners back to original image size
      if (corners.length == 4) {
        final scaledCorners = corners.map((corner) => Offset(corner.dx / scale, corner.dy / scale)).toList();
        debugPrint('✅ Simple document corners detected and scaled back');
        return scaledCorners;
      }

      debugPrint('⚠️ Simple detection could not find 4 corners (found ${corners.length})');
      return [];
    } catch (e) {
      debugPrint('❌ Error in simple corner detection: $e');
      return [];
    }
  }

  /// Simple edge detection
  List<List<bool>> _findEdgesSimple(img.Image image) {
    debugPrint('🔍 Applying simple edge detection...');

    final width = image.width;
    final height = image.height;
    final edges = List.generate(height, (y) => List.filled(width, false));

    // Simple threshold-based edge detection
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final center = image.getPixel(x, y).r;
        final neighbors = [
          image.getPixel(x - 1, y - 1).r,
          image.getPixel(x, y - 1).r,
          image.getPixel(x + 1, y - 1).r,
          image.getPixel(x - 1, y).r,
          image.getPixel(x + 1, y).r,
          image.getPixel(x - 1, y + 1).r,
          image.getPixel(x, y + 1).r,
          image.getPixel(x + 1, y + 1).r,
        ];

        final maxDiff = neighbors.map((n) => (n - center).abs()).reduce(math.max);
        edges[y][x] = maxDiff > 30; // Simple threshold
      }
    }

    debugPrint('✅ Simple edge detection completed');
    return edges;
  }

  /// Simple document boundary detection
  List<Offset> _findDocumentBoundarySimple(List<List<bool>> edges, int width, int height) {
    debugPrint('🔍 Finding document boundary with simple algorithm...');

    // Find edge bounding box
    int minX = width, maxX = 0, minY = height, maxY = 0;
    int edgeCount = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        if (edges[y][x]) {
          minX = math.min(minX, x);
          maxX = math.max(maxX, x);
          minY = math.min(minY, y);
          maxY = math.max(maxY, y);
          edgeCount++;
        }
      }
    }

    debugPrint('📊 Found $edgeCount edges, bounds: ($minX,$minY) to ($maxX,$maxY)');

    if (edgeCount < 100) {
      debugPrint('⚠️ Not enough edges found for detection');
      return [];
    }

    // Calculate the detected region size
    final detectedWidth = maxX - minX;
    final detectedHeight = maxY - minY;
    final imageArea = width * height;
    final detectedArea = detectedWidth * detectedHeight;
    final areaRatio = detectedArea / imageArea;

    debugPrint('📐 Detected region: ${detectedWidth}x$detectedHeight (${(areaRatio * 100).toStringAsFixed(1)}% of image)');

    // If the detected region is too large (> 80% of image), it's probably the entire image
    // In this case, create a reasonable document region instead
    if (areaRatio > 0.8 || detectedWidth > width * 0.9 || detectedHeight > height * 0.9) {
      debugPrint('⚠️ Detected region is too large, creating smart document bounds');

      // Create a document region that's 70% of the image size, centered
      final docWidth = (width * 0.7).round();
      final docHeight = (height * 0.7).round();
      final offsetX = ((width - docWidth) / 2).round();
      final offsetY = ((height - docHeight) / 2).round();

      final corners = [
        Offset(offsetX.toDouble(), offsetY.toDouble()), // top-left
        Offset((offsetX + docWidth).toDouble(), offsetY.toDouble()), // top-right
        Offset((offsetX + docWidth).toDouble(), (offsetY + docHeight).toDouble()), // bottom-right
        Offset(offsetX.toDouble(), (offsetY + docHeight).toDouble()), // bottom-left
      ];

      debugPrint('✅ Created smart document bounds: ${corners.map((c) => '(${c.dx.toInt()}, ${c.dy.toInt()})')}');
      return corners;
    }

    // Use detected bounds with moderate padding
    final paddingX = math.max(10, detectedWidth * 0.1);
    final paddingY = math.max(10, detectedHeight * 0.1);

    final corners = [
      Offset(math.max(0.0, minX.toDouble() - paddingX), math.max(0.0, minY.toDouble() - paddingY)), // top-left
      Offset(math.min(width.toDouble(), maxX.toDouble() + paddingX), math.max(0.0, minY.toDouble() - paddingY)), // top-right
      Offset(math.min(width.toDouble(), maxX.toDouble() + paddingX), math.min(height.toDouble(), maxY.toDouble() + paddingY)), // bottom-right
      Offset(math.max(0.0, minX.toDouble() - paddingX), math.min(height.toDouble(), maxY.toDouble() + paddingY)), // bottom-left
    ];

    debugPrint('✅ Document boundary found with ${corners.length} corners: ${corners.map((c) => '(${c.dx.toInt()}, ${c.dy.toInt()})')}');
    return corners;
  }

  /// Creates a cropped and flattened document from an image using specified corners
  Future<File?> cropDocumentWithCorners(File imageFile, List<Offset> corners) async {
    try {
      debugPrint('📐 Starting document perspective correction...');

      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('❌ Failed to decode image for cropping');
        return null;
      }

      debugPrint('✅ Image loaded for perspective correction: ${image.width}x${image.height}');
      debugPrint('📍 Corner points: ${corners.map((c) => '(${c.dx.toInt()}, ${c.dy.toInt()})')}');

      // Apply perspective transformation
      final correctedImage = await _applyPerspectiveTransformation(image, corners);
      if (correctedImage == null) {
        debugPrint('❌ Failed to apply perspective transformation');
        return null;
      }

      debugPrint('✅ Perspective transformation completed: ${correctedImage.width}x${correctedImage.height}');

      // Apply document enhancement
      final enhanced = await _enhanceDocument(correctedImage);

      // Save to temporary file
      final tempFile = File('${imageFile.path}_cropped.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(enhanced, quality: 95));

      debugPrint('✅ Document perspective correction completed successfully');
      return tempFile;
    } catch (e) {
      debugPrint('❌ Error in cropDocumentWithCorners: $e');
      return null;
    }
  }

  /// Applies perspective transformation to correct document viewing angle
  Future<img.Image?> _applyPerspectiveTransformation(img.Image sourceImage, List<Offset> corners) async {
    try {
      debugPrint('🔄 Applying perspective transformation...');

      if (corners.length != 4) {
        debugPrint('❌ Invalid number of corners: ${corners.length}');
        return null;
      }

      // Order corners: top-left, top-right, bottom-right, bottom-left
      final orderedCorners = _orderCorners(corners);
      debugPrint('📍 Ordered corners: ${orderedCorners.map((c) => '(${c.dx.toInt()}, ${c.dy.toInt()})')}');

      // Calculate destination dimensions for optimal aspect ratio
      final destSize = _calculateDestinationSize(orderedCorners);
      debugPrint('📏 Destination size: ${destSize.width.toInt()}x${destSize.height.toInt()}');

      // Create destination image
      final destImage = img.Image(width: destSize.width.toInt(), height: destSize.height.toInt());

      // Fill with white background
      img.fill(destImage, color: img.ColorRgb8(255, 255, 255));

      // Define destination rectangle corners
      final destCorners = [
        const Offset(0, 0), // top-left
        Offset(destSize.width, 0), // top-right
        Offset(destSize.width, destSize.height), // bottom-right
        Offset(0, destSize.height), // bottom-left
      ];

      // Apply perspective transformation
      for (int y = 0; y < destImage.height; y++) {
        for (int x = 0; x < destImage.width; x++) {
          final destPoint = Offset(x.toDouble(), y.toDouble());
          final sourcePoint = _mapDestinationToSource(destPoint, destCorners, orderedCorners);

          if (sourcePoint != null && sourcePoint.dx >= 0 && sourcePoint.dx < sourceImage.width && sourcePoint.dy >= 0 && sourcePoint.dy < sourceImage.height) {
            // Bilinear interpolation for better quality
            final color = _bilinearInterpolation(sourceImage, sourcePoint);
            destImage.setPixel(x, y, color);
          }
        }
      }

      debugPrint('✅ Perspective transformation applied successfully');
      return destImage;
    } catch (e) {
      debugPrint('❌ Error in perspective transformation: $e');
      return null;
    }
  }

  /// Orders corners in clockwise order starting from top-left
  List<Offset> _orderCorners(List<Offset> corners) {
    // Find center point
    final centerX = corners.map((c) => c.dx).reduce((a, b) => a + b) / 4;
    final centerY = corners.map((c) => c.dy).reduce((a, b) => a + b) / 4;
    final center = Offset(centerX, centerY);

    // Sort corners by angle from center
    final sortedCorners = List<Offset>.from(corners);
    sortedCorners.sort((a, b) {
      final angleA = math.atan2(a.dy - center.dy, a.dx - center.dx);
      final angleB = math.atan2(b.dy - center.dy, b.dx - center.dx);
      return angleA.compareTo(angleB);
    });

    // Find top-left corner (closest to origin)
    int topLeftIndex = 0;
    double minDistance = double.infinity;
    for (int i = 0; i < sortedCorners.length; i++) {
      final distance = sortedCorners[i].dx + sortedCorners[i].dy;
      if (distance < minDistance) {
        minDistance = distance;
        topLeftIndex = i;
      }
    }

    // Reorder starting from top-left
    final orderedCorners = <Offset>[];
    for (int i = 0; i < 4; i++) {
      orderedCorners.add(sortedCorners[(topLeftIndex + i) % 4]);
    }

    return orderedCorners;
  }

  /// Calculates optimal destination size maintaining aspect ratio
  Size _calculateDestinationSize(List<Offset> corners) {
    // Calculate distances between corners
    final topWidth = (corners[1] - corners[0]).distance;
    final bottomWidth = (corners[2] - corners[3]).distance;
    final leftHeight = (corners[3] - corners[0]).distance;
    final rightHeight = (corners[2] - corners[1]).distance;

    // Use maximum dimensions for best quality
    final width = math.max(topWidth, bottomWidth);
    final height = math.max(leftHeight, rightHeight);

    // Ensure minimum dimensions and reasonable aspect ratio
    final minDimension = 200.0;
    final maxDimension = 2000.0;

    final finalWidth = math.max(minDimension, math.min(maxDimension, width));
    final finalHeight = math.max(minDimension, math.min(maxDimension, height));

    return Size(finalWidth, finalHeight);
  }

  /// Maps destination point to source point using perspective transformation
  Offset? _mapDestinationToSource(Offset destPoint, List<Offset> destCorners, List<Offset> sourceCorners) {
    try {
      // Use bilinear interpolation to find corresponding source point
      final x = destPoint.dx / (destCorners[1].dx - destCorners[0].dx);
      final y = destPoint.dy / (destCorners[3].dy - destCorners[0].dy);

      // Interpolate along top and bottom edges
      final topPoint = Offset.lerp(sourceCorners[0], sourceCorners[1], x)!;
      final bottomPoint = Offset.lerp(sourceCorners[3], sourceCorners[2], x)!;

      // Interpolate between top and bottom
      final sourcePoint = Offset.lerp(topPoint, bottomPoint, y)!;

      return sourcePoint;
    } catch (e) {
      return null;
    }
  }

  /// Performs bilinear interpolation for smooth color sampling
  img.Color _bilinearInterpolation(img.Image image, Offset point) {
    final x = point.dx;
    final y = point.dy;

    final x1 = x.floor();
    final y1 = y.floor();
    final x2 = math.min(x1 + 1, image.width - 1);
    final y2 = math.min(y1 + 1, image.height - 1);

    final dx = x - x1;
    final dy = y - y1;

    final c11 = image.getPixel(x1, y1);
    final c12 = image.getPixel(x1, y2);
    final c21 = image.getPixel(x2, y1);
    final c22 = image.getPixel(x2, y2);

    final r = ((1 - dx) * (1 - dy) * c11.r + dx * (1 - dy) * c21.r + (1 - dx) * dy * c12.r + dx * dy * c22.r).round();
    final g = ((1 - dx) * (1 - dy) * c11.g + dx * (1 - dy) * c21.g + (1 - dx) * dy * c12.g + dx * dy * c22.g).round();
    final b = ((1 - dx) * (1 - dy) * c11.b + dx * (1 - dy) * c21.b + (1 - dx) * dy * c12.b + dx * dy * c22.b).round();

    return img.ColorRgb8(r, g, b);
  }

  /// Enhanced document processing for better readability
  Future<img.Image> _enhanceDocument(img.Image image) async {
    debugPrint('🎨 Applying gentle document enhancement...');

    try {
      // Convert to grayscale first for better processing
      final grayscale = img.grayscale(image);
      debugPrint('✅ Converted to grayscale');

      // Apply moderate contrast enhancement for text clarity
      final contrasted = img.adjustColor(
        grayscale,
        contrast: 1.3, // Reduced from 1.8
        brightness: 1.1, // Reduced from 1.3
        gamma: 0.85, // Gentler gamma correction
      );
      debugPrint('✅ Applied gentle contrast enhancement');

      // Apply very subtle text enhancement
      final enhanced = _applySubtleTextEnhancement(contrasted);
      debugPrint('✅ Applied subtle text enhancement');

      debugPrint('✅ Gentle document enhancement completed');
      return enhanced;
    } catch (e) {
      debugPrint('⚠️ Enhancement failed, using basic enhancement: $e');
      return _applyBasicEnhancement(img.grayscale(image));
    }
  }

  /// Applies very subtle text enhancement - just slightly darker text, cleaner background
  img.Image _applySubtleTextEnhancement(img.Image image) {
    debugPrint('📝 Applying subtle text enhancement...');

    final result = img.Image(width: image.width, height: image.height);

    // Very gentle enhancement - just nudge values slightly
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = pixel.r.toInt();

        int newValue;

        // Very subtle enhancement
        if (gray > 220) {
          // Very light areas -> make slightly whiter
          newValue = math.min(255, gray + 15);
        } else if (gray > 180) {
          // Light areas -> keep mostly the same, slight brightening
          newValue = math.min(255, gray + 8);
        } else if (gray > 120) {
          // Mid-tones -> keep exactly the same (preserve readability)
          newValue = gray;
        } else if (gray > 80) {
          // Darker areas -> make slightly darker
          newValue = math.max(0, gray - 8);
        } else {
          // Very dark areas -> make slightly darker
          newValue = math.max(0, gray - 15);
        }

        result.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
      }
    }

    debugPrint('✅ Subtle text enhancement completed');
    return result;
  }

  /// Basic enhancement fallback
  img.Image _applyBasicEnhancement(img.Image image) {
    debugPrint('🔧 Applying basic enhancement fallback...');

    // Apply enhanced contrast and brightness with gamma correction
    final enhanced = img.adjustColor(image, contrast: 1.5, brightness: 1.15, gamma: 0.8);

    // Apply simple thresholding for better text clarity
    final result = img.Image(width: enhanced.width, height: enhanced.height);

    for (int y = 0; y < enhanced.height; y++) {
      for (int x = 0; x < enhanced.width; x++) {
        final pixel = enhanced.getPixel(x, y);
        // Simple threshold - adjust this value to fine-tune text clarity
        const int threshold = 128;
        final newValue = pixel.r > threshold ? 255 : 0;
        result.setPixel(x, y, img.ColorRgb8(newValue, newValue, newValue));
      }
    }

    return result;
  }

  /// Gets smart default corner points based on image analysis
  List<Offset> _getSmartDefaultCorners(img.Image image) {
    final width = image.width.toDouble();
    final height = image.height.toDouble();

    debugPrint('📐 Creating smart default corners for ${width.toInt()}x${height.toInt()} image');

    // Create a document region that's 75% of the image size, centered
    // This ensures corners are not at the very edges where they're hard to reach
    final docWidth = width * 0.75;
    final docHeight = height * 0.75;
    final offsetX = (width - docWidth) / 2;
    final offsetY = (height - docHeight) / 2;

    final corners = [
      Offset(offsetX, offsetY), // top-left
      Offset(offsetX + docWidth, offsetY), // top-right
      Offset(offsetX + docWidth, offsetY + docHeight), // bottom-right
      Offset(offsetX, offsetY + docHeight), // bottom-left
    ];

    debugPrint('📍 Smart default corners created (75% centered region):');
    for (int i = 0; i < corners.length; i++) {
      debugPrint('   Corner $i: (${corners[i].dx.toInt()}, ${corners[i].dy.toInt()})');
    }

    return corners;
  }
}
