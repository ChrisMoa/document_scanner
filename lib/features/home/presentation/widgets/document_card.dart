import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:document_scanner/core/models/document_model.dart';

class DocumentCard extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const DocumentCard({
    super.key,
    required this.document,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: 'Delete',
          ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildThumbnail(theme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${document.imagePaths.length} page${document.imagePaths.length != 1 ? 's' : ''}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(document.updatedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    if (document.isUploaded)
                      Icon(
                        Icons.cloud_done,
                        color: Colors.green,
                        size: 20,
                      ),
                    if (document.isEncrypted)
                      Icon(
                        Icons.lock,
                        color: Colors.orange,
                        size: 20,
                      ),
                    if (document.pdfPath != null)
                      Icon(
                        Icons.picture_as_pdf,
                        color: Colors.red,
                        size: 20,
                      ),
                    const Icon(
                      Icons.chevron_right,
                      color: Colors.grey,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    if (document.imagePaths.isEmpty) {
      return Container(
        width: 60,
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Icon(
          Icons.description,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          size: 32,
        ),
      );
    }

    final firstImagePath = document.imagePaths.first;
    final file = File(firstImagePath);

    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: FutureBuilder<bool>(
          future: file.exists(),
          builder: (context, snapshot) {
            if (snapshot.data == true) {
              return Stack(
                children: [
                  Image.file(
                    file,
                    fit: BoxFit.cover,
                    width: 60,
                    height: 80,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildErrorThumbnail(theme);
                    },
                  ),
                  if (document.imagePaths.length > 1)
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '+${document.imagePaths.length - 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            } else {
              return _buildErrorThumbnail(theme);
            }
          },
        ),
      ),
    );
  }

  Widget _buildErrorThumbnail(ThemeData theme) {
    return Container(
      width: 60,
      height: 80,
      decoration: BoxDecoration(
        color: theme.colorScheme.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Icon(
        Icons.broken_image,
        color: theme.colorScheme.error,
        size: 24,
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

