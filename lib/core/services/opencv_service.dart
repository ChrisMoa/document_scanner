import 'dart:io';
import 'dart:math' as math;
import 'package:dartcv4/dartcv.dart' as cv;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class OpenCVService {
  /// Detects and crops a document from an image
  /// Returns the cropped document image as a File
  Future<File?> detectAndCropDocument(File imageFile) async {
    try {
      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Convert to OpenCV Mat
      final mat = cv.Mat.fromList(image.height, image.width, cv.MatType.CV_8UC4, imageBytes.toList());

      // Convert to grayscale
      final gray = cv.Mat.empty();
      cv.cvtColor(mat, cv.COLOR_BGR2GRAY, dst: gray);

      // Apply Gaussian blur
      final blurred = cv.Mat.empty();
      cv.blur(gray, (5, 5), dst: blurred);

      // Edge detection
      final edges = cv.Mat.empty();
      cv.canny(blurred, 75.0, 200.0, edges: edges);

      // Find contours
      final (contours, _) = cv.findContours(edges, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);

      // Find the largest contour by area
      double maxArea = 0;
      cv.VecPoint? documentContour;
      for (var i = 0; i < contours.length; i++) {
        final contour = contours[i];
        final area = cv.contourArea(contour);
        if (area > maxArea) {
          maxArea = area;
          documentContour = contour;
        }
      }

      if (documentContour == null) return null;

      // Approximate the contour to get a simpler polygon
      final epsilon = 0.02 * cv.arcLength(documentContour, true);
      final approx = cv.approxPolyDP(documentContour, epsilon, true);

      // If we have 4 points, we found a document
      if (approx.length == 4) {
        // Order points in top-left, top-right, bottom-right, bottom-left order
        final orderedPoints = _orderPoints(approx);

        // Calculate the width and height of the new image
        final widthA = _distance(orderedPoints[0], orderedPoints[1]);
        final widthB = _distance(orderedPoints[2], orderedPoints[3]);
        final heightA = _distance(orderedPoints[0], orderedPoints[3]);
        final heightB = _distance(orderedPoints[1], orderedPoints[2]);

        final maxWidth = widthA > widthB ? widthA : widthB;
        final maxHeight = heightA > heightB ? heightA : heightB;

        // Create destination points for perspective transform
        final dstPoints = cv.VecPoint2f.fromList([cv.Point2f(0, 0), cv.Point2f(maxWidth - 1, 0), cv.Point2f(maxWidth - 1, maxHeight - 1), cv.Point2f(0, maxHeight - 1)]);

        // Get perspective transform matrix
        final M = cv.getPerspectiveTransform(
          cv.VecPoint.fromList(orderedPoints.map((p) => cv.Point(p.x.toInt(), p.y.toInt())).toList()),
          cv.VecPoint.fromList(dstPoints.map((p) => cv.Point(p.x.toInt(), p.y.toInt())).toList()),
        );

        // Apply perspective transform
        final warped = cv.Mat.empty();
        cv.warpPerspective(mat, M, (maxWidth.toInt(), maxHeight.toInt()), dst: warped);

        // Convert back to image
        final warpedData = warped.data;
        final warpedImage = img.Image.fromBytes(width: maxWidth.toInt(), height: maxHeight.toInt(), bytes: warpedData.buffer);

        // Save to temporary file
        final tempFile = File('${imageFile.path}_cropped.jpg');
        await tempFile.writeAsBytes(img.encodeJpg(warpedImage));

        // Clean up
        mat.dispose();
        gray.dispose();
        blurred.dispose();
        edges.dispose();
        warped.dispose();
        M.dispose();

        return tempFile;
      }

      // Clean up
      mat.dispose();
      gray.dispose();
      blurred.dispose();
      edges.dispose();

      return null;
    } catch (e) {
      debugPrint('Error in detectAndCropDocument: $e');
      return null;
    }
  }

  /// Enhances the image quality
  Future<File?> enhanceImage(File imageFile) async {
    try {
      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Convert to OpenCV Mat
      final mat = cv.Mat.fromList(image.height, image.width, cv.MatType.CV_8UC4, imageBytes.toList());

      // Convert to grayscale
      final gray = cv.Mat.empty();
      cv.cvtColor(mat, cv.COLOR_BGR2GRAY, dst: gray);

      // Apply adaptive histogram equalization
      final clahe = cv.createCLAHE(clipLimit: 2.0, tileGridSize: (8, 8));
      final enhanced = cv.Mat.empty();
      clahe.apply(gray, dst: enhanced);

      // Convert back to color
      final enhancedColor = cv.Mat.empty();
      cv.cvtColor(enhanced, cv.COLOR_GRAY2BGR, dst: enhancedColor);

      // Apply bilateral filter for noise reduction while preserving edges
      final filtered = cv.Mat.empty();
      cv.bilateralFilter(enhancedColor, 9, 75.0, 75.0, dst: filtered);

      // Convert back to image
      final filteredData = filtered.data;
      final filteredImage = img.Image.fromBytes(width: image.width, height: image.height, bytes: filteredData.buffer);

      // Save to temporary file
      final tempFile = File('${imageFile.path}_enhanced.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(filteredImage));

      // Clean up
      mat.dispose();
      gray.dispose();
      enhanced.dispose();
      enhancedColor.dispose();
      filtered.dispose();
      clahe.dispose();

      return tempFile;
    } catch (e) {
      debugPrint('Error in enhanceImage: $e');
      return null;
    }
  }

  /// Adjusts the brightness of an image
  Future<File?> adjustBrightness(File imageFile, double factor) async {
    try {
      // Read the image file
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Convert to OpenCV Mat
      final mat = cv.Mat.fromList(image.height, image.width, cv.MatType.CV_8UC4, imageBytes.toList());

      // Convert to float for better precision
      final floatMat = mat.convertTo(cv.MatType.CV_16FC1, alpha: 1 / 255.0);

      // Multiply by factor to adjust brightness
      final adjusted = floatMat.multiply(factor);

      // Convert back to uint8
      final result = adjusted.convertTo(cv.MatType.CV_8UC1, alpha: 255.0);

      // Convert back to image
      final resultData = result.data;
      final resultImage = img.Image.fromBytes(width: image.width, height: image.height, bytes: resultData.buffer);

      // Save to temporary file
      final tempFile = File('${imageFile.path}_brightness.jpg');
      await tempFile.writeAsBytes(img.encodeJpg(resultImage));

      // Clean up
      mat.dispose();
      floatMat.dispose();
      adjusted.dispose();
      result.dispose();

      return tempFile;
    } catch (e) {
      debugPrint('Error in adjustBrightness: $e');
      return null;
    }
  }

  // Helper function to order points in top-left, top-right, bottom-right, bottom-left order
  List<cv.Point2f> _orderPoints(cv.VecPoint points) {
    final rect = cv.boundingRect(points);
    final center = cv.Point2f(rect.x + rect.width / 2, rect.y + rect.height / 2);

    final ordered = List<cv.Point2f>.filled(4, cv.Point2f(0, 0));
    final tl = List<cv.Point2f>.filled(4, cv.Point2f(0, 0));
    final tr = List<cv.Point2f>.filled(4, cv.Point2f(0, 0));
    final br = List<cv.Point2f>.filled(4, cv.Point2f(0, 0));
    final bl = List<cv.Point2f>.filled(4, cv.Point2f(0, 0));

    for (var i = 0; i < points.length; i++) {
      final point = cv.Point2f(points[i].x.toDouble(), points[i].y.toDouble());
      if (point.x < center.x && point.y < center.y) {
        tl[i] = point;
      } else if (point.x > center.x && point.y < center.y) {
        tr[i] = point;
      } else if (point.x > center.x && point.y > center.y) {
        br[i] = point;
      } else {
        bl[i] = point;
      }
    }

    ordered[0] = tl.firstWhere((p) => p.x != 0 && p.y != 0);
    ordered[1] = tr.firstWhere((p) => p.x != 0 && p.y != 0);
    ordered[2] = br.firstWhere((p) => p.x != 0 && p.y != 0);
    ordered[3] = bl.firstWhere((p) => p.x != 0 && p.y != 0);

    return ordered;
  }

  // Helper function to calculate Euclidean distance between two points
  double _distance(cv.Point2f p1, cv.Point2f p2) {
    final dx = p2.x - p1.x;
    final dy = p2.y - p1.y;
    return math.sqrt(dx * dx + dy * dy);
  }
}
