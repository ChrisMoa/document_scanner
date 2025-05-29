import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/services/encryption_service.dart';
import 'package:document_scanner/core/services/pdf_service.dart';
import 'package:document_scanner/core/services/onedrive_service.dart';
import 'package:document_scanner/core/services/auto_backup_service.dart';

class DownloadService {
  static const String _tag = 'DownloadService';

  /// Get available cloud documents from OneDrive
  static Future<List<CloudDocument>> getCloudDocuments() async {
    debugPrint('$_tag: Fetching cloud documents from OneDrive');

    if (!OneDriveService.isAuthenticated) {
      debugPrint('$_tag: OneDrive not authenticated');
      return [];
    }

    try {
      // Get backup folder ID
      final backupFolderId = AutoBackupService.autoBackupFolderId;
      List<Map<String, dynamic>>? files;

      // Try to get files from backup folder first, then root
      if (backupFolderId != null) {
        debugPrint('$_tag: Checking backup folder: $backupFolderId');
        files = await OneDriveService.listFiles(folderId: backupFolderId);
      }

      // If backup folder failed or no files, try root
      if (files == null || files.isEmpty) {
        debugPrint('$_tag: Checking OneDrive root');
        files = await OneDriveService.listFiles();
      }

      if (files == null) {
        debugPrint('$_tag: Failed to get files from OneDrive');
        return [];
      }

      // Filter for PDF files
      final cloudDocs = <CloudDocument>[];
      for (final file in files) {
        final fileName = file['name'] as String?;
        if (fileName != null && (fileName.toLowerCase().endsWith('.pdf') || fileName.toLowerCase().endsWith('.pdf.encrypted'))) {
          final cloudDoc = CloudDocument(
            id: file['id'] as String,
            name: fileName,
            size: file['size'] as int? ?? 0,
            downloadUrl: file['@microsoft.graph.downloadUrl'] as String?,
            isEncrypted: fileName.toLowerCase().endsWith('.encrypted'),
            modifiedTime: DateTime.tryParse(file['lastModifiedDateTime'] as String? ?? '') ?? DateTime.now(),
          );
          cloudDocs.add(cloudDoc);
          debugPrint('$_tag: Found cloud document: $fileName (${cloudDoc.size} bytes)');
        }
      }

      debugPrint('$_tag: Found ${cloudDocs.length} cloud documents');
      return cloudDocs;
    } catch (e) {
      debugPrint('$_tag: Error fetching cloud documents: $e');
      return [];
    }
  }

