import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/models/scan_session_model.dart';

final documentsProvider = StateNotifierProvider<DocumentsNotifier, List<DocumentModel>>((ref) {
  debugPrint('🏗️ Creating DocumentsNotifier provider');
  return DocumentsNotifier();
});

final scanSessionsProvider = StateNotifierProvider<ScanSessionsNotifier, List<ScanSessionModel>>((ref) {
  debugPrint('🏗️ Creating ScanSessionsNotifier provider');
  return ScanSessionsNotifier();
});

final saveLocationProvider = StateNotifierProvider<SaveLocationNotifier, String?>((ref) {
  debugPrint('🏗️ Creating SaveLocationNotifier provider');
  return SaveLocationNotifier();
});

class DocumentsNotifier extends StateNotifier<List<DocumentModel>> {
  DocumentsNotifier() : super([]) {
    debugPrint('📚 Initializing DocumentsNotifier');
    _loadDocuments();
  }

  void _loadDocuments() {
    debugPrint('📖 Loading documents from storage...');
    final documents = StorageService.documentsBox.values.toList();
    documents.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    debugPrint('📖 Loaded ${documents.length} documents');
    state = documents;
  }

  Future<void> addDocument(DocumentModel document) async {
    debugPrint('➕ Adding new document: ${document.name} (ID: ${document.id})');
    await StorageService.documentsBox.put(document.id, document);
    _loadDocuments();
    debugPrint('✅ Document added successfully');
  }

  Future<void> updateDocument(DocumentModel document) async {
    debugPrint('🔄 Updating document: ${document.name} (ID: ${document.id})');
    final updatedDocument = document.copyWith(updatedAt: DateTime.now());
    await StorageService.documentsBox.put(updatedDocument.id, updatedDocument);
    _loadDocuments();
    debugPrint('✅ Document updated successfully');
  }

  Future<void> deleteDocument(String documentId) async {
    debugPrint('🗑️ Deleting document: $documentId');
    final document = StorageService.documentsBox.get(documentId);
    if (document != null) {
      debugPrint('🗑️ Deleting ${document.imagePaths.length} image files and PDF');

      // Delete all associated files
      for (final imagePath in document.imagePaths) {
        await StorageService.deleteFile(imagePath);
      }

      if (document.pdfPath != null) {
        await StorageService.deleteFile(document.pdfPath!);
      }

      await StorageService.documentsBox.delete(documentId);
      _loadDocuments();
      debugPrint('✅ Document and associated files deleted successfully');
    } else {
      debugPrint('⚠️ Document not found for deletion: $documentId');
    }
  }

  DocumentModel? getDocument(String documentId) {
    final document = StorageService.documentsBox.get(documentId);
    debugPrint('🔍 Retrieved document: ${document?.name ?? 'Not found'} (ID: $documentId)');
    return document;
  }

  List<DocumentModel> getDocumentsByName(String name) {
    final filtered = state.where((doc) => doc.name.toLowerCase().contains(name.toLowerCase())).toList();
    debugPrint('🔍 Found ${filtered.length} documents matching "$name"');
    return filtered;
  }

  List<DocumentModel> getUploadedDocuments() {
    final uploaded = state.where((doc) => doc.isUploaded).toList();
    debugPrint('☁️ Found ${uploaded.length} uploaded documents');
    return uploaded;
  }

  List<DocumentModel> getEncryptedDocuments() {
    final encrypted = state.where((doc) => doc.isEncrypted).toList();
    debugPrint('🔒 Found ${encrypted.length} encrypted documents');
    return encrypted;
  }
}

class ScanSessionsNotifier extends StateNotifier<List<ScanSessionModel>> {
  ScanSessionsNotifier() : super([]) {
    debugPrint('📸 Initializing ScanSessionsNotifier');
    _loadScanSessions();
  }

  void _loadScanSessions() {
    debugPrint('📖 Loading scan sessions from storage...');
    final sessions = StorageService.scanSessionsBox.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    debugPrint('📖 Loaded ${sessions.length} scan sessions');
    state = sessions;
  }

  Future<void> addScanSession(ScanSessionModel session) async {
    debugPrint('➕ Adding new scan session: ${session.id}');
    await StorageService.scanSessionsBox.put(session.id, session);
    _loadScanSessions();
    debugPrint('✅ Scan session added successfully');
  }

