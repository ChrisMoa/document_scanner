// lib/features/document/presentation/widgets/image_grid_view.dart
import 'dart:io';
import 'package:flutter/material.dart';

class ImageGridView extends StatelessWidget {
  final List<File> images;
  final Function(int) onImageTap;
  final Function(int, int) onReorder;
  final EdgeInsetsGeometry? padding;

  const ImageGridView({super.key, required this.images, required this.onImageTap, required this.onReorder, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ReorderableGridView(
      padding: padding ?? const EdgeInsets.all(8.0),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.75,
      itemCount: images.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        return _ImageGridItem(key: ValueKey(images[index].path), imagePath: images[index].path, index: index, onTap: () => onImageTap(index), theme: theme);
      },
    );
  }
}

class _ImageGridItem extends StatelessWidget {
  final String imagePath;
  final int index;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ImageGridItem({super.key, required this.imagePath, required this.index, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(children: [_buildImage(), _buildOverlay(), _buildPageNumber(), _buildReorderHandle()]),
              ),
            ),
            _buildImageInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return FutureBuilder<bool>(
      future: File(imagePath).exists(),
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Image.file(
            File(imagePath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              debugPrint('Error loading image $imagePath: $error');
              return _buildErrorWidget();
            },
          );
        } else {
          return _buildErrorWidget();
        }
      },
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      color: theme.colorScheme.error.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.broken_image, color: theme.colorScheme.error, size: 32),
            const SizedBox(height: 8),
            Text('Image not found', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withOpacity(0.3), Colors.transparent, Colors.transparent, Colors.black.withOpacity(0.5)],
        ),
      ),
    );
  }

  Widget _buildPageNumber() {
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(12)),
        child: Text('Page ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildReorderHandle() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.drag_handle, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildImageInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Page ${index + 1}', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          FutureBuilder<FileStat>(
            future: File(imagePath).stat(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                final stat = snapshot.data as FileStat;
                final sizeInKB = (stat.size / 1024).round();
                return Text('${sizeInKB}KB', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)));
              }
              return Text('Loading...', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)));
            },
          ),
        ],
      ),
    );
  }
}

class ReorderableGridView extends StatefulWidget {
  final int crossAxisCount;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Function(int, int) onReorder;
  final EdgeInsetsGeometry? padding;

  const ReorderableGridView({
    super.key,
    required this.crossAxisCount,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.childAspectRatio,
    required this.itemCount,
    required this.itemBuilder,
    required this.onReorder,
    this.padding,
  });

  @override
  State<ReorderableGridView> createState() => _ReorderableGridViewState();
}

class _ReorderableGridViewState extends State<ReorderableGridView> {
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      padding: widget.padding as EdgeInsets?,
      itemCount: (widget.itemCount / widget.crossAxisCount).ceil(),
      onReorder: (oldIndex, newIndex) {
        final oldRowIndex = oldIndex;
        final newRowIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;

        for (int i = 0; i < widget.crossAxisCount; i++) {
          final oldItemIndex = oldRowIndex * widget.crossAxisCount + i;
          final newItemIndex = newRowIndex * widget.crossAxisCount + i;

          if (oldItemIndex < widget.itemCount && newItemIndex < widget.itemCount) {
            widget.onReorder(oldItemIndex, newItemIndex);
            break;
          }
        }
      },
      itemBuilder: (context, rowIndex) {
        return _buildRow(rowIndex);
      },
    );
  }

  Widget _buildRow(int rowIndex) {
    final startIndex = rowIndex * widget.crossAxisCount;
    final endIndex = (startIndex + widget.crossAxisCount).clamp(0, widget.itemCount);

    return Container(
      key: ValueKey('row_$rowIndex'),
      margin: EdgeInsets.symmetric(vertical: widget.mainAxisSpacing / 2),
      child: Row(
        children: [
          for (int i = startIndex; i < endIndex; i++) ...[
            Expanded(
              child: Container(margin: EdgeInsets.symmetric(horizontal: widget.crossAxisSpacing / 2), child: AspectRatio(aspectRatio: widget.childAspectRatio, child: widget.itemBuilder(context, i))),
            ),
          ],
          // Fill remaining space if last row is incomplete
          for (int i = endIndex; i < startIndex + widget.crossAxisCount; i++) Expanded(child: Container()),
        ],
      ),
    );
  }
}
