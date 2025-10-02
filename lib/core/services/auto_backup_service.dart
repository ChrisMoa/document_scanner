import 'package:flutter/material.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/services/nextcloud_service.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/services/encryption_service.dart';
import 'dart:typed_data';
import 'dart:io';

class AutoBackupService {
  static const String _autoBackupKey = 'auto_backup_enabled';
  static const String _autoBackupFolderKey = 'auto_backup_folder_id';

  /// Check if auto backup is enabled
  static bool get isAutoBackupEnabled {
    final enabled = StorageService.settingsBox.get(_autoBackupKey, defaultValue: 'false') == 'true';
    debugPrint('🔄 Auto backup enabled: $enabled');
    return enabled;
  }

  /// Upload a document to Nextcloud regardless of auto-backup setting.
  /// Returns true if upload succeeds.
  static Future<bool> uploadDocumentNow(DocumentModel document) async {
    if (!NextcloudService.isAuthenticated) {
      debugPrint('❌ Nextcloud not authenticated, cannot upload now: ${document.name}');
      return false;
    }

    if (document.isUploaded) {
      debugPrint('⏭️ Document already uploaded, skipping: ${document.name}');
      return true;
    }

    try {
      Uint8List? dataToUpload;
      String fileName;

      if (document.pdfPath != null && await _fileExists(document.pdfPath!)) {
        final pdfFile = File(document.pdfPath!);
        dataToUpload = await pdfFile.readAsBytes();
        fileName = '${document.name}.pdf';
      } else {
        debugPrint('❌ Upload now: PDF not found at ${document.pdfPath}');
        return false;
      }

      if (EncryptionService.isEncryptionEnabled && EncryptionService.hasUserKey) {
        final encryptedData = await EncryptionService.encryptData(dataToUpload);
        if (encryptedData != null) {
          dataToUpload = encryptedData;
          fileName = '$fileName.encrypted';
        }
      }

      // Ensure/resolve backup folder
      String? folderId = autoBackupFolderId ?? await createBackupFolder();

      String? cloudUrl;
      if (folderId != null) {
        cloudUrl = await NextcloudService.uploadFile(dataToUpload, fileName, folderId: folderId);
        if (cloudUrl == null) {
          // fallback to root
          cloudUrl = await NextcloudService.uploadFile(dataToUpload, fileName);
        }
      } else {
        cloudUrl = await NextcloudService.uploadFile(dataToUpload, fileName);
      }

      if (cloudUrl != null) {
        debugPrint('✅ Immediate upload successful: $cloudUrl');
        return true;
      }
      debugPrint('❌ Immediate upload failed for ${document.name}');
      return false;
    } catch (e) {
      debugPrint('❌ Immediate upload error for ${document.name}: $e');
      return false;
    }
  }

  /// Enable or disable auto backup
  static Future<void> setAutoBackupEnabled(bool enabled) async {
    await StorageService.settingsBox.put(_autoBackupKey, enabled.toString());
    debugPrint('🔄 Auto backup ${enabled ? 'enabled' : 'disabled'}');
  }

  /// Get the auto backup folder ID (if user created a specific folder)
  static String? get autoBackupFolderId {
    return StorageService.settingsBox.get(_autoBackupFolderKey);
  }

  /// Set the auto backup folder ID
  static Future<void> setAutoBackupFolderId(String? folderId) async {
    if (folderId != null) {
      await StorageService.settingsBox.put(_autoBackupFolderKey, folderId);
    } else {
      await StorageService.settingsBox.delete(_autoBackupFolderKey);
    }
    debugPrint('🔄 Auto backup folder ID set to: $folderId');
  }