  Future<void> updateScanSession(ScanSessionModel session) async {
    debugPrint('🔄 Updating scan session: ${session.id} (${session.imagePaths.length} images)');
    await StorageService.scanSessionsBox.put(session.id, session);
    _loadScanSessions();
    debugPrint('✅ Scan session updated successfully');
  }

  Future<void> deleteScanSession(String sessionId) async {
    debugPrint('🗑️ Deleting scan session: $sessionId');
    final session = StorageService.scanSessionsBox.get(sessionId);
    if (session != null) {
      debugPrint('🗑️ Deleting ${session.imagePaths.length} session image files');
      for (final imagePath in session.imagePaths) {
        await StorageService.deleteFile(imagePath);
      }
      await StorageService.scanSessionsBox.delete(sessionId);
      _loadScanSessions();
      debugPrint('✅ Scan session and associated files deleted successfully');
    } else {
      debugPrint('⚠️ Scan session not found for deletion: $sessionId');
    }
  }

  ScanSessionModel? getScanSession(String sessionId) {
    final session = StorageService.scanSessionsBox.get(sessionId);
    debugPrint('🔍 Retrieved scan session: ${session?.id ?? 'Not found'}');
    return session;
  }

  List<ScanSessionModel> getIncompleteSessions() {
    final incomplete = state.where((session) => !session.isCompleted).toList();
    debugPrint('📋 Found ${incomplete.length} incomplete scan sessions');
    return incomplete;
  }

  Future<void> markSessionCompleted(String sessionId) async {
    debugPrint('✅ Marking scan session as completed: $sessionId');
    final session = getScanSession(sessionId);
    if (session != null) {
      final updatedSession = session.copyWith(isCompleted: true);
      await updateScanSession(updatedSession);
      debugPrint('✅ Scan session marked as completed');
    } else {
      debugPrint('⚠️ Session not found for completion: $sessionId');
    }
  }
}

class SaveLocationNotifier extends StateNotifier<String?> {
  SaveLocationNotifier() : super(null) {
    debugPrint('📁 Initializing SaveLocationNotifier');
    _loadSaveLocation();
  }

  Future<void> _loadSaveLocation() async {
    debugPrint('📖 Loading save location setting...');
    final userLocation = StorageService.getSaveLocation();

    if (userLocation != null) {
      // Show user-friendly name for user-selected location
      final displayName = userLocation.split('/').last;
      final finalDisplayName = displayName.isNotEmpty ? displayName : 'Custom Location';
      debugPrint('📁 User has custom location: $finalDisplayName ($userLocation)');
      state = finalDisplayName;
    } else {
      // Check if external storage is available
      final externalDir = await StorageService.getExternalAppDirectory();
      if (externalDir != null) {
        debugPrint('📁 Using external app storage location');
        state = 'External App Storage (Default)';
      } else {
        debugPrint('📁 Using internal app storage location');
        state = 'Internal App Storage (Default)';
      }
    }
  }

  Future<void> setSaveLocation(String path) async {
    debugPrint('💾 Setting new save location: $path');
    await StorageService.setSaveLocation(path);

    // Update display name
    final displayName = path.split('/').last;
    final finalDisplayName = displayName.isNotEmpty ? displayName : 'Custom Location';
    state = finalDisplayName;
    debugPrint('✅ Save location updated to: $finalDisplayName');
  }

  Future<void> resetToDefault() async {
    debugPrint('🔄 Resetting save location to default');
    // Remove user location setting to fall back to default
    await StorageService.settingsBox.delete('save_location');

    // Check what the default will be
    final externalDir = await StorageService.getExternalAppDirectory();
    if (externalDir != null) {
      state = 'External App Storage (Default)';
    } else {
      state = 'Internal App Storage (Default)';
    }
    debugPrint('✅ Save location reset to default');
  }

  /// Get detailed status information about current storage
  Future<Map<String, dynamic>> getStorageStatus() async {
    debugPrint('📊 Getting detailed storage status...');
    final status = await StorageService.getSaveLocationStatus();
    debugPrint('📊 Storage status retrieved: ${status['message']}');
    return status;
  }
}
