import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class EmptyStateWidget extends StatelessWidget {
  final bool hasDocuments;
  final String searchQuery;

  const EmptyStateWidget({super.key, required this.hasDocuments, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (searchQuery.isNotEmpty) {
      return _buildSearchEmptyState(theme);
    }

    return _buildNoDocumentsState(context, theme);
  }

  Widget _buildSearchEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('No documents found', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          const SizedBox(height: 8),
          Text('No documents match "$searchQuery"', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildNoDocumentsState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(Icons.document_scanner, size: 64, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text('No documents yet', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
            const SizedBox(height: 12),
            Text(
              'Start scanning documents by tapping the camera button below. Your scanned documents will appear here.',
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                GoRouter.of(context).push('/camera');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Start Scanning'),
            ),
            const SizedBox(height: 16),
            Text('Or learn more about the features in Settings', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }
}
