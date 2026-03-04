import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:document_scanner/core/providers/theme_provider.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
import 'package:document_scanner/core/services/download_service.dart';
import 'package:document_scanner/features/home/presentation/widgets/document_card.dart';
import 'package:document_scanner/features/home/presentation/widgets/empty_state_widget.dart';
import 'package:document_scanner/features/home/presentation/widgets/search_bar_widget.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  String _searchQuery = '';
  bool _showSearchBar = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final documents = ref.watch(documentsProvider);

    final filteredDocuments = _searchQuery.isEmpty ? documents : documents.where((doc) => doc.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title:
            _showSearchBar
                ? SearchBarWidget(
                  onChanged: (query) => setState(() => _searchQuery = query),
                  onClear:
                      () => setState(() {
                        _searchQuery = '';
                        _showSearchBar = false;
                      }),
                )
                : const Text('Document Scanner'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          if (!_showSearchBar) ...[
            IconButton(icon: const Icon(Icons.search), onPressed: () => setState(() => _showSearchBar = true)),
            IconButton(icon: const Icon(Icons.download), onPressed: _downloadAllDocuments, tooltip: 'Download All Documents'),
            IconButton(icon: const Icon(Icons.brightness_6), onPressed: () => ref.read(themeProvider.notifier).toggleTheme()),
            IconButton(icon: const Icon(Icons.settings), onPressed: () => context.push('/settings')),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(documentsProvider);
        },
        child:
            filteredDocuments.isEmpty
                ? EmptyStateWidget(hasDocuments: documents.isNotEmpty, searchQuery: _searchQuery)
                : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredDocuments.length,
                  itemBuilder: (context, index) {
                    final document = filteredDocuments[index];
                    return DocumentCard(document: document, onTap: () => context.push('/document/${document.id}'), onDelete: () => _showDeleteDialog(document.id));
                  },
                ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/enhanced-camera'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan'),
      ),
      bottomNavigationBar:
          documents.isNotEmpty
              ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: theme.cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, -2))]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildStatItem(icon: Icons.description, label: 'Documents', count: documents.length, theme: theme),
                    _buildStatItem(icon: Icons.cloud_upload, label: 'Uploaded', count: documents.where((d) => d.isUploaded).length, theme: theme),
                    _buildStatItem(icon: Icons.download_done, label: 'Downloaded', count: documents.where((d) => d.isDownloaded).length, theme: theme),
                    _buildStatItem(icon: Icons.lock, label: 'Encrypted', count: documents.where((d) => d.isEncrypted).length, theme: theme),
                  ],
                ),
              )
              : null,
    );
  }

  Future<void> _downloadAllDocuments() async {
    debugPrint('📥 Starting download all documents');

    final documents = ref.read(documentsProvider);

    // Show progress dialog while checking for documents
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Checking for documents...')])),
    );

    try {
      // Get download statistics (includes cloud documents)
      final stats = await DownloadService.getDownloadStats(documents);

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      // Check if any documents are available
      if (stats.totalDocuments == 0) {
        // Show helpful dialog when no documents exist anywhere
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('No Documents Found'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('No documents found locally or in the cloud.'),
                    const SizedBox(height: 16),
                    if (!stats.oneDriveConnected) ...[
                      const Text('💡 To download cloud documents:'),
                      const SizedBox(height: 8),
                      const Text('1. Connect to Nextcloud in Settings'),
                      const Text('2. Upload documents from other devices'),
                      const Text('3. Return here to download them'),
                      const SizedBox(height: 16),
                    ],
                    const Text('📱 To create local documents:'),
                    const SizedBox(height: 8),
                    const Text('1. Tap the "Scan" button to create documents'),
                    const Text('2. Scan documents using your camera'),
                    const Text('3. Come back to download all your documents to any folder'),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
                  if (!stats.oneDriveConnected)
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        context.push('/settings');
                      },
                      child: const Text('Go to Settings'),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push('/enhanced-camera');
                    },
                    child: const Text('Start Scanning'),
                  ),
                ],
              ),
        );
        return;
      }

      // Show download statistics dialog first
      final shouldProceed = await _showDownloadDialog(stats);

      if (!shouldProceed) return;
    } catch (e) {
      // Close progress dialog if still open
      if (mounted) Navigator.of(context).pop();

      debugPrint('❌ Error checking documents: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error checking documents: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
      }
      return;
    }

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(content: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Downloading documents...')])),
    );

    try {
      // Download all documents
      final result = await DownloadService.downloadAllDocuments(documents);

      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      // Mark successfully downloaded documents as synced
      if (result.success && result.downloadedCount > 0) {
        await DownloadService.markDocumentsAsDownloaded(documents);
        // Refresh the UI to show updated download status and any imported cloud documents
        ref.invalidate(documentsProvider);
        debugPrint('📱 UI refreshed to show imported cloud documents');
      }

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message), backgroundColor: result.success ? Colors.green : Colors.red, duration: const Duration(seconds: 4)));
      }
    } catch (e) {
      // Close progress dialog
      if (mounted) Navigator.of(context).pop();

      debugPrint('❌ Download failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Download failed: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 4)));
      }
    }
  }

  Future<bool> _showDownloadDialog(DownloadStats stats) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Download All Documents'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Download summary:'),
                    const SizedBox(height: 12),
                    Text('• Total documents: ${stats.totalDocuments}'),
                    if (stats.localDocuments > 0) Text('• Local documents: ${stats.localDocuments}'),
                    if (stats.cloudDocuments > 0) Text('• Cloud documents: ${stats.cloudDocuments}'),
                    Text('• Available for download: ${stats.availableForDownload}'),
                    Text('• Already downloaded: ${stats.downloadedDocuments}'),
                    if (stats.encryptedDocuments > 0) Text('• Encrypted documents: ${stats.encryptedDocuments}'),
                    const SizedBox(height: 16),
                    if (stats.cloudDocuments > 0) ...[
                      Row(
                        children: [
                          Icon(stats.oneDriveConnected ? Icons.cloud_done : Icons.cloud_off, size: 16, color: stats.oneDriveConnected ? Colors.green : Colors.red),
                          const SizedBox(width: 4),
                          Text(stats.oneDriveConnected ? 'Nextcloud connected' : 'Nextcloud disconnected', style: TextStyle(color: stats.oneDriveConnected ? Colors.green : Colors.red, fontSize: 12)),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    const Text(
                      'Encrypted documents will be decrypted if you have the password, '
                      'otherwise they will be saved as encrypted files.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                  ElevatedButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Download')),
                ],
              ),
        ) ??
        false;
  }

  Widget _buildStatItem({required IconData icon, required String label, required int count, required ThemeData theme}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: theme.colorScheme.primary, size: 24),
        const SizedBox(height: 4),
        Text(count.toString(), style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
      ],
    );
  }

  void _showDeleteDialog(String documentId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Document'),
            content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  ref.read(documentsProvider.notifier).deleteDocument(documentId);
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document deleted')));
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }
}
