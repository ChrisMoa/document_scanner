import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static Future<bool> requestStoragePermissions() async {
    if (!Platform.isAndroid) {
      return true; // iOS handles permissions differently
    }

    try {
      debugPrint('📱 Requesting storage permissions...');

      // For Android 13+ (API 33+), we need different permissions
      if (Platform.isAndroid) {
        final int androidVersion = await _getAndroidVersion();
        debugPrint('🔍 Android version: $androidVersion');

        if (androidVersion >= 33) {
          // Android 13+ - Request media permissions
          final permissions = [Permission.photos, Permission.videos];

          Map<Permission, PermissionStatus> statuses = await permissions.request();

          bool allGranted = statuses.values.every((status) => status == PermissionStatus.granted || status == PermissionStatus.limited);

          debugPrint('📱 Media permissions status: $statuses');
          return allGranted;
        } else if (androidVersion >= 30) {
          // Android 11-12 - Request manage external storage
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
          // Android 10 and below - Regular storage permissions
          final storageStatus = await Permission.storage.request();
          debugPrint('📱 Storage permission: $storageStatus');
          return storageStatus == PermissionStatus.granted;
        }
      }

      return false;
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
      final int androidVersion = await _getAndroidVersion();

      if (androidVersion >= 33) {
        // Android 13+ - Check media permissions
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;

        return (photosStatus == PermissionStatus.granted || photosStatus == PermissionStatus.limited) && (videosStatus == PermissionStatus.granted || videosStatus == PermissionStatus.limited);
      } else if (androidVersion >= 30) {
        // Android 11-12 - Check manage external storage first
        final manageStorageStatus = await Permission.manageExternalStorage.status;
        if (manageStorageStatus == PermissionStatus.granted) {
          return true;
        }

        // Fallback to regular storage permission
        final storageStatus = await Permission.storage.status;
        return storageStatus == PermissionStatus.granted;
      } else {
        // Android 10 and below
        final storageStatus = await Permission.storage.status;
        return storageStatus == PermissionStatus.granted;
      }
    } catch (e) {
      debugPrint('❌ Error checking permissions: $e');
      return false;
    }
  }

  static Future<int> _getAndroidVersion() async {
    // This is a simplified version - in a real app, you might want to use
    // platform channels to get the exact Android API level
    // For now, we'll assume a modern Android version
    return 33; // Assume Android 13+ for testing
  }

  static Future<void> openSettings() async {
    await openAppSettings();
  }
}
