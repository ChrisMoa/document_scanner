import 'dart:io';
import 'dart:typed_data';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/models/scan_session_model.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:file_picker/file_picker.dart';

class StorageService {
  static late Box<DocumentModel> _documentsBox;
  static late Box<ScanSessionModel> _scanSessionsBox;
  static late Box<String> _settingsBox;

  static Future<void> initialize() async {
    Hive.registerAdapter(DocumentModelAdapter());
    Hive.registerAdapter(ScanSessionModelAdapter());

    _documentsBox = await Hive.openBox<DocumentModel>('documents');
    _scanSessionsBox = await Hive.openBox<ScanSessionModel>('scan_sessions');
    _settingsBox = await Hive.openBox<String>('settings');
  }

  static Box<DocumentModel> get documentsBox => _documentsBox;
  static Box<ScanSessionModel> get scanSessionsBox => _scanSessionsBox;
  static Box<String> get settingsBox => _settingsBox;

  static Future<String> getDefaultSaveLocation() async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/DocumentScanner';
  }

  /// Get the external storage directory for the app (works on Android 11+)
  static Future<String?> getExternalAppDirectory() async {
    try {
      final directory = await getExternalStorageDirectory();
      return directory?.path;
    } catch (e) {
      debugPrint('❌ Error getting external storage directory: $e');
      return null;
    }
  }

  static String? getSaveLocation() {
    return _settingsBox.get('save_location');
  }

  static String? getSaveLocationUri() {
    return _settingsBox.get('save_location_uri');
  }

  static Future<void> setSaveLocation(String path) async {
    await _settingsBox.put('save_location', path);
    debugPrint('📁 Save location set to: $path');
  }

  static Future<void> setSaveLocationUri(String uri) async {
    await _settingsBox.put('save_location_uri', uri);
    debugPrint('📁 Save location URI set to: $uri');
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

  /// Get the actual save directory to use
  static Future<String> _getActualSaveDirectory() async {
    final userLocation = getSaveLocation();

    if (userLocation != null) {
      // Try to use external app storage with user's folder name
      final externalDir = await getExternalStorageDirectory();
      if (externalDir != null) {
        final userFolderName = path.basename(userLocation);
        final targetDir = path.join(externalDir.path, userFolderName);
        debugPrint('🎯 Using external app storage: $targetDir');
        return targetDir;
      }
    }

    // Fallback to default internal storage
    return await getDefaultSaveLocation();
  }

  static Future<String> saveImageFile(Uint8List imageData, String fileName) async {
    try {
      // Get the target directory
      final saveDir = await _getActualSaveDirectory();
      await ensureDirectoryExists(saveDir);

      // Save the file
      final filePath = path.join(saveDir, fileName);
      final file = File(filePath);
      await file.writeAsBytes(imageData);

      debugPrint('✅ Image saved to: $filePath');

      // Verify file exists
      if (await file.exists()) {
        debugPrint('✅ Image file verified: ${file.path}');
        return file.path;
      } else {
        throw Exception('File was not created successfully');
      }
    } catch (e) {
      debugPrint('❌ Error saving image: $e');

      // Fallback to internal storage
      final defaultDir = await getDefaultSaveLocation();
      await ensureDirectoryExists(defaultDir);
      final filePath = path.join(defaultDir, fileName);
      final file = File(filePath);
      await file.writeAsBytes(imageData);
      debugPrint('📱 Image saved to internal storage fallback: $filePath');
      return file.path;
    }
  }

  static Future<String> savePdfFile(Uint8List pdfData, String fileName) async {
    try {
      // Get the target directory
      final saveDir = await _getActualSaveDirectory();
      await ensureDirectoryExists(saveDir);

      // Save the file
      final filePath = path.join(saveDir, fileName);
      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      debugPrint('✅ PDF saved to: $filePath');

      // Verify file exists
      if (await file.exists()) {
        debugPrint('✅ PDF file verified: ${file.path}');
        return file.path;
      } else {
        throw Exception('File was not created successfully');
      }
    } catch (e) {
      debugPrint('❌ Error saving PDF: $e');

      // Fallback to internal storage
      final defaultDir = await getDefaultSaveLocation();
      await ensureDirectoryExists(defaultDir);
      final filePath = path.join(defaultDir, fileName);
      final file = File(filePath);
      await file.writeAsBytes(pdfData);
      debugPrint('📱 PDF saved to internal storage fallback: $filePath');
      return file.path;
    }
  }

  static Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ File deleted: $filePath');
      }
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
    }
  }

  static Future<bool> fileExists(String filePath) async {
    try {
      return await File(filePath).exists();
    } catch (e) {
      debugPrint('❌ Error checking file existence: $e');
      return false;
    }
  }

  /// Get the folder name where files are actually saved
  static String getStorageLocationDisplayName(String filePath) {
    try {
      final userLocation = getSaveLocation();

      // If user has set a custom location, show that folder name
      if (userLocation != null) {
        return path.basename(userLocation);
      }

      // Check if it's internal storage
      if (filePath.contains('app_flutter') || filePath.contains('DocumentScanner')) {
        return 'App Internal Storage';
      }

      // For external storage, try to extract folder name
      final directory = File(filePath).parent;
      final dirPath = directory.path;
      final parts = dirPath.split('/');
      return parts.isNotEmpty ? parts.last : 'Storage';
    } catch (e) {
      return 'App Storage';
    }
  }

  /// Test the current save location and provide detailed status
  static Future<Map<String, dynamic>> getSaveLocationStatus() async {
    final userLocation = getSaveLocation();
    final actualDir = await _getActualSaveDirectory();

    if (userLocation == null) {
      return {'isDefault': true, 'location': actualDir, 'displayLocation': 'App Internal Storage', 'canWrite': true, 'message': 'Using default app storage'};
    }

    // Test if we can write to the actual directory
    final canWrite = await _testDirectWrite(actualDir);

    return {
      'isDefault': false,
      'location': actualDir,
      'displayLocation': path.basename(userLocation),
      'canWrite': canWrite,
      'message': canWrite ? 'Saving to user-selected location' : 'Using app storage (external access limited)',
    };
  }

  static Future<bool> _testDirectWrite(String dirPath) async {
    try {
      await ensureDirectoryExists(dirPath);

      // Try to create a test file
      final testFile = File(path.join(dirPath, '.test_write_${DateTime.now().millisecondsSinceEpoch}'));
      await testFile.writeAsString('test');

      if (await testFile.exists()) {
        await testFile.delete();
        debugPrint('✅ Direct write test successful: $dirPath');
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Direct write test failed: $dirPath - $e');
      return false;
    }
  }
}
