import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:document_scanner/core/services/storage_service.dart';

class OneDriveService {
  static const String _baseUrl = 'https://graph.microsoft.com/v1.0';
  static const String _tokenKey = 'onedrive_access_token';
  static const String _refreshTokenKey = 'onedrive_refresh_token';
  static const String _clientIdKey = 'onedrive_client_id';

  static late Dio _dio;
  static String? _accessToken;
  static String? _refreshToken;

  static Future<void> initialize() async {
    _dio = Dio();
    _dio.options.baseUrl = _baseUrl;
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            final success = await _refreshAccessToken();
            if (success) {
              final request = error.requestOptions;
              request.headers['Authorization'] = 'Bearer $_accessToken';
              final response = await _dio.fetch(request);
              handler.resolve(response);
              return;
            }
          }
          handler.next(error);
        },
      ),
    );

    await _loadTokens();
  }

  static Future<void> _loadTokens() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(_tokenKey);
    _refreshToken = prefs.getString(_refreshTokenKey);
  }

  static Future<void> _saveTokens(String accessToken, String refreshToken) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, accessToken);
    await prefs.setString(_refreshTokenKey, refreshToken);
  }

  static Future<bool> _refreshAccessToken() async {
    if (_refreshToken == null) return false;

    try {
      const authUrl = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';
      final clientId = StorageService.settingsBox.get(_clientIdKey);

      if (clientId == null) return false;

      final response = await Dio().post(
        authUrl,
        data: {'client_id': clientId, 'scope': 'files.readwrite offline_access', 'refresh_token': _refreshToken, 'grant_type': 'refresh_token'},
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _saveTokens(data['access_token'], data['refresh_token']);
        return true;
      }
    } catch (e) {
      debugPrint('Error refreshing token: $e');
    }

    return false;
  }

  static Future<bool> authenticate(String clientId, String code) async {
    try {
      const authUrl = 'https://login.microsoftonline.com/common/oauth2/v2.0/token';

      final response = await Dio().post(
        authUrl,
        data: {
          'client_id': clientId,
          'scope': 'files.readwrite offline_access',
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': 'https://login.microsoftonline.com/common/oauth2/nativeclient',
        },
        options: Options(contentType: 'application/x-www-form-urlencoded'),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        await _saveTokens(data['access_token'], data['refresh_token']);
        await StorageService.settingsBox.put(_clientIdKey, clientId);
        return true;
      }
    } catch (e) {
      debugPrint('Authentication error: $e');
    }

    return false;
  }

  static bool get isAuthenticated => _accessToken != null;

  static Future<void> signOut() async {
    _accessToken = null;
    _refreshToken = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_refreshTokenKey);
    await StorageService.settingsBox.delete(_clientIdKey);
  }

  static Future<String?> uploadFile(Uint8List fileData, String fileName, {String? folderId}) async {
    try {
      final uploadPath = folderId != null ? '/me/drive/items/$folderId:/$fileName:/content' : '/me/drive/root:/$fileName:/content';

      final response = await _dio.put(uploadPath, data: fileData, options: Options(headers: {'Content-Type': 'application/octet-stream'}));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data['webUrl'];
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    }

    return null;
  }

  static Future<Uint8List?> downloadFile(String fileId) async {
    try {
      final response = await _dio.get('/me/drive/items/$fileId/content', options: Options(responseType: ResponseType.bytes));

      if (response.statusCode == 200) {
        return Uint8List.fromList(response.data);
      }
    } catch (e) {
      debugPrint('Download error: $e');
    }

    return null;
  }

  static Future<bool> deleteFile(String fileId) async {
    try {
      final response = await _dio.delete('/me/drive/items/$fileId');
      return response.statusCode == 204;
    } catch (e) {
      debugPrint('Delete error: $e');
      return false;
    }
  }

  static Future<Map<String, dynamic>?> createFolder(String folderName, {String? parentId}) async {
    try {
      final parentPath = parentId != null ? '/me/drive/items/$parentId/children' : '/me/drive/root/children';

      final response = await _dio.post(parentPath, data: {'name': folderName, 'folder': {}, '@microsoft.graph.conflictBehavior': 'rename'});

      if (response.statusCode == 201) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Create folder error: $e');
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>?> listFiles({String? folderId}) async {
    try {
      final path = folderId != null ? '/me/drive/items/$folderId/children' : '/me/drive/root/children';

      final response = await _dio.get(path);

      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['value']);
      }
    } catch (e) {
      debugPrint('List files error: $e');
    }

    return null;
  }

  static String getAuthUrl(String clientId) {
    final params = {
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': 'https://login.microsoftonline.com/common/oauth2/nativeclient',
      'scope': 'files.readwrite offline_access',
      'response_mode': 'query',
    };

    final queryString = params.entries.map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}').join('&');

    return 'https://login.microsoftonline.com/common/oauth2/v2.0/authorize?$queryString';
  }
}
