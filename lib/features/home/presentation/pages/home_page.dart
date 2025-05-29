import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:document_scanner/core/providers/theme_provider.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
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
                    _buildStatItem(icon: Icons.lock, label: 'Encrypted', count: documents.where((d) => d.isEncrypted).length, theme: theme),
                  ],
                ),
              )
              : null,
    );
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
