import 'dart:io';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/models/scan_session_model.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';
import 'package:document_scanner/core/services/permission_service.dart';

class StorageService {
  static late Box<DocumentModel> _documentsBox;
  static late Box<ScanSessionModel> _scanSessionsBox;
  static late Box<String> _settingsBox;

  static Future<void> initialize() async {
    debugPrint('🔧 Initializing StorageService...');

    Hive.registerAdapter(DocumentModelAdapter());
    Hive.registerAdapter(ScanSessionModelAdapter());

    _documentsBox = await Hive.openBox<DocumentModel>('documents');
    _scanSessionsBox = await Hive.openBox<ScanSessionModel>('scan_sessions');
    _settingsBox = await Hive.openBox<String>('settings');

    debugPrint('✅ StorageService initialized successfully');
  }

  static Box<DocumentModel> get documentsBox => _documentsBox;
  static Box<ScanSessionModel> get scanSessionsBox => _scanSessionsBox;
  static Box<String> get settingsBox => _settingsBox;

  static Future<String> getDefaultSaveLocation() async {
    final directory = await getApplicationDocumentsDirectory();
    final defaultPath = '${directory.path}/DocumentScanner';
    debugPrint('📁 Default save location: $defaultPath');
    return defaultPath;
  }

  /// Get the external storage directory for the app (works on Android 11+)
  static Future<String?> getExternalAppDirectory() async {
    try {
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        debugPrint('📱 External app directory: ${directory.path}');
        return directory.path;
      }
    } catch (e) {
      debugPrint('❌ Error getting external storage directory: $e');
    }
    return null;
  }

  static String? getSaveLocation() {
    final location = _settingsBox.get('save_location');
    debugPrint('🔍 User save location: $location');
    return location;
  }

  static String? getSaveLocationUri() {
    return _settingsBox.get('save_location_uri');
  }

  static Future<void> setSaveLocation(String path) async {
    await _settingsBox.put('save_location', path);
    debugPrint('💾 Save location set to: $path');
  }

  static Future<void> setSaveLocationUri(String uri) async {
    await _settingsBox.put('save_location_uri', uri);
    debugPrint('💾 Save location URI set to: $uri');
  }

  /// Request user to select a directory - ONLY used in settings
  static Future<String?> selectSaveDirectory() async {
    try {
      debugPrint('📁 Requesting user to select save directory...');

      final result = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Select folder to save documents');

      if (result != null) {
        debugPrint('✅ User selected directory: $result');
        await setSaveLocation(result);
        return result;
      } else {
        debugPrint('❌ User cancelled directory selection');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error selecting directory: $e');
      return null;
    }
  }

  static Future<void> ensureDirectoryExists(String path) async {
    final directory = Directory(path);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
      debugPrint('📁 Created directory: $path');
    }
  }

  /// Get the actual save directory to use for saving files (images only)
  static Future<String> _getActualSaveDirectory() async {
    // Always try to use external app storage first for better user experience
    final externalDir = await getExternalAppDirectory();
    if (externalDir != null) {
      final userLocation = getSaveLocation();
      if (userLocation != null) {
        // Create a subfolder in external app storage with user's preferred name
        final folderName = path.basename(userLocation);
        final targetDir = path.join(externalDir, folderName);
        debugPrint('🎯 Using external app storage with user folder name: $targetDir');
        return targetDir;
      } else {
        // Use default DocumentScanner folder in external app storage
        final targetDir = path.join(externalDir, 'DocumentScanner');
        debugPrint('🎯 Using default external app storage: $targetDir');
        return targetDir;
      }
    }

    // Fallback to internal storage
    final userLocation = getSaveLocation();
    if (userLocation != null) {
      final folderName = path.basename(userLocation);
      final defaultDir = await getDefaultSaveLocation();
      final targetDir = path.join(path.dirname(defaultDir), folderName);
      debugPrint('🎯 Using internal storage with user folder name: $targetDir');
      return targetDir;
    }

    // Final fallback to default internal storage
    final defaultDir = await getDefaultSaveLocation();
    debugPrint('🎯 Using default internal storage: $defaultDir');
    return defaultDir;
  }

  static Future<String> saveImageFile(Uint8List imageData, String fileName) async {
    try {
      debugPrint('💾 Saving image file: $fileName');

      // Get the target directory (always app storage for images)
      final saveDir = await _getActualSaveDirectory();
      await ensureDirectoryExists(saveDir);

      // Save the file
      final filePath = path.join(saveDir, fileName);
      final file = File(filePath);
      await file.writeAsBytes(imageData);

      debugPrint('✅ Image saved successfully to: $filePath');

      // Verify file exists
      if (await file.exists()) {
        final fileSize = await file.length();
        debugPrint('✅ Image file verified: ${file.path} (${fileSize} bytes)');
        return file.path;
      } else {
        throw Exception('File was not created successfully');
      }
    } catch (e) {
      debugPrint('❌ Error saving image: $e');

      // Fallback to internal storage
      try {
        final defaultDir = await getDefaultSaveLocation();
        await ensureDirectoryExists(defaultDir);
        final filePath = path.join(defaultDir, fileName);
        final file = File(filePath);
        await file.writeAsBytes(imageData);
        debugPrint('📱 Image saved to internal storage fallback: $filePath');
        return file.path;
      } catch (fallbackError) {
        debugPrint('❌ Fallback save also failed: $fallbackError');
        rethrow;
      }
    }
  }

  /// Save PDF file using SAF with user confirmation
  static Future<String> savePdfFile(Uint8List pdfData, String fileName) async {
    try {
      debugPrint('💾 Saving PDF file: $fileName (${pdfData.length} bytes)');

      // Check if we have storage permissions first
      final hasPermissions = await PermissionService.checkStoragePermissions();
      debugPrint('🔐 Storage permissions available: $hasPermissions');

      // Always try app storage first for reliability
      debugPrint('📱 Attempting to save to app storage first...');
      try {
        final appStoragePath = await _savePdfToAppStorage(pdfData, fileName);
        debugPrint('✅ PDF saved to app storage successfully: $appStoragePath');
        return appStoragePath;
      } catch (appStorageError) {
        debugPrint('❌ App storage save failed: $appStorageError');
      }

      // If app storage fails and we have permissions, try SAF as fallback
      if (hasPermissions) {
        debugPrint('🔄 Attempting SAF save as fallback...');
        try {
          final result = await FilePicker.platform
              .saveFile(dialogTitle: 'Save PDF Document', fileName: fileName, type: FileType.custom, allowedExtensions: ['pdf'], bytes: pdfData)
              .timeout(
                const Duration(minutes: 2),
                onTimeout: () {
                  debugPrint('⚠️ SAF save timed out after 2 minutes');
                  return null;
                },
              );

          if (result != null) {
            debugPrint('✅ PDF saved via SAF to: $result');
            return result;
          } else {
            debugPrint('⚠️ SAF save cancelled by user or timed out');
          }
        } catch (safError) {
          debugPrint('❌ SAF save failed: $safError');
        }
      }

      // Final fallback - try internal storage
      debugPrint('🔄 Final fallback: attempting internal storage...');
      return await _savePdfToInternalStorage(pdfData, fileName);
    } catch (e) {
      debugPrint('❌ All PDF save methods failed: $e');
      // Last resort - try internal storage
      return await _savePdfToInternalStorage(pdfData, fileName);
    }
  }

  /// Fallback method to save PDF to app storage
  static Future<String> _savePdfToAppStorage(Uint8List pdfData, String fileName) async {
    try {
      debugPrint('📱 Saving PDF to app storage: $fileName');

      // Get the target directory
      final saveDir = await _getActualSaveDirectory();
      await ensureDirectoryExists(saveDir);

      // Save the file
      final filePath = path.join(saveDir, fileName);
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      debugPrint('✅ PDF saved to app storage: $filePath');

      // Verify file exists and has correct size
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize == pdfData.length) {
          debugPrint('✅ PDF file verified: ${file.path} (${fileSize} bytes)');
          return file.path;
        } else {
          throw Exception('PDF file size mismatch: expected ${pdfData.length}, got $fileSize');
        }
      } else {
        throw Exception('PDF file was not created successfully');
      }
    } catch (e) {
      debugPrint('❌ Error saving PDF to app storage: $e');
      rethrow;
    }
  }

  /// Final fallback to save PDF to internal storage
  static Future<String> _savePdfToInternalStorage(Uint8List pdfData, String fileName) async {
    try {
      debugPrint('🏠 Saving PDF to internal storage (final fallback): $fileName');

      final defaultDir = await getDefaultSaveLocation();
      await ensureDirectoryExists(defaultDir);
      final filePath = path.join(defaultDir, fileName);
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      // Verify file exists and has correct size
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize == pdfData.length) {
          debugPrint('✅ PDF saved to internal storage: $filePath (${fileSize} bytes)');
          return file.path;
        } else {
          throw Exception('PDF file size mismatch in internal storage: expected ${pdfData.length}, got $fileSize');
        }
      } else {
        throw Exception('PDF file creation failed in internal storage');
      }
    } catch (e) {
      debugPrint('❌ Final fallback PDF save failed: $e');
      rethrow;
    }
  }

  /// Save PDF file directly to app storage (for when user doesn't want SAF)
  static Future<String> savePdfFileToAppStorage(Uint8List pdfData, String fileName) async {
    return await _savePdfToAppStorage(pdfData, fileName);
  }

  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ File deleted: $filePath');
      } else {
        debugPrint('⚠️ File not found for deletion: $filePath');
      }
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
    }
  }

  static Future<bool> fileExists(String filePath) async {
    try {
      final exists = await File(filePath).exists();
      debugPrint('🔍 File exists check for $filePath: $exists');
      return exists;
    } catch (e) {
      debugPrint('❌ Error checking file existence: $e');
      return false;
    }
  }

  /// Get the folder name where files are actually saved for display purposes
  static String getStorageLocationDisplayName(String filePath) {
    try {
      final userLocation = getSaveLocation();

      // If user has set a custom location, show that folder name
      if (userLocation != null) {
        final folderName = path.basename(userLocation);
        debugPrint('📂 Display name for user location: $folderName');
        return folderName;
      }

      // Check if it's external app storage
      if (filePath.contains('/Android/data/') && filePath.contains('/files/')) {
        debugPrint('📂 Display name: External App Storage');
        return 'External App Storage';
      }

      // Check if it's internal storage
      if (filePath.contains('app_flutter') || filePath.contains('DocumentScanner')) {
        debugPrint('📂 Display name: Internal App Storage');
        return 'Internal App Storage';
      }

      // For SAF saved files (user chosen location)
      if (filePath.startsWith('/storage/emulated/0/') && !filePath.contains('/Android/data/')) {
        debugPrint('📂 Display name: User Selected Location');
        return 'User Selected Location';
      }

      // For other paths, try to extract folder name
      final directory = File(filePath).parent;
      final dirPath = directory.path;
      final parts = dirPath.split('/');
      final displayName = parts.isNotEmpty ? parts.last : 'App Storage';
      debugPrint('📂 Display name for path $filePath: $displayName');
      return displayName;
    } catch (e) {
      debugPrint('❌ Error getting display name: $e');
      return 'App Storage';
    }
  }

  /// Test the current save location and provide detailed status
  static Future<Map<String, dynamic>> getSaveLocationStatus() async {
    debugPrint('📊 Getting save location status...');

    final userLocation = getSaveLocation();
    final actualDir = await _getActualSaveDirectory();

    // Check if external app storage is available
    final externalDir = await getExternalAppDirectory();
    final hasExternalStorage = externalDir != null;

    if (userLocation == null) {
      return {
        'isDefault': true,
        'location': actualDir,
        'displayLocation': hasExternalStorage ? 'External App Storage (Default)' : 'Internal App Storage (Default)',
        'canWrite': true,
        'message': hasExternalStorage ? 'Images: External app storage, PDFs: User choice via file picker' : 'Images: Internal app storage, PDFs: User choice via file picker',
        'pdfSaveMethod': 'SAF (Storage Access Framework)',
      };
    }

    // Test if we can write to the actual directory
    final canWrite = await _testDirectWrite(actualDir);

    // Get user-friendly location description
    String displayLocation;
    String message;

    if (hasExternalStorage) {
      displayLocation = '${path.basename(userLocation)} (External)';
      message = 'Images: External app storage, PDFs: User choice via file picker';
    } else {
      displayLocation = '${path.basename(userLocation)} (Internal)';
      message = 'Images: Internal app storage, PDFs: User choice via file picker';
    }

    final status = {
      'isDefault': false,
      'location': actualDir,
      'displayLocation': displayLocation,
      'canWrite': canWrite,
      'message': message,
      'hasExternalStorage': hasExternalStorage,
      'pdfSaveMethod': 'SAF (Storage Access Framework)',
    };

    debugPrint('📊 Save location status: $status');
    return status;
  }

  static Future<bool> _testDirectWrite(String dirPath) async {
    try {
      debugPrint('🧪 Testing write access to: $dirPath');

      await ensureDirectoryExists(dirPath);

      // Try to create a test file
      final testFile = File(path.join(dirPath, '.test_write_${DateTime.now().millisecondsSinceEpoch}'));
      await testFile.writeAsString('test');

      if (await testFile.exists()) {
        await testFile.delete();
        debugPrint('✅ Write test successful for: $dirPath');
        return true;
      }
      debugPrint('❌ Write test failed - file not created: $dirPath');
      return false;
    } catch (e) {
      debugPrint('❌ Write test failed for $dirPath: $e');
      return false;
    }
  }
}
