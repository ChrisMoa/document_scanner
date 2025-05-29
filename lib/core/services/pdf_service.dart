import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:image/image.dart' as img;

class PdfService {
  static Future<Uint8List> createPdfFromImages(List<String> imagePaths, String title) async {
    final pdf = pw.Document();

    debugPrint('📄 Creating PDF from ${imagePaths.length} images:');
    for (int i = 0; i < imagePaths.length; i++) {
      debugPrint('  Image $i: ${imagePaths[i]}');
    }

    if (imagePaths.isEmpty) {
      debugPrint('⚠️ No image paths provided, creating empty PDF');
      throw Exception('No images provided for PDF creation');
    }

    int imagesAdded = 0;
    List<String> failedImages = [];

    for (int i = 0; i < imagePaths.length; i++) {
      final imagePath = imagePaths[i];
      try {
        final imageFile = File(imagePath);
        final exists = await imageFile.exists();
        debugPrint('🔍 Checking image $i: $imagePath - exists: $exists');

        if (exists) {
          final imageBytes = await imageFile.readAsBytes();

          // Validate image size
          if (imageBytes.isEmpty) {
            debugPrint('❌ Image file is empty: $imagePath');
            failedImages.add(imagePath);
            continue;
          }

          // Try to decode the image to ensure it's valid
          final image = img.decodeImage(imageBytes);

          if (image != null) {
            debugPrint('✅ Image decoded successfully: ${image.width}x${image.height}');

            final pdfImage = pw.MemoryImage(imageBytes);

            pdf.addPage(
              pw.Page(
                pageFormat: PdfPageFormat.a4,
                margin: const pw.EdgeInsets.all(20),
                build: (pw.Context context) {
                  return pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain));
                },
              ),
            );
            imagesAdded++;
            debugPrint('✅ Added image $i to PDF: $imagePath');
          } else {
            debugPrint('❌ Failed to decode image $i: $imagePath');
            failedImages.add(imagePath);
          }
        } else {
          debugPrint('❌ Image file not found $i: $imagePath');
          failedImages.add(imagePath);
        }
      } catch (e) {
        debugPrint('❌ Error processing image $i: $imagePath - $e');
        failedImages.add(imagePath);
      }
    }

    debugPrint('📊 PDF creation summary: ${imagesAdded}/${imagePaths.length} images added successfully');

    if (failedImages.isNotEmpty) {
      debugPrint('⚠️ Failed to process ${failedImages.length} images: ${failedImages.join(', ')}');
    }

    if (pdf.document.pdfPageList.pages.isEmpty) {
      debugPrint('⚠️ No valid images found, creating error PDF');
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text('No Valid Images Found', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 20),
                  pw.Text('Total images attempted: ${imagePaths.length}', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Successfully processed: $imagesAdded', style: const pw.TextStyle(fontSize: 12)),
                  pw.Text('Failed to process: ${failedImages.length}', style: const pw.TextStyle(fontSize: 12)),
                  if (failedImages.isNotEmpty) ...[
                    pw.SizedBox(height: 10),
                    pw.Text('Failed image paths:', style: const pw.TextStyle(fontSize: 10)),
                    ...failedImages.take(5).map((path) => pw.Text(path, style: const pw.TextStyle(fontSize: 8))),
                    if (failedImages.length > 5) pw.Text('... and ${failedImages.length - 5} more', style: const pw.TextStyle(fontSize: 8)),
                  ],
                ],
              ),
            );
          },
        ),
      );
    }

    debugPrint('📄 Saving PDF document...');
    final pdfBytes = await pdf.save();
    debugPrint('✅ PDF created successfully, size: ${pdfBytes.length} bytes');

    return pdfBytes;
  }

  static Future<Uint8List> createPdfFromImageData(List<Uint8List> imageDataList, String title) async {
    final pdf = pw.Document();

    for (final imageData in imageDataList) {
      try {
        final image = img.decodeImage(imageData);

        if (image != null) {
          final pdfImage = pw.MemoryImage(imageData);

          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(20),
              build: (pw.Context context) {
                return pw.Center(child: pw.Image(pdfImage, fit: pw.BoxFit.contain));
              },
            ),
          );
        }
      } catch (e) {
        debugPrint('Error adding image data to PDF: $e');
      }
    }

    if (pdf.document.pdfPageList.pages.isEmpty) {
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Center(child: pw.Text('No images found', style: const pw.TextStyle(fontSize: 24)));
          },
        ),
      );
    }

    return await pdf.save();
  }

  static Future<Uint8List> createMultiPagePdf(List<String> imagePaths, String title, {PdfPageFormat? pageFormat, double margin = 20, pw.BoxFit fit = pw.BoxFit.contain}) async {
    final pdf = pw.Document(title: title, author: 'Document Scanner', creator: 'Document Scanner App');

    final format = pageFormat ?? PdfPageFormat.a4;

    for (int i = 0; i < imagePaths.length; i++) {
      try {
        final imagePath = imagePaths[i];
        final imageFile = File(imagePath);

        if (await imageFile.exists()) {
          final imageBytes = await imageFile.readAsBytes();
          final image = img.decodeImage(imageBytes);

          if (image != null) {
            final pdfImage = pw.MemoryImage(imageBytes);

            pdf.addPage(
              pw.Page(
                pageFormat: format,
                margin: pw.EdgeInsets.all(margin),
                build: (pw.Context context) {
                  return pw.Column(
                    children: [
                      if (i == 0) ...[pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 20)],
                      pw.Expanded(child: pw.Image(pdfImage, fit: fit)),
                      pw.SizedBox(height: 10),
                      pw.Text('Page ${i + 1} of ${imagePaths.length}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  );
                },
              ),
            );
          }
        }
      } catch (e) {
        debugPrint('Error processing image ${i + 1}: $e');
      }
    }

    return await pdf.save();
  }

  static Future<pw.ImageProvider?> loadImageFromPath(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        final imageBytes = await imageFile.readAsBytes();
        return pw.MemoryImage(imageBytes);
      }
    } catch (e) {
      debugPrint('Error loading image: $e');
    }
    return null;
  }

  static Future<bool> validateImages(List<String> imagePaths) async {
    for (final imagePath in imagePaths) {
      final file = File(imagePath);
      if (!await file.exists()) {
        return false;
      }

      try {
        final bytes = await file.readAsBytes();
        final image = img.decodeImage(bytes);
        if (image == null) {
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  static String generateFileName(String baseName) {
    final now = DateTime.now();
    final timestamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return '${baseName}_$timestamp.pdf';
  }
}