  /// Automatically backup a document if auto backup is enabled
  static Future<bool> autoBackupDocument(DocumentModel document) async {
    if (!isAutoBackupEnabled) {
      debugPrint('🔄 Auto backup disabled, skipping document: ${document.name}');
      return false;
    }

    if (!NextcloudService.isAuthenticated) {
      debugPrint('🔄 Nextcloud not authenticated, skipping auto backup for: ${document.name}');
      return false;
    }

    if (document.isUploaded) {
      debugPrint('🔄 Document already uploaded, skipping: ${document.name}');
      return false;
    }

    debugPrint('🔄 Starting auto backup for document: ${document.name}');
    debugPrint('📄 Document PDF path: ${document.pdfPath}');

    try {
      Uint8List? dataToUpload;
      String fileName;

      // Prepare data for upload (PDF preferred)
      if (document.pdfPath != null && await _fileExists(document.pdfPath!)) {
        debugPrint('📄 Auto backup: Using existing PDF file at ${document.pdfPath}');
        final pdfFile = File(document.pdfPath!);
        final fileSize = await pdfFile.length();
        debugPrint('📊 PDF file size: $fileSize bytes');

        dataToUpload = await pdfFile.readAsBytes();
        fileName = '${document.name}.pdf';
        debugPrint('✅ PDF data loaded: ${dataToUpload.length} bytes');
      } else {
        debugPrint('❌ Auto backup: PDF not found at ${document.pdfPath}');
        debugPrint('🔍 File exists check: ${document.pdfPath != null ? await _fileExists(document.pdfPath!) : false}');
        return false;
      }

      // Add encryption if enabled
      if (EncryptionService.isEncryptionEnabled && EncryptionService.hasUserKey) {
        debugPrint('🔒 Auto backup: Encrypting data before upload');
        final encryptedData = await EncryptionService.encryptData(dataToUpload);

        if (encryptedData != null) {
          dataToUpload = encryptedData;
          fileName = '$fileName.encrypted';
          debugPrint('✅ Data encrypted for upload: ${dataToUpload.length} bytes');
        } else {
          debugPrint('❌ Encryption failed, uploading without encryption');
        }
      }

      debugPrint('☁️ Auto backup: Uploading to Nextcloud: $fileName (${dataToUpload.length} bytes)');

      // Get backup folder ID, create if needed
      String? folderId = autoBackupFolderId;

      // Upload to Nextcloud (try with backup folder first, fallback to root)
      String? cloudUrl;

      if (folderId != null) {
        debugPrint('📁 Attempting upload to backup folder: $folderId');
        cloudUrl = await NextcloudService.uploadFile(dataToUpload, fileName, folderId: folderId);

        if (cloudUrl == null) {
          debugPrint('❌ Upload to backup folder failed, clearing invalid folder ID');
          await setAutoBackupFolderId(null); // Clear invalid folder ID
          folderId = null;
        }
      }

      // If folder upload failed or no folder, try creating/finding folder and upload again
      if (cloudUrl == null) {
        debugPrint('📁 Creating/finding backup folder...');
        folderId = await createBackupFolder();

        if (folderId != null) {
          debugPrint('📁 Retrying upload to backup folder: $folderId');
          cloudUrl = await NextcloudService.uploadFile(dataToUpload, fileName, folderId: folderId);
        }

        // Final fallback: upload to root
        if (cloudUrl == null) {
          debugPrint('📁 Fallback: uploading to Nextcloud root');
          cloudUrl = await NextcloudService.uploadFile(dataToUpload, fileName);
        }
      }

      if (cloudUrl != null) {
        debugPrint('✅ Auto backup successful: $cloudUrl');
        return true;
      } else {
        debugPrint('❌ Auto backup failed - no URL returned');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Auto backup failed for ${document.name}: $e');
      return false;
    }
  }

  /// Create a dedicated backup folder in Nextcloud
  static Future<String?> createBackupFolder() async {
    if (!NextcloudService.isAuthenticated) {
      debugPrint('❌ Cannot create backup folder - Nextcloud not authenticated');
      return null;
    }

    try {
      debugPrint('📁 Setting up backup folder in Nextcloud...');

      // Check if we already have a folder ID saved
      final existingFolderId = autoBackupFolderId;
      if (existingFolderId != null) {
        debugPrint('📁 Using existing backup folder ID: $existingFolderId');
        return existingFolderId;
      }

      // Create or find the backup folder
      final folderData = await NextcloudService.createFolder('Document Scanner Backup');

      if (folderData != null) {
        final folderId = folderData['id'] as String;
        await setAutoBackupFolderId(folderId);
        debugPrint('✅ Backup folder ready with ID: $folderId');
        return folderId;
      }
    } catch (e) {
      debugPrint('❌ Error setting up backup folder: $e');
    }

    return null;
  }

  /// Manually synchronize all documents with PDFs to Nextcloud
  static Future<Map<String, dynamic>> synchronizeAllDocuments() async {
    debugPrint('🔄 Starting manual synchronization of all documents...');

    if (!NextcloudService.isAuthenticated) {
      debugPrint('❌ Nextcloud not authenticated for sync');
      return {'success': false, 'message': 'Nextcloud not connected', 'uploaded': 0, 'failed': 0, 'skipped': 0};
    }

    // Ensure backup folder exists
    final folderId = await createBackupFolder();
    if (folderId == null) {
      debugPrint('❌ Could not create/access backup folder');
      return {'success': false, 'message': 'Could not access backup folder', 'uploaded': 0, 'failed': 0, 'skipped': 0};
    }

    final allDocuments = StorageService.documentsBox.values.toList();
    int uploaded = 0, failed = 0, skipped = 0;

    debugPrint('📋 Found ${allDocuments.length} documents to check for sync');

    for (final document in allDocuments) {
      try {
        if (document.pdfPath == null) {
          debugPrint('⏭️ Skipping document without PDF: ${document.name}');
          skipped++;
          continue;
        }

        if (document.isUploaded) {
          debugPrint('⏭️ Document already uploaded: ${document.name}');
          skipped++;
          continue;
        }

        debugPrint('🔄 Uploading document (manual sync): ${document.name}');
        final success = await uploadDocumentNow(document);

        if (success) {
          // Mark document as uploaded
          final updatedDocument = document.copyWith(isUploaded: true);
          await StorageService.documentsBox.put(updatedDocument.id, updatedDocument);
          uploaded++;
          debugPrint('✅ Successfully uploaded: ${document.name}');
        } else {
          failed++;
          debugPrint('❌ Failed to upload: ${document.name}');
        }
      } catch (e) {
        failed++;
      }
    }

    final message = 'Sync complete: $uploaded uploaded, $skipped skipped, $failed failed';
    debugPrint('📊 $message');

    return {'success': failed == 0, 'message': message, 'uploaded': uploaded, 'failed': failed, 'skipped': skipped, 'total': allDocuments.length};
  }

  /// Helper method to check if file exists
  static Future<bool> _fileExists(String path) async {
    try {
      return await File(path).exists();
    } catch (e) {
      return false;
    }
  }

  /// Get backup statistics
  static Future<Map<String, dynamic>> getBackupStats() async {
    try {
      final allDocuments = StorageService.documentsBox.values.toList();
      final totalDocuments = allDocuments.length;
      final uploadedDocuments = allDocuments.where((doc) => doc.isUploaded).length;
      final pendingDocuments = totalDocuments - uploadedDocuments;

      return {'total': totalDocuments, 'uploaded': uploadedDocuments, 'pending': pendingDocuments, 'autoBackupEnabled': isAutoBackupEnabled, 'oneDriveConnected': NextcloudService.isAuthenticated};
    } catch (e) {
      debugPrint('❌ Error getting backup stats: $e');
      return {'total': 0, 'uploaded': 0, 'pending': 0, 'autoBackupEnabled': false, 'oneDriveConnected': false};
    }
  }
}
