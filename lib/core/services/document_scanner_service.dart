import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cunning_document_scanner/cunning_document_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;
import 'package:document_scanner/core/models/document_model.dart';
import 'package:path/path.dart';

/// Service for document scanning using cunning_document_scanner
class DocumentScannerService {
  static const String _tag = 'DocumentScannerService';
  static final ImagePicker _imagePicker = ImagePicker();

  /// Scans documents using cunning document scanner
  ///
  /// [maxPages] - Maximum number of pages to scan (default: 5)
  /// Returns a list of document models with scanned images
  static Future<List<DocumentModel>> scanDocuments({int maxPages = 5}) async {
    debugPrint('$_tag: Starting cunning document scanner with max pages: $maxPages');

    try {
      final documents = <DocumentModel>[];
      List<String>? scannedImages;

      try {
        // Use cunning document scanner to scan multiple pages at once
        scannedImages = await CunningDocumentScanner.getPictures(
          noOfPages: maxPages, // Allow scanning multiple pages
          isGalleryImportAllowed: true, // Allow gallery import
        );
        debugPrint('$_tag: Cunning scanner result: ${scannedImages?.length ?? 0} images captured');
      } catch (e) {
        debugPrint('$_tag: Cunning scanner failed: $e');
        throw DocumentScannerException('Document scanner failed: $e. Please ensure camera permissions are granted and try again.');
      }

      if (scannedImages != null && scannedImages.isNotEmpty) {
        debugPrint('$_tag: Processing ${scannedImages.length} scanned images');

        // Process each scanned image into separate documents
        for (int i = 0; i < scannedImages.length; i++) {
          final imagePath = scannedImages[i];
          final document = await _processScannedImage(imagePath, i);
          if (document != null) {
            documents.add(document);
            debugPrint('$_tag: Successfully processed image ${i + 1} of ${scannedImages.length}');
          }
        }
      } else {
        debugPrint('$_tag: No images captured');
      }

      if (documents.isEmpty) {
        throw DocumentScannerException('No documents were scanned. Please try again.');
      }

      debugPrint('$_tag: Successfully scanned ${documents.length} documents');
      return documents;
    } catch (e) {
      debugPrint('$_tag: Error during document scanning: $e');
      throw DocumentScannerException('Failed to scan documents: $e');
    }
  }