  /// Download all documents (local + cloud) to a user-selected output folder
  static Future<DownloadResult> downloadAllDocuments(List<DocumentModel> localDocuments) async {
    debugPrint('$_tag: Starting download of ${localDocuments.length} local documents');

    // Also fetch cloud documents
    final cloudDocuments = await getCloudDocuments();
    debugPrint('$_tag: Found ${cloudDocuments.length} cloud documents');

    final totalCount = localDocuments.length + cloudDocuments.length;
    debugPrint('$_tag: Total documents to process: $totalCount (${localDocuments.length} local + ${cloudDocuments.length} cloud)');

    try {
      // Get user's preferred save location as default
      String? defaultPath = StorageService.getSaveLocation();
      if (defaultPath == null) {
        // Fallback to external app storage or default location
        final externalDir = await StorageService.getExternalAppDirectory();
        if (externalDir != null) {
          defaultPath = externalDir;
        } else {
          defaultPath = await StorageService.getDefaultSaveLocation();
        }
      }

      debugPrint('$_tag: Default download location: $defaultPath');

      // Let user select output folder (with default)
      final outputPath = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select Download Folder', initialDirectory: defaultPath);

      if (outputPath == null) {
        debugPrint('$_tag: User cancelled folder selection');
        return DownloadResult(success: false, message: 'Download cancelled by user', downloadedCount: 0);
      }

      debugPrint('$_tag: Selected output folder: $outputPath');

      int downloadedCount = 0;
      int skippedCount = 0;
      List<String> errors = [];
      List<DocumentModel> importedDocuments = [];

      // Process local documents
      for (int i = 0; i < localDocuments.length; i++) {
        final document = localDocuments[i];
        debugPrint('$_tag: Processing local document ${i + 1}/${localDocuments.length}: ${document.name}');

        try {
          final success = await _downloadSingleDocument(document, outputPath);
          if (success) {
            downloadedCount++;
            debugPrint('✅ Downloaded: ${document.name}');
          } else {
            skippedCount++;
            debugPrint('⚠️ Skipped: ${document.name} (no PDF available)');
          }
        } catch (e) {
          errors.add('${document.name}: $e');
          debugPrint('❌ Error downloading ${document.name}: $e');
        }
      }

      // Process cloud documents
      for (int i = 0; i < cloudDocuments.length; i++) {
        final cloudDoc = cloudDocuments[i];
        debugPrint('$_tag: Processing cloud document ${i + 1}/${cloudDocuments.length}: ${cloudDoc.name}');

        try {
          final result = await _downloadAndImportCloudDocument(cloudDoc, outputPath);
          if (result != null) {
            downloadedCount++;
            importedDocuments.add(result);
            debugPrint('✅ Downloaded and imported from cloud: ${cloudDoc.name}');
          } else {
            skippedCount++;
            debugPrint('⚠️ Skipped cloud document: ${cloudDoc.name}');
          }
        } catch (e) {
          errors.add('${cloudDoc.name}: $e');
          debugPrint('❌ Error downloading cloud document ${cloudDoc.name}: $e');
        }
      }

      // Import the downloaded cloud documents into local storage
      if (importedDocuments.isNotEmpty) {
        debugPrint('$_tag: Importing ${importedDocuments.length} downloaded cloud documents into local storage');
        for (final document in importedDocuments) {
          await StorageService.documentsBox.put(document.id, document);
        }
        debugPrint('✅ Successfully imported ${importedDocuments.length} cloud documents');
      }

      final message =
          'Downloaded $downloadedCount documents' +
          (skippedCount > 0 ? ', skipped $skippedCount' : '') +
          (errors.isNotEmpty ? ', ${errors.length} errors' : '') +
          (importedDocuments.isNotEmpty ? '. ${importedDocuments.length} cloud documents imported to app.' : '');

      debugPrint('$_tag: Download completed: $message');
      return DownloadResult(success: downloadedCount > 0, message: message, downloadedCount: downloadedCount, skippedCount: skippedCount, errors: errors);
    } catch (e) {
      debugPrint('$_tag: Download failed: $e');
      return DownloadResult(success: false, message: 'Download failed: $e', downloadedCount: 0);
    }
  }

  /// Download a single document to the output folder
  static Future<bool> _downloadSingleDocument(DocumentModel document, String outputPath) async {
    try {
      Uint8List? dataToDownload;
      String fileName = '${document.name}.pdf';

      // Get PDF data
      if (document.pdfPath != null && await File(document.pdfPath!).exists()) {
        debugPrint('$_tag: Using existing PDF for ${document.name}');
        dataToDownload = await File(document.pdfPath!).readAsBytes();
      } else if (document.imagePaths.isNotEmpty) {
        debugPrint('$_tag: Generating PDF from images for ${document.name}');
        dataToDownload = await PdfService.createPdfFromImages(document.imagePaths, document.name);
      } else {
        debugPrint('$_tag: No PDF or images available for ${document.name}');
        return false;
      }

      if (dataToDownload == null) {
        debugPrint('$_tag: Failed to get PDF data for ${document.name}');
        return false;
      }

      // Check if document is encrypted and decrypt if needed
      if (document.isEncrypted && EncryptionService.hasUserKey) {
        debugPrint('$_tag: Decrypting document ${document.name}');
        final decryptedData = await EncryptionService.decryptData(dataToDownload);

        if (decryptedData != null) {
          dataToDownload = decryptedData;
          debugPrint('✅ Successfully decrypted ${document.name}');
        } else {
          debugPrint('❌ Failed to decrypt ${document.name}');
          // Still save the encrypted version with .encrypted extension
          fileName = '${document.name}.encrypted.pdf';
        }
      } else if (document.isEncrypted && !EncryptionService.hasUserKey) {
        debugPrint('⚠️ Document ${document.name} is encrypted but no decryption key available');
        fileName = '${document.name}.encrypted.pdf';
      }

      // Save to output folder
      final outputFile = File(path.join(outputPath, fileName));
      await outputFile.writeAsBytes(dataToDownload);

      final fileSize = await outputFile.length();
      debugPrint('✅ Saved ${document.name} to ${outputFile.path} (${fileSize} bytes)');

      return true;
    } catch (e) {
      debugPrint('❌ Error downloading ${document.name}: $e');
      rethrow;
    }
  }

