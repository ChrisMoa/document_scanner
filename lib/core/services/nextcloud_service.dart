import 'dart:convert';
import 'dart:typed_data';
import 'dart:io' show HttpDate;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xml/xml.dart' as xml;

/// Nextcloud WebDAV based cloud service.
///
/// Exposes the same public interface as the former OneDriveService so the rest
/// of the app can call identical static methods.
class NextcloudService {
  static const String _tokenKey = 'nextcloud_app_password';
  static const String _serverKey = 'nextcloud_server_url';
  static const String _usernameKey = 'nextcloud_username';

  static late Dio _dio;
  static String? _serverUrl; // e.g. https://cloud.example.com
  static String? _username; // Nextcloud username
  static String? _appPassword; // App password (or user password)

  // Read-only accessors for UI prefill
  static String? get serverUrl => _serverUrl;
  static String? get username => _username;

  static String get _webDavBasePath {
    // Nextcloud WebDAV root for user files
    if (_serverUrl == null || _username == null) return '';
    final clean = _serverUrl!.endsWith('/') ? _serverUrl!.substring(0, _serverUrl!.length - 1) : _serverUrl!;
    return '$clean/remote.php/dav/files/${Uri.encodeComponent(_username!)}';
  }

  static Future<void> initialize() async {
    _dio = Dio();
    _dio.options.followRedirects = true;
    _dio.options.validateStatus = (status) => status != null && status >= 200 && status < 400 || status == 401 || status == 404;

    await _loadCredentials();

    // Configure auth header if available
    if (_appPassword != null && _username != null) {
      _setAuthHeader(_username!, _appPassword!);
    }
  }

  static Future<void> _loadCredentials() async {
    debugPrint('🔑 Loading Nextcloud credentials from SharedPreferences...');
    final prefs = await SharedPreferences.getInstance();
    _serverUrl = prefs.getString(_serverKey);
    _username = prefs.getString(_usernameKey);
    _appPassword = prefs.getString(_tokenKey);

    if (isAuthenticated) {
      debugPrint('✅ Nextcloud credentials loaded');
      debugPrint('🌐 Server: ${_serverUrl}');
      debugPrint('👤 User: ${_username}');
    } else {
      debugPrint('🔑 No complete Nextcloud credentials found');
    }
  }

  static Future<void> _saveCredentials(String serverUrl, String username, String appPassword) async {
    debugPrint('💾 Saving Nextcloud credentials to SharedPreferences...');
    _serverUrl = serverUrl.trim();
    _username = username.trim();
    _appPassword = appPassword;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_serverKey, _serverUrl!);
    await prefs.setString(_usernameKey, _username!);
    await prefs.setString(_tokenKey, _appPassword!);

