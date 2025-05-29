import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class OpenCVDocumentService {
  /// Detects document edges in an image and returns the corner points
  static Future<DocumentCorners?> detectDocumentCorners(String imagePath) async {
    try {
      debugPrint('🔍 Starting document detection for: $imagePath');

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('❌ Image file does not exist: $imagePath');
        return null;
      }

      // Read and decode image
      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('❌ Failed to decode image');
        return null;
      }

      debugPrint('📐 Image dimensions: ${image.width}x${image.height}');

      // Detect document corners
      final corners = await _detectDocumentEdges(image);

      if (corners != null) {
        debugPrint('✅ Document corners detected successfully');
        return DocumentCorners(topLeft: corners[0], topRight: corners[1], bottomRight: corners[2], bottomLeft: corners[3], imageWidth: image.width, imageHeight: image.height);
      } else {
        debugPrint('⚠️ No document detected, using full image bounds');
        // Return full image bounds as fallback
        return DocumentCorners(
          topLeft: Offset(0, 0),
          topRight: Offset(image.width.toDouble(), 0),
          bottomRight: Offset(image.width.toDouble(), image.height.toDouble()),
          bottomLeft: Offset(0, image.height.toDouble()),
          imageWidth: image.width,
          imageHeight: image.height,
        );
      }
    } catch (e) {
      debugPrint('❌ Error in document detection: $e');
      return null;
    }
  }

  /// Detects document edges using contour detection
  static Future<List<Offset>?> _detectDocumentEdges(img.Image image) async {
    try {
      debugPrint('🔍 Performing document edge detection');

      // Convert to grayscale for edge detection
      final grayscale = img.grayscale(image);

      // Apply Gaussian blur to reduce noise
      final blurred = img.gaussianBlur(grayscale, radius: 5);

      // Apply adaptive threshold for better edge detection
      final threshold = _adaptiveThreshold(blurred);

      // Find contours and detect document
      final corners = _findLargestRectangularContour(threshold);

      if (corners != null) {
        debugPrint('✅ Document edges detected');
        return corners;
      }

      debugPrint('⚠️ No rectangular document found');
      return null;
    } catch (e) {
      debugPrint('❌ Edge detection failed: $e');
      return null;
    }
  }

  /// Apply adaptive threshold for better edge detection
  static img.Image _adaptiveThreshold(img.Image image) {
    // Create a binary image using adaptive thresholding
    final result = img.Image.from(image);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final gray = img.getLuminance(pixel);

        // Simple adaptive threshold
        final localMean = _getLocalMean(image, x, y, 15);
        final threshold = localMean - 10;

        if (gray > threshold) {
          result.setPixel(x, y, img.ColorRgb8(255, 255, 255));
        } else {
          result.setPixel(x, y, img.ColorRgb8(0, 0, 0));
        }
      }
    }

    return result;
  }

  /// Get local mean for adaptive thresholding
  static double _getLocalMean(img.Image image, int centerX, int centerY, int windowSize) {
    int sum = 0;
    int count = 0;
    int halfWindow = windowSize ~/ 2;

    for (int y = centerY - halfWindow; y <= centerY + halfWindow; y++) {
      for (int x = centerX - halfWindow; x <= centerX + halfWindow; x++) {
        if (x >= 0 && x < image.width && y >= 0 && y < image.height) {
          final pixel = image.getPixel(x, y);
          sum += img.getLuminance(pixel).round();
          count++;
        }
      }
    }

    return count > 0 ? sum / count : 0;
  }

  /// Find the largest rectangular contour (document)
  static List<Offset>? _findLargestRectangularContour(img.Image binaryImage) {
    // Find edge pixels
    final edgePixels = <Offset>[];

    for (int y = 1; y < binaryImage.height - 1; y++) {
      for (int x = 1; x < binaryImage.width - 1; x++) {
        final current = img.getLuminance(binaryImage.getPixel(x, y));

        // Check if this is an edge pixel by comparing with neighbors
        if (current < 128) {
          // Black pixel
          bool isEdge = false;

          // Check 8-connectivity for edge detection
          for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
              if (dx == 0 && dy == 0) continue;

              final neighbor = img.getLuminance(binaryImage.getPixel(x + dx, y + dy));
              if (neighbor > 128) {
                // White neighbor
                isEdge = true;
                break;
              }
            }
            if (isEdge) break;
          }

          if (isEdge) {
            edgePixels.add(Offset(x.toDouble(), y.toDouble()));
          }
        }
      }
    }

    if (edgePixels.length < 4) {
      debugPrint('⚠️ Not enough edge pixels found: ${edgePixels.length}');
      return null;
    }

    // Find the document corners using convex hull approximation
    final corners = _findDocumentCorners(edgePixels, binaryImage.width, binaryImage.height);

    if (corners != null && corners.length == 4) {
      debugPrint('✅ Found 4 document corners');
      return corners;
    }

    debugPrint('⚠️ Could not find 4 document corners');
    return null;
  }

  /// Find document corners from edge pixels
  static List<Offset>? _findDocumentCorners(List<Offset> edgePixels, int width, int height) {
    if (edgePixels.isEmpty) return null;

    // Find extreme points
    double minX = width.toDouble();
    double maxX = 0;
    double minY = height.toDouble();
    double maxY = 0;

    Offset? topLeft, topRight, bottomLeft, bottomRight;

    for (final point in edgePixels) {
      minX = math.min(minX, point.dx);
      maxX = math.max(maxX, point.dx);
      minY = math.min(minY, point.dy);
      maxY = math.max(maxY, point.dy);
    }

    // Find corner candidates
    final centerX = (minX + maxX) / 2;
    final centerY = (minY + maxY) / 2;

    double minTopLeftDist = double.infinity;
    double minTopRightDist = double.infinity;
    double minBottomLeftDist = double.infinity;
    double minBottomRightDist = double.infinity;

    for (final point in edgePixels) {
      // Top-left corner (minimize distance to top-left)
      final topLeftDist = math.sqrt(math.pow(point.dx - minX, 2) + math.pow(point.dy - minY, 2));
      if (topLeftDist < minTopLeftDist && point.dx < centerX && point.dy < centerY) {
        minTopLeftDist = topLeftDist;
        topLeft = point;
      }

      // Top-right corner
      final topRightDist = math.sqrt(math.pow(point.dx - maxX, 2) + math.pow(point.dy - minY, 2));
      if (topRightDist < minTopRightDist && point.dx > centerX && point.dy < centerY) {
        minTopRightDist = topRightDist;
        topRight = point;
      }

      // Bottom-left corner
      final bottomLeftDist = math.sqrt(math.pow(point.dx - minX, 2) + math.pow(point.dy - maxY, 2));
      if (bottomLeftDist < minBottomLeftDist && point.dx < centerX && point.dy > centerY) {
        minBottomLeftDist = bottomLeftDist;
        bottomLeft = point;
      }

      // Bottom-right corner
      final bottomRightDist = math.sqrt(math.pow(point.dx - maxX, 2) + math.pow(point.dy - maxY, 2));
      if (bottomRightDist < minBottomRightDist && point.dx > centerX && point.dy > centerY) {
        minBottomRightDist = bottomRightDist;
        bottomRight = point;
      }
    }

    // Validate that we found all corners
    if (topLeft != null && topRight != null && bottomLeft != null && bottomRight != null) {
      return [topLeft, topRight, bottomRight, bottomLeft];
    }

    // Fallback: use approximate corners based on bounds
    return [
      Offset(minX, minY), // top-left
      Offset(maxX, minY), // top-right
      Offset(maxX, maxY), // bottom-right
      Offset(minX, maxY), // bottom-left
    ];
  }

  /// Crops and transforms the document based on corner points (removes background, applies perspective correction)
  static Future<Uint8List?> cropAndTransformDocument(String imagePath, DocumentCorners corners) async {
    try {
      debugPrint('✂️ Starting document crop and perspective correction');

      final file = File(imagePath);
      if (!await file.exists()) {
        debugPrint('❌ Image file does not exist: $imagePath');
        return null;
      }

      final imageBytes = await file.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) {
        debugPrint('❌ Failed to decode image');
        return null;
      }

      // Calculate destination dimensions based on document aspect ratio
      final destWidth = _calculateDistance(corners.topLeft, corners.topRight);
      final destHeight = _calculateDistance(corners.topLeft, corners.bottomLeft);

      debugPrint('📐 Destination dimensions: ${destWidth.toInt()}x${destHeight.toInt()}');

      // Apply perspective transform to straighten the document
      final transformed = _perspectiveTransform(image, corners, destWidth.toInt(), destHeight.toInt());

      if (transformed != null) {
        // NO ENHANCEMENT OR FILTERING - Keep original image quality and colors
        debugPrint('✅ Document cropped and perspective corrected - NO FILTERS APPLIED');

        // Encode to JPEG with high quality
        final result = img.encodeJpg(transformed, quality: 95);
        debugPrint('✅ Document cropped and perspective corrected successfully');
        return Uint8List.fromList(result);
      }

      debugPrint('❌ Perspective transform failed');
      return null;
    } catch (e) {
      debugPrint('❌ Error in crop and transform: $e');
      return null;
    }
  }

  static double _calculateDistance(Offset p1, Offset p2) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Apply perspective transformation to correct document orientation
  static img.Image? _perspectiveTransform(img.Image source, DocumentCorners corners, int destWidth, int destHeight) {
    try {
      // Create destination image
      final dest = img.Image(width: destWidth, height: destHeight);

      // Source corners (document corners in original image)
      final srcCorners = [corners.topLeft, corners.topRight, corners.bottomRight, corners.bottomLeft];

      // Destination corners (rectangular document)
      final dstCorners = [
        Offset(0, 0), // top-left
        Offset(destWidth.toDouble(), 0), // top-right
        Offset(destWidth.toDouble(), destHeight.toDouble()), // bottom-right
        Offset(0, destHeight.toDouble()), // bottom-left
      ];

      // For each pixel in destination image, find corresponding source pixel
      for (int y = 0; y < destHeight; y++) {
        for (int x = 0; x < destWidth; x++) {
          // Calculate relative position in destination
          final u = x / destWidth;
          final v = y / destHeight;

          // Bilinear interpolation to find source coordinates
          final srcX = _bilinearInterpolateCoord(srcCorners, u, v, true);
          final srcY = _bilinearInterpolateCoord(srcCorners, u, v, false);

          // Sample from source image if coordinates are valid
          if (srcX >= 0 && srcX < source.width && srcY >= 0 && srcY < source.height) {
            final pixel = _bilinearSample(source, srcX, srcY);
            dest.setPixel(x, y, pixel);
          } else {
            // Fill with white if outside source bounds
            dest.setPixel(x, y, img.ColorRgb8(255, 255, 255));
          }
        }
      }

      return dest;
    } catch (e) {
      debugPrint('❌ Perspective transform error: $e');
      return null;
    }
  }

  /// Interpolate coordinates for perspective transform
  static double _bilinearInterpolateCoord(List<Offset> corners, double u, double v, bool isX) {
    final tl = corners[0]; // top-left
    final tr = corners[1]; // top-right
    final br = corners[2]; // bottom-right
    final bl = corners[3]; // bottom-left

    // Bilinear interpolation
    final top = (1 - u) * (isX ? tl.dx : tl.dy) + u * (isX ? tr.dx : tr.dy);
    final bottom = (1 - u) * (isX ? bl.dx : bl.dy) + u * (isX ? br.dx : br.dy);

    return (1 - v) * top + v * bottom;
  }

  /// Sample pixel with bilinear interpolation
  static img.Color _bilinearSample(img.Image image, double x, double y) {
    final x0 = x.floor();
    final y0 = y.floor();
    final x1 = math.min(x0 + 1, image.width - 1);
    final y1 = math.min(y0 + 1, image.height - 1);

    final fx = x - x0;
    final fy = y - y0;

    final p00 = image.getPixel(x0, y0);
    final p10 = image.getPixel(x1, y0);
    final p01 = image.getPixel(x0, y1);
    final p11 = image.getPixel(x1, y1);

    // Interpolate RGB channels
    final r = _interpolateChannel(p00.r, p10.r, p01.r, p11.r, fx, fy);
    final g = _interpolateChannel(p00.g, p10.g, p01.g, p11.g, fx, fy);
    final b = _interpolateChannel(p00.b, p10.b, p01.b, p11.b, fx, fy);

    return img.ColorRgb8(r.round(), g.round(), b.round());
  }

  static double _interpolateChannel(num v00, num v10, num v01, num v11, double fx, double fy) {
    final v0 = v00 * (1 - fx) + v10 * fx;
    final v1 = v01 * (1 - fx) + v11 * fx;
    return v0 * (1 - fy) + v1 * fy;
  }
}

class DocumentCorners {
  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;
  final int imageWidth;
  final int imageHeight;

  DocumentCorners({required this.topLeft, required this.topRight, required this.bottomRight, required this.bottomLeft, required this.imageWidth, required this.imageHeight});

  List<Offset> get points => [topLeft, topRight, bottomRight, bottomLeft];

  DocumentCorners copyWith({Offset? topLeft, Offset? topRight, Offset? bottomRight, Offset? bottomLeft}) {
    return DocumentCorners(
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomRight: bottomRight ?? this.bottomRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );
  }
}