  /// Download a cloud document from OneDrive to the output folder
  static Future<bool> _downloadCloudDocument(CloudDocument cloudDoc, String outputPath) async {
    try {
      debugPrint('$_tag: Downloading cloud document: ${cloudDoc.name} (${cloudDoc.size} bytes)');

      // Download file data from OneDrive
      final fileData = await OneDriveService.downloadFile(cloudDoc.id);
      if (fileData == null) {
        debugPrint('$_tag: Failed to download cloud document: ${cloudDoc.name}');
        return false;
      }

      Uint8List dataToSave = fileData;
      String fileName = cloudDoc.displayName;

      // Handle decryption if file is encrypted
      if (cloudDoc.isEncrypted && EncryptionService.hasUserKey) {
        debugPrint('$_tag: Decrypting cloud document: ${cloudDoc.name}');
        final decryptedData = await EncryptionService.decryptData(fileData);

        if (decryptedData != null) {
          dataToSave = decryptedData;
          debugPrint('✅ Successfully decrypted cloud document: ${cloudDoc.name}');
        } else {
          debugPrint('❌ Failed to decrypt cloud document: ${cloudDoc.name}');
          // Save encrypted version with .encrypted extension
          fileName = '${cloudDoc.displayName}.encrypted';
        }
      } else if (cloudDoc.isEncrypted && !EncryptionService.hasUserKey) {
        debugPrint('⚠️ Cloud document ${cloudDoc.name} is encrypted but no decryption key available');
        fileName = '${cloudDoc.displayName}.encrypted';
      }

      // Ensure .pdf extension
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }

      // Save to output folder
      final outputFile = File(path.join(outputPath, fileName));
      await outputFile.writeAsBytes(dataToSave);

      final fileSize = await outputFile.length();
      debugPrint('✅ Saved cloud document to ${outputFile.path} (${fileSize} bytes)');

      return true;
    } catch (e) {
      debugPrint('❌ Error downloading cloud document ${cloudDoc.name}: $e');
      rethrow;
    }
  }

  /// Download a cloud document and create a DocumentModel for import
  static Future<DocumentModel?> _downloadAndImportCloudDocument(CloudDocument cloudDoc, String outputPath) async {
    try {
      debugPrint('$_tag: Downloading and importing cloud document: ${cloudDoc.name} (${cloudDoc.size} bytes)');

      // Download file data from OneDrive
      final fileData = await OneDriveService.downloadFile(cloudDoc.id);
      if (fileData == null) {
        debugPrint('$_tag: Failed to download cloud document: ${cloudDoc.name}');
        return null;
      }

      Uint8List dataToSave = fileData;
      String fileName = cloudDoc.displayName;
      bool isDecrypted = false;

      // Handle decryption if file is encrypted
      if (cloudDoc.isEncrypted && EncryptionService.hasUserKey) {
        debugPrint('$_tag: Decrypting cloud document: ${cloudDoc.name}');
        final decryptedData = await EncryptionService.decryptData(fileData);

        if (decryptedData != null) {
          dataToSave = decryptedData;
          isDecrypted = true;
          debugPrint('✅ Successfully decrypted cloud document: ${cloudDoc.name}');
        } else {
          debugPrint('❌ Failed to decrypt cloud document: ${cloudDoc.name}');
          // Save encrypted version with .encrypted extension
          fileName = '${cloudDoc.displayName}.encrypted';
        }
      } else if (cloudDoc.isEncrypted && !EncryptionService.hasUserKey) {
        debugPrint('⚠️ Cloud document ${cloudDoc.name} is encrypted but no decryption key available');
        fileName = '${cloudDoc.displayName}.encrypted';
      }

      // Ensure .pdf extension
      if (!fileName.toLowerCase().endsWith('.pdf')) {
        fileName = '$fileName.pdf';
      }

      // Save to output folder
      final outputFile = File(path.join(outputPath, fileName));
      await outputFile.writeAsBytes(dataToSave);

      final fileSize = await outputFile.length();
      debugPrint('✅ Saved cloud document to ${outputFile.path} (${fileSize} bytes)');

      // Create DocumentModel for import
      final now = DateTime.now();
      final documentId = 'cloud_${cloudDoc.id}_${now.millisecondsSinceEpoch}';

      final document = DocumentModel(
        id: documentId,
        name: cloudDoc.displayName,
        imagePaths: [], // Cloud documents don't have individual images
        pdfPath: outputFile.path,
        createdAt: cloudDoc.modifiedTime,
        updatedAt: now,
        isUploaded: true, // It was downloaded from cloud, so mark as uploaded
        cloudUrl: cloudDoc.downloadUrl,
        isEncrypted: cloudDoc.isEncrypted && !isDecrypted, // Mark as encrypted only if still encrypted
        isDownloaded: true, // Mark as downloaded since we just downloaded it
        storageLocation: StorageService.getStorageLocationDisplayName(outputFile.path),
      );

      debugPrint('✅ Created DocumentModel for cloud document: ${document.name}');
      return document;
    } catch (e) {
      debugPrint('❌ Error downloading and importing cloud document ${cloudDoc.name}: $e');
      rethrow;
    }
  }

  /// Mark documents as downloaded/synced
  static Future<void> markDocumentsAsDownloaded(List<DocumentModel> documents) async {
    debugPrint('$_tag: Marking ${documents.length} documents as downloaded');

    for (final document in documents) {
      try {
        final updatedDocument = document.copyWith(isDownloaded: true);
        await StorageService.documentsBox.put(document.id, updatedDocument);
        debugPrint('✅ Marked ${document.name} as downloaded');
      } catch (e) {
        debugPrint('❌ Error marking ${document.name} as downloaded: $e');
      }
    }
  }

  /// Get download statistics
  static Future<DownloadStats> getDownloadStats(List<DocumentModel> localDocuments) async {
    final cloudDocuments = await getCloudDocuments();

    int totalDocuments = localDocuments.length + cloudDocuments.length;
    int downloadedDocuments = localDocuments.where((doc) => doc.isDownloaded).length;
    int encryptedDocuments = localDocuments.where((doc) => doc.isEncrypted).length + cloudDocuments.where((doc) => doc.isEncrypted).length;
    int availableForDownload = localDocuments.where((doc) => doc.pdfPath != null || doc.imagePaths.isNotEmpty).length + cloudDocuments.length;

    return DownloadStats(
      totalDocuments: totalDocuments,
      downloadedDocuments: downloadedDocuments,
      encryptedDocuments: encryptedDocuments,
      availableForDownload: availableForDownload,
      cloudDocuments: cloudDocuments.length,
      localDocuments: localDocuments.length,
      oneDriveConnected: OneDriveService.isAuthenticated,
    );
  }
}

