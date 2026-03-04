import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class PermissionService {
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) {
      debugPrint('📱 iOS - permissions handled by system');
      return true; // iOS handles permissions differently
    }

    try {
      debugPrint('📱 Requesting storage permissions...');
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      debugPrint('🔍 Android SDK version: $sdkInt');

      if (sdkInt >= 33) {
        // Android 13+ (API 33+) - Request specific media permissions
        debugPrint('📱 Android 13+ - requesting media permissions');
        final permissions = [Permission.photos, Permission.videos];

        Map<Permission, PermissionStatus> statuses = await permissions.request();
        bool allGranted = statuses.values.every((status) => status == PermissionStatus.granted || status == PermissionStatus.limited);

        debugPrint('📱 Media permissions status: $statuses');

        // For document storage, we also need to check manage external storage
        if (allGranted) {
          final manageStorageStatus = await Permission.manageExternalStorage.request();
          debugPrint('📱 Manage external storage permission: $manageStorageStatus');
          return manageStorageStatus == PermissionStatus.granted || allGranted;
        }

        return allGranted;
      } else if (sdkInt >= 30) {
        // Android 11-12 (API 30-32) - Request manage external storage for full access
        debugPrint('📱 Android 11-12 - requesting manage external storage');
        final manageStorageStatus = await Permission.manageExternalStorage.request();
        debugPrint('📱 Manage external storage permission: $manageStorageStatus');

        if (manageStorageStatus == PermissionStatus.granted) {
          return true;
        }

        // Fallback to regular storage permissions
        final storageStatus = await Permission.storage.request();
        debugPrint('📱 Storage permission fallback: $storageStatus');
        return storageStatus == PermissionStatus.granted;
      } else {
        // Android 10 and below (API 29 and below) - Regular storage permissions
        debugPrint('📱 Android 10 and below - requesting storage permission');
        final storageStatus = await Permission.storage.request();
        debugPrint('📱 Storage permission: $storageStatus');
        return storageStatus == PermissionStatus.granted;
      }
    } catch (e) {
      debugPrint('❌ Error requesting permissions: $e');
      return false;
    }
  }

  static Future<bool> checkStoragePermissions() async {
    if (!Platform.isAndroid) {
      return true; // iOS handles permissions differently
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      debugPrint('🔍 Checking permissions for Android SDK: $sdkInt');

      if (sdkInt >= 33) {
        // Android 13+ - Check media permissions
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;
        final manageStorageStatus = await Permission.manageExternalStorage.status;

        debugPrint('📱 Photos: $photosStatus, Videos: $videosStatus, ManageStorage: $manageStorageStatus');

        return (photosStatus == PermissionStatus.granted || photosStatus == PermissionStatus.limited) && (videosStatus == PermissionStatus.granted || videosStatus == PermissionStatus.limited) ||
            manageStorageStatus == PermissionStatus.granted;
      } else if (sdkInt >= 30) {
        // Android 11-12 - Check manage external storage first
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        debugPrint('📱 Manage external storage status: $manageStorageStatus');

        if (manageStorageStatus == PermissionStatus.granted) {
          return true;
        }

        // Fallback to regular storage permission
        final storageStatus = await Permission.storage.status;
        debugPrint('📱 Storage status fallback: $storageStatus');
        return storageStatus == PermissionStatus.granted;
      } else {
        // Android 10 and below
        final storageStatus = await Permission.storage.status;
        debugPrint('📱 Storage status: $storageStatus');
        return storageStatus == PermissionStatus.granted;
      }
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  /// Check if we can write to external storage directories
  static Future<bool> canWriteToExternalStorage() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30) {
        // Android 11+ - Check if we have manage external storage permission
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        debugPrint('📱 Can write to external storage: ${manageStorageStatus == PermissionStatus.granted}');
        return manageStorageStatus == PermissionStatus.granted;
      } else {
        // Android 10 and below - Check regular storage permission
        final storageStatus = await Permission.storage.status;
        debugPrint('📱 Can write to external storage: ${storageStatus == PermissionStatus.granted}');
        return storageStatus == PermissionStatus.granted;
      }
    } catch (e) {
      debugPrint('❌ Error checking write permissions: $e');
      return false;
    }
  }

  static Future<void> openSettings() async {
    debugPrint('🔧 Opening app settings');
    await openAppSettings();
  }

  /// Show explanation dialog for storage permissions
  static String getStoragePermissionExplanation() {
    return 'This app needs storage permissions to save your scanned documents and PDFs to your chosen location. '
        'Without these permissions, files will only be saved to app-specific storage.';
  }

  /// Get user-friendly permission status message
  static Future<String> getPermissionStatusMessage() async {
    if (!Platform.isAndroid) {
      return 'Storage access available';
    }

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      if (sdkInt >= 30) {
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        switch (manageStorageStatus) {
          case PermissionStatus.granted:
            return 'Full storage access granted - can save to any location';
          case PermissionStatus.denied:
            return 'Storage access denied - files saved to app storage only';
          case PermissionStatus.permanentlyDenied:
            return 'Storage access permanently denied - please enable in settings';
          default:
            return 'Storage access limited - some locations may not be accessible';
        }
      } else {
        final storageStatus = await Permission.storage.status;
        switch (storageStatus) {
          case PermissionStatus.granted:
            return 'Storage access granted';
          case PermissionStatus.denied:
            return 'Storage access denied';
          case PermissionStatus.permanentlyDenied:
            return 'Storage access permanently denied - please enable in settings';
          default:
            return 'Storage access status unknown';
        }
      }
    } catch (e) {
      return 'Unable to determine storage permission status';
    }
  }
}