  /// Scan a single document using cunning document scanner
  static Future<DocumentModel?> scanSingleDocument() async {
    debugPrint('$_tag: Starting single document scan with cunning scanner');

    try {
      List<String>? scannedImages;

      try {
        scannedImages = await CunningDocumentScanner.getPictures(noOfPages: 1, isGalleryImportAllowed: true);
        debugPrint('$_tag: Cunning scanner result: $scannedImages');
      } catch (e) {
        debugPrint('$_tag: Cunning scanner failed: $e');
        throw DocumentScannerException('Document scanner failed: $e. Please ensure camera permissions are granted and try again.');
      }

      if (scannedImages != null && scannedImages.isNotEmpty) {
        return await _processScannedImage(scannedImages.first, 0);
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Error during single document scanning: $e');
      throw DocumentScannerException('Failed to scan document: $e');
    }
  }

  /// Scan multiple documents as images
  static Future<List<String>> scanDocumentsAsImages({int maxPages = 5}) async {
    debugPrint('$_tag: Starting image scanning with max pages: $maxPages');

    try {
      final allImagePaths = <String>[];

      try {
        // Use cunning document scanner to get multiple images at once
        final scannedImages = await CunningDocumentScanner.getPictures(noOfPages: maxPages, isGalleryImportAllowed: true);

        if (scannedImages != null && scannedImages.isNotEmpty) {
          debugPrint('$_tag: Cunning scanner captured ${scannedImages.length} images');

          // Process and save all scanned images
          for (int i = 0; i < scannedImages.length; i++) {
            final processedPath = await _processAndSaveImage(scannedImages[i], i);
            if (processedPath != null) {
              allImagePaths.add(processedPath);
            }
          }
        }
      } catch (e) {
        debugPrint('$_tag: Cunning scanner failed: $e');
        throw DocumentScannerException('Document scanner failed: $e. Please ensure camera permissions are granted and try again.');
      }

      debugPrint('$_tag: Successfully processed ${allImagePaths.length} images');
      return allImagePaths;
    } catch (e) {
      debugPrint('$_tag: Error during image scanning: $e');
      throw DocumentScannerException('Failed to scan images: $e');
    }
  }

  /// Scan documents and create a PDF
  static Future<String?> scanDocumentsAsPdf({int maxPages = 5}) async {
    debugPrint('$_tag: Starting PDF document scan with max pages: $maxPages');

    try {
      // First scan the images
      final imagePaths = await scanDocumentsAsImages(maxPages: maxPages);

      if (imagePaths.isEmpty) {
        debugPrint('$_tag: No images captured for PDF');
        return null;
      }

      // Create PDF from the captured images
      final pdfData = await _createPdfFromImages(imagePaths);

      if (pdfData == null) {
        debugPrint('$_tag: Failed to create PDF from images');
        return null;
      }

      // Save the PDF
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = 'scanned_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final pdfPath = join(appDocDir.path, fileName);
      final pdfFile = File(pdfPath);

      await pdfFile.writeAsBytes(pdfData);

      final fileSize = await pdfFile.length();
      debugPrint('$_tag: PDF created successfully: $pdfPath (${fileSize} bytes)');

      return pdfPath;
    } catch (e) {
      debugPrint('$_tag: Error during PDF scanning: $e');
      return null;
    }
  }

  /// Scan from gallery using cunning document scanner
  static Future<DocumentModel?> scanFromGallery() async {
    debugPrint('$_tag: Starting gallery scan with cunning scanner');

    try {
      List<String>? scannedImages;

      try {
        // Cunning scanner allows gallery import when isGalleryImportAllowed is true
        // User can choose gallery option within the scanner interface
        scannedImages = await CunningDocumentScanner.getPictures(noOfPages: 1, isGalleryImportAllowed: true);
        debugPrint('$_tag: Cunning scanner gallery result: $scannedImages');
      } catch (e) {
        debugPrint('$_tag: Cunning scanner gallery failed: $e');

        // Fallback to regular gallery selection for gallery import
        final imageFile = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 100);

        if (imageFile != null) {
          scannedImages = [imageFile.path];
          debugPrint('$_tag: Gallery fallback successful');
        }
      }

      if (scannedImages != null && scannedImages.isNotEmpty) {
        return await _processScannedImage(scannedImages.first, 0);
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Error during gallery scan: $e');
      throw DocumentScannerException('Failed to scan from gallery: $e');
    }
  }

  /// Process a scanned image and create a DocumentModel
  static Future<DocumentModel?> _processScannedImage(String imagePath, int index) async {
    try {
      debugPrint('$_tag: Processing scanned image: $imagePath');

      final file = File(imagePath);

      if (!await file.exists()) {
        debugPrint('$_tag: Scanned image file does not exist: $imagePath');
        return null;
      }

      final fileSize = await file.length();
      if (fileSize < 1000) {
        debugPrint('$_tag: Scanned image file too small: $imagePath ($fileSize bytes)');
        return null;
      }

      debugPrint('$_tag: Image file verified - size: $fileSize bytes');

      // The image is already processed by cunning_document_scanner
      // We can optionally enhance it further or use it as-is
      final processedImagePath = await _enhanceImage(imagePath, index) ?? imagePath;

      // Create document model
      final document = DocumentModel(
        id: 'scan_${DateTime.now().millisecondsSinceEpoch}_$index',
        name:
            'Scanned_Document_${index + 1}_${DateTime.now().day}_${DateTime.now().month}_${DateTime.now().year}_${DateTime.now().hour.toString().padLeft(2, '0')}_${DateTime.now().minute.toString().padLeft(2, '0')}',
        imagePaths: [processedImagePath],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      debugPrint('$_tag: Processed scanned image successfully: ${document.id}');
      return document;
    } catch (e) {
      debugPrint('$_tag: Error processing scanned image: $e');
      return null;
    }
  }

  /// Process and save an image
  static Future<String?> _processAndSaveImage(String imagePath, int index) async {
    try {
      debugPrint('$_tag: Processing image: $imagePath');

      final file = File(imagePath);

      if (!await file.exists()) {
        debugPrint('$_tag: Image file does not exist: $imagePath');
        return null;
      }

      // The image is already processed by cunning_document_scanner
      // We can optionally enhance it further or use it as-is
      final enhancedPath = await _enhanceImage(imagePath, index);

      if (enhancedPath == null) {
        debugPrint('$_tag: Using original image (enhancement failed)');
        return imagePath;
      }

      return enhancedPath;
    } catch (e) {
      debugPrint('$_tag: Error processing image: $e');
      return imagePath; // Return original on error
    }
  }

  /// Enhance an image with basic processing (optional)
  static Future<String?> _enhanceImage(String imagePath, int index) async {
    try {
      debugPrint('$_tag: Enhancing image: $imagePath');

      final imageBytes = await File(imagePath).readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        debugPrint('$_tag: Failed to decode image');
        return null;
      }

      // Apply basic enhancements (optional - cunning_document_scanner already processes the image)
      var enhanced = image;

      // Light sharpening only since cunning_document_scanner already did the heavy lifting
      enhanced = img.convolution(enhanced, filter: [0, -0.5, 0, -0.5, 3, -0.5, 0, -0.5, 0]);

      // Save the enhanced image
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = 'enhanced_${DateTime.now().millisecondsSinceEpoch}_$index.jpg';
      final enhancedPath = join(appDocDir.path, fileName);

      final enhancedBytes = img.encodeJpg(enhanced, quality: 95);
      await File(enhancedPath).writeAsBytes(enhancedBytes);

      debugPrint('$_tag: Image enhanced and saved: $enhancedPath');
      return enhancedPath;
    } catch (e) {
      debugPrint('$_tag: Error enhancing image: $e');
      return null;
    }
  }

  /// Create PDF from captured images
  static Future<Uint8List?> _createPdfFromImages(List<String> imagePaths) async {
    try {
      debugPrint('$_tag: Creating PDF from ${imagePaths.length} images');

      final pdf = pw.Document();

      for (int i = 0; i < imagePaths.length; i++) {
        final imagePath = imagePaths[i];
        debugPrint('$_tag: Adding image $i to PDF: $imagePath');

        try {
          final imageFile = File(imagePath);
          if (await imageFile.exists()) {
            final imageBytes = await imageFile.readAsBytes();
            final image = pw.MemoryImage(imageBytes);

            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                build: (pw.Context context) {
                  return pw.Center(child: pw.Image(image, fit: pw.BoxFit.contain));
                },
              ),
            );

            debugPrint('$_tag: Successfully added image $i to PDF (${imageBytes.length} bytes)');
          } else {
            debugPrint('$_tag: Image file does not exist: $imagePath');
          }
        } catch (e) {
          debugPrint('$_tag: Error adding image $i to PDF: $e');
        }
      }

      final pdfBytes = await pdf.save();
      debugPrint('$_tag: PDF created successfully with ${pdfBytes.length} bytes');

      return pdfBytes;
    } catch (e) {
      debugPrint('$_tag: Error creating PDF from images: $e');
      return null;
    }
  }

  /// Create PDF from captured images (public method)
  static Future<Uint8List?> createPdfFromImagePaths(List<String> imagePaths) async {
    return await _createPdfFromImages(imagePaths);
  }

  /// Manual camera capture fallback
  static Future<DocumentModel?> captureDocumentManually() async {
    debugPrint('$_tag: Starting manual document capture');

    try {
      final imageFile = await _imagePicker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.rear, imageQuality: 100);

      if (imageFile != null) {
        return await _processScannedImage(imageFile.path, 0);
      }

      return null;
    } catch (e) {
      debugPrint('$_tag: Error during manual capture: $e');
      throw DocumentScannerException('Failed to capture document manually: $e');
    }
  }

  /// Add new pages to an existing document
  ///
  /// [existingDocument] - The document to add pages to
  /// [maxNewPages] - Maximum number of new pages to scan (default: 5)
  /// Returns the updated document with new pages added
  static Future<DocumentModel?> addPagesToDocument(DocumentModel existingDocument, {int maxNewPages = 5}) async {
    debugPrint('$_tag: Adding pages to existing document: ${existingDocument.name} (current pages: ${existingDocument.imagePaths.length})');

    try {
      // Scan new pages
      final newImagePaths = await scanDocumentsAsImages(maxPages: maxNewPages);

      if (newImagePaths.isEmpty) {
        debugPrint('$_tag: No new pages scanned');
        return null;
      }

      debugPrint('$_tag: Scanned ${newImagePaths.length} new pages');

      // Combine existing and new image paths
      final allImagePaths = [...existingDocument.imagePaths, ...newImagePaths];
      debugPrint('$_tag: Total pages after adding: ${allImagePaths.length}');

      // Create new PDF with all pages
      final pdfData = await _createPdfFromImages(allImagePaths);

      if (pdfData == null) {
        throw DocumentScannerException('Failed to create PDF from combined images');
      }

      // Save the new PDF (overwrite existing one if it exists)
      final appDocDir = await getApplicationDocumentsDirectory();
      final fileName = 'scanned_document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final newPdfPath = join(appDocDir.path, fileName);
      final pdfFile = File(newPdfPath);

      await pdfFile.writeAsBytes(pdfData);

      final fileSize = await pdfFile.length();
      debugPrint('$_tag: Updated PDF created successfully: $newPdfPath (${fileSize} bytes)');

      // Delete old PDF if it exists
      if (existingDocument.pdfPath != null) {
        try {
          final oldPdfFile = File(existingDocument.pdfPath!);
          if (await oldPdfFile.exists()) {
            await oldPdfFile.delete();
            debugPrint('$_tag: Deleted old PDF: ${existingDocument.pdfPath}');
          }
        } catch (e) {
          debugPrint('$_tag: Warning - could not delete old PDF: $e');
        }
      }

      // Create updated document model
      final updatedDocument = existingDocument.copyWith(imagePaths: allImagePaths, pdfPath: newPdfPath, updatedAt: DateTime.now());

      debugPrint('$_tag: Successfully added ${newImagePaths.length} pages to document');
      return updatedDocument;
    } catch (e) {
      debugPrint('$_tag: Error adding pages to document: $e');
      throw DocumentScannerException('Failed to add pages to document: $e');
    }
  }
}

/// Custom exception for document scanner errors
class DocumentScannerException implements Exception {
  final String message;

  const DocumentScannerException(this.message);

  @override
  String toString() => 'DocumentScannerException: $message';
}
