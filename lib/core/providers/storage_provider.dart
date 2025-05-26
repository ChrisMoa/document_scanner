import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/models/scan_session_model.dart';

final documentsProvider = StateNotifierProvider<DocumentsNotifier, List<DocumentModel>>((ref) => DocumentsNotifier());

final scanSessionsProvider = StateNotifierProvider<ScanSessionsNotifier, List<ScanSessionModel>>((ref) => ScanSessionsNotifier());

final saveLocationProvider = StateNotifierProvider<SaveLocationNotifier, String?>((ref) => SaveLocationNotifier());

class DocumentsNotifier extends StateNotifier<List<DocumentModel>> {
  DocumentsNotifier() : super([]) {
    _loadDocuments();
  }

  void _loadDocuments() {
    final documents = StorageService.documentsBox.values.toList();
    documents.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    state = documents;
  }

  Future<void> addDocument(DocumentModel document) async {
    await StorageService.documentsBox.put(document.id, document);
    _loadDocuments();
  }

  Future<void> updateDocument(DocumentModel document) async {
    final updatedDocument = document.copyWith(updatedAt: DateTime.now());
    await StorageService.documentsBox.put(updatedDocument.id, updatedDocument);
    _loadDocuments();
  }

  Future<void> deleteDocument(String documentId) async {
    final document = StorageService.documentsBox.get(documentId);
    if (document != null) {
      for (final imagePath in document.imagePaths) {
        await StorageService.deleteFile(imagePath);
      }

      if (document.pdfPath != null) {
        await StorageService.deleteFile(document.pdfPath!);
      }

      await StorageService.documentsBox.delete(documentId);
      _loadDocuments();
    }
  }

  DocumentModel? getDocument(String documentId) {
    return StorageService.documentsBox.get(documentId);
  }

  List<DocumentModel> getDocumentsByName(String name) {
    return state.where((doc) => doc.name.toLowerCase().contains(name.toLowerCase())).toList();
  }

  List<DocumentModel> getUploadedDocuments() {
    return state.where((doc) => doc.isUploaded).toList();
  }

  List<DocumentModel> getEncryptedDocuments() {
    return state.where((doc) => doc.isEncrypted).toList();
  }
}

class ScanSessionsNotifier extends StateNotifier<List<ScanSessionModel>> {
  ScanSessionsNotifier() : super([]) {
    _loadScanSessions();
  }

  void _loadScanSessions() {
    final sessions = StorageService.scanSessionsBox.values.toList();
    sessions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = sessions;
  }

  Future<void> addScanSession(ScanSessionModel session) async {
    await StorageService.scanSessionsBox.put(session.id, session);
    _loadScanSessions();
  }

  Future<void> updateScanSession(ScanSessionModel session) async {
    await StorageService.scanSessionsBox.put(session.id, session);
    _loadScanSessions();
  }

  Future<void> deleteScanSession(String sessionId) async {
    final session = StorageService.scanSessionsBox.get(sessionId);
    if (session != null) {
      for (final imagePath in session.imagePaths) {
        await StorageService.deleteFile(imagePath);
      }
      await StorageService.scanSessionsBox.delete(sessionId);
      _loadScanSessions();
    }
  }

  ScanSessionModel? getScanSession(String sessionId) {
    return StorageService.scanSessionsBox.get(sessionId);
  }

  List<ScanSessionModel> getIncompleteSessions() {
    return state.where((session) => !session.isCompleted).toList();
  }

  Future<void> markSessionCompleted(String sessionId) async {
    final session = getScanSession(sessionId);
    if (session != null) {
      final updatedSession = session.copyWith(isCompleted: true);
      await updateScanSession(updatedSession);
    }
  }
}

class SaveLocationNotifier extends StateNotifier<String?> {
  SaveLocationNotifier() : super(null) {
    _loadSaveLocation();
  }

  Future<void> _loadSaveLocation() async {
    final userLocation = StorageService.getSaveLocation();
    if (userLocation != null) {
      // Show user-friendly name for user-selected location
      final displayName = userLocation.split('/').last;
      state = displayName.isNotEmpty ? displayName : 'Custom Location';
    } else {
      state = 'App Internal Storage (Default)';
    }
  }

  Future<void> setSaveLocation(String path) async {
    await StorageService.setSaveLocation(path);
    // Update display name
    final displayName = path.split('/').last;
    state = displayName.isNotEmpty ? displayName : 'Custom Location';
  }

  Future<void> resetToDefault() async {
    // Remove user location setting to fall back to default
    await StorageService.settingsBox.delete('save_location');
    state = 'App Internal Storage (Default)';
  }

  /// Get detailed status information about current storage
  Future<Map<String, dynamic>> getStorageStatus() async {
    return await StorageService.getSaveLocationStatus();
  }
}