/// Result of a download operation
class DownloadResult {
  final bool success;
  final String message;
  final int downloadedCount;
  final int skippedCount;
  final List<String> errors;

  DownloadResult({required this.success, required this.message, required this.downloadedCount, this.skippedCount = 0, this.errors = const []});
}

/// Statistics about downloadable documents
class DownloadStats {
  final int totalDocuments;
  final int downloadedDocuments;
  final int encryptedDocuments;
  final int availableForDownload;
  final int cloudDocuments;
  final int localDocuments;
  final bool oneDriveConnected;

  DownloadStats({
    required this.totalDocuments,
    required this.downloadedDocuments,
    required this.encryptedDocuments,
    required this.availableForDownload,
    required this.cloudDocuments,
    required this.localDocuments,
    required this.oneDriveConnected,
  });
}

/// Represents a document stored in OneDrive cloud storage
class CloudDocument {
  final String id;
  final String name;
  final int size;
  final String? downloadUrl;
  final bool isEncrypted;
  final DateTime modifiedTime;

  CloudDocument({required this.id, required this.name, required this.size, this.downloadUrl, required this.isEncrypted, required this.modifiedTime});

  String get displayName {
    // Remove .pdf or .pdf.encrypted extension for display
    String displayName = name;
    if (displayName.toLowerCase().endsWith('.pdf.encrypted')) {
      displayName = displayName.substring(0, displayName.length - 14);
    } else if (displayName.toLowerCase().endsWith('.pdf')) {
      displayName = displayName.substring(0, displayName.length - 4);
    }
    return displayName;
  }
}