    _setAuthHeader(_username!, _appPassword!);
    debugPrint('✅ Nextcloud credentials saved');
  }

  static void _setAuthHeader(String username, String appPassword) {
    final basic = base64Encode(utf8.encode('$username:$appPassword'));
    _dio.options.headers['Authorization'] = 'Basic $basic';
  }

  static bool get isAuthenticated => _serverUrl != null && _username != null && _appPassword != null && _serverUrl!.isNotEmpty && _username!.isNotEmpty && _appPassword!.isNotEmpty;

  static Future<void> signOut() async {
    _serverUrl = null;
    _username = null;
    _appPassword = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_serverKey);
    await prefs.remove(_usernameKey);
    await prefs.remove(_tokenKey);
  }

  /// Authenticate by verifying WebDAV access using provided credentials.
  /// Returns true on success and persists credentials.
  static Future<bool> authenticate(String serverUrl, String username, String appPassword) async {
    try {
      final clean = serverUrl.trim().replaceAll(RegExp(r'/+$'), '');
      final authDio = Dio();
      final basic = base64Encode(utf8.encode('$username:$appPassword'));
      authDio.options.headers['Authorization'] = 'Basic $basic';

      // PROPFIND Depth: 0 on the user root to validate credentials
      final url = '$clean/remote.php/dav/files/${Uri.encodeComponent(username)}/';
      final response = await authDio.request(
        url,
        options: Options(method: 'PROPFIND', headers: {'Depth': '0'}),
        data: '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/><d:displayname/></d:prop></d:propfind>',
      );

      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        await _saveCredentials(clean, username, appPassword);
        return true;
      }
      debugPrint('❌ Nextcloud auth failed with status ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Nextcloud authentication error: $e');
    }
    return false;
  }

  /// Upload a file. folderId is treated as a path relative to the root (e.g., 'Backups/Docs').
  static Future<String?> uploadFile(Uint8List fileData, String fileName, {String? folderId}) async {
    if (!isAuthenticated) return null;
    try {
      final encodedFileName = Uri.encodeComponent(fileName);
      final folderPath = (folderId ?? '').trim();
      final fullPath = folderPath.isEmpty ? '/$encodedFileName' : '/${_normalizePath(folderPath)}/$encodedFileName';

      // Ensure parent folder exists (create recursively)
      await _ensureFoldersExist(folderPath);

      final url = '$_webDavBasePath$fullPath';
      debugPrint('📤 Uploading to Nextcloud path: $url');
      final response = await _dio.put(
        url,
        data: fileData,
        options: Options(headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Length': fileData.length.toString(),
        }),
      );

      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        debugPrint('✅ Upload successful');
        return url; // Direct WebDAV URL (requires auth)
      }
      debugPrint('❌ Upload failed with status ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ Upload error: $e');
    }
    return null;
  }

  static Future<Uint8List?> downloadFile(String fileId) async {
    if (!isAuthenticated) return null;
    try {
      // fileId is the relative path from listFiles
      // It should already be properly encoded, so we just clean leading slashes
      final cleanPath = fileId.trim().replaceAll(RegExp(r'^/+'), '');
      final url = '$_webDavBasePath/$cleanPath';
      debugPrint('📥 Downloading from Nextcloud: $url');
      debugPrint('📥 File ID: $fileId');
      final response = await _dio.get(url, options: Options(responseType: ResponseType.bytes));
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        final bytes = response.data as List<int>;
        debugPrint('✅ Downloaded ${bytes.length} bytes from $cleanPath');
        return Uint8List.fromList(bytes);
      }
      debugPrint('❌ Download failed with status ${response.statusCode} for $cleanPath');
    } catch (e) {
      debugPrint('❌ Download error for $fileId: $e');
    }
    return null;
  }

  static Future<bool> deleteFile(String fileId) async {
    if (!isAuthenticated) return false;
    try {
      final path = _normalizePath(fileId);
      final url = '$_webDavBasePath/$path';
      final response = await _dio.delete(url);
      return response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300;
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> createFolder(String folderName, {String? parentId}) async {
    if (!isAuthenticated) return null;
    try {
      final parent = parentId == null || parentId.trim().isEmpty ? '' : '${_normalizePath(parentId)}/';
      final path = '$parent${_encodePathSegment(folderName)}';

      // Check if folder already exists first
      final existing = await findFolder(folderName, parentId: parentId);
      if (existing != null) {
        debugPrint('✅ Folder already exists: $folderName');
        return existing;
      }

      final url = '$_webDavBasePath/$path';
      debugPrint('📁 Creating folder at: $url');
      final response = await _dio.request(url, options: Options(method: 'MKCOL'));
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        debugPrint('✅ Folder created: $folderName');
        return {
          'id': path,
          'name': folderName,
          'folder': <String, dynamic>{},
        };
      } else if (response.statusCode == 405) {
        // 405 Method Not Allowed usually means folder already exists
        debugPrint('⚠️ Folder might already exist (405): $folderName');
        // Try to find it again
        final retry = await findFolder(folderName, parentId: parentId);
        if (retry != null) return retry;
        // Return a basic folder object if we can't find it but it exists
        return {
          'id': path,
          'name': folderName,
          'folder': <String, dynamic>{},
        };
      }
    } catch (e) {
      debugPrint('❌ Create folder error: $e');
      // If it's a 405 error, the folder likely exists
      if (e.toString().contains('405')) {
        debugPrint('⚠️ Folder likely exists (405 error): $folderName');
        final parent = parentId == null || parentId.trim().isEmpty ? '' : '${_normalizePath(parentId)}/';
        final path = '$parent${_encodePathSegment(folderName)}';
        return {
          'id': path,
          'name': folderName,
          'folder': <String, dynamic>{},
        };
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>?> findFolder(String folderName, {String? parentId}) async {
    final files = await listFiles(folderId: parentId);
    if (files == null) return null;
    for (final f in files) {
      if (f['name'] == folderName && f['folder'] != null) return f;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>?> listFiles({String? folderId}) async {
    if (!isAuthenticated) return null;
    try {
      final path = folderId == null || folderId.trim().isEmpty ? '' : '${_normalizePath(folderId)}/';
      final url = '$_webDavBasePath/$path';
      debugPrint('📂 Listing files from: $url');

      final response = await _dio.request(
        url,
        options: Options(method: 'PROPFIND', headers: {'Depth': '1'}),
        data: '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:displayname/><d:getcontentlength/><d:getlastmodified/><d:resourcetype/></d:prop></d:propfind>',
      );

      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        final body = response.data is String ? response.data as String : utf8.decode((response.data as List<int>));
        final doc = xml.XmlDocument.parse(body);
        final results = <Map<String, dynamic>>[];

        for (final resp in doc.findAllElements('response', namespace: '*')) {
          final href = resp.findElements('href', namespace: '*').firstOrNull?.innerText ?? '';
          // Skip the directory itself
          if (href.endsWith('/$path') || (path.isEmpty && href.endsWith('/${Uri.encodeComponent(_username!)}/'))) {
            continue;
          }
          final propstat = resp.findElements('propstat', namespace: '*').firstOrNull;
          final prop = propstat?.findElements('prop', namespace: '*').firstOrNull;
          final displayName = prop?.findElements('displayname', namespace: '*').firstOrNull?.innerText ?? '';
          final lengthStr = prop?.findElements('getcontentlength', namespace: '*').firstOrNull?.innerText ?? '0';
          final modified = prop?.findElements('getlastmodified', namespace: '*').firstOrNull?.innerText ?? '';
          final resType = prop?.findElements('resourcetype', namespace: '*').firstOrNull;
          final isCollection = resType?.findElements('collection', namespace: '*').isNotEmpty == true;

          // Convert href to relative path under the user root
          final relPath = _relativePathFromHref(href);
          if (relPath == null) continue;

          results.add({
            'id': relPath, // use relative path as id
            'name': displayName.isNotEmpty ? displayName : _basename(relPath),
            'size': int.tryParse(lengthStr) ?? 0,
            '@microsoft.graph.downloadUrl': '$_webDavBasePath/$relPath', // for compatibility
            'folder': isCollection ? <String, dynamic>{} : null,
            'lastModifiedDateTime': _httpDateToIso(modified),
          });
        }

        debugPrint('✅ Found ${results.length} items in $url');
        return results;
      }
      debugPrint('❌ List files failed with status ${response.statusCode}');
    } catch (e) {
      debugPrint('❌ List files error: $e');
    }
    return null;
  }

  // -------------- Interface compatibility stubs --------------
  static String getAuthUrl(String _) => '';
  static String getDefaultAuthUrl() => '';
  static bool get hasDefaultClientId => false;
  static String get defaultClientId => '';
  static Future<bool> authenticateWithDefault(String code) async => false;

  // -------------- Helpers --------------
  static String _normalizePath(String p) {
    final trimmed = p.trim().replaceAll('\\', '/');
    final parts = trimmed.split('/').where((e) => e.isNotEmpty).map((s) => _encodePathSegment(Uri.decodeComponent(s))).toList();
    return parts.join('/');
  }

  static String _encodePathSegment(String s) => Uri.encodeComponent(s);

  static String? _relativePathFromHref(String href) {
    // href is absolute path like /remote.php/dav/files/USERNAME/path/to/item
    try {
      final base = Uri.parse(_webDavBasePath);
      final hrefUri = Uri.parse(href.startsWith('http') ? href : (_serverUrl! + href));
      final basePath = base.path.endsWith('/') ? base.path : base.path + '/';
      final fullPath = hrefUri.path;
      final idx = fullPath.indexOf(basePath);
      if (idx >= 0) {
        var rel = fullPath.substring(idx + basePath.length);
        rel = rel.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'/+$'), '');
        return rel;
      }
    } catch (_) {}
    return null;
  }

  static String _basename(String relPath) {
    final parts = relPath.split('/');
    return parts.isNotEmpty ? parts.last : relPath;
  }

  static Future<void> _ensureFoldersExist(String folderPath) async {
    if (folderPath.trim().isEmpty) return;
    final parts = _normalizePath(folderPath).split('/');
    String current = '';
    for (final part in parts) {
      current = current.isEmpty ? part : '$current/$part';
      final url = '$_webDavBasePath/$current';
      try {
        // Try PROPFIND to see if exists
        final resp = await _dio.request(url, options: Options(method: 'PROPFIND', headers: {'Depth': '0'}));
        if (resp.statusCode == 404) {
          await _dio.request(url, options: Options(method: 'MKCOL'));
        }
      } catch (_) {
        // Try to create on any error
        try {
          await _dio.request(url, options: Options(method: 'MKCOL'));
        } catch (e) {
          debugPrint('❌ Failed to ensure folder $current: $e');
        }
      }
    }
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

// Parse HTTP date string (e.g., "Mon, 20 Feb 2023 10:20:30 GMT") to ISO8601
String _httpDateToIso(String httpDate) {
  try {
    final dt = HttpDate.parse(httpDate);
    return dt.toIso8601String();
  } catch (_) {
    return DateTime.now().toIso8601String();
  }
}
