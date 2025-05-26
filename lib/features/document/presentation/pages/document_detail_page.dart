import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/services/pdf_service.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/services/onedrive_service.dart';
import 'package:document_scanner/core/services/encryption_service.dart';
import 'package:document_scanner/features/document/presentation/widgets/image_grid_view.dart';
import 'package:document_scanner/features/document/presentation/widgets/document_actions.dart';

class DocumentDetailPage extends ConsumerStatefulWidget {
  final String documentId;

  const DocumentDetailPage({super.key, required this.documentId});

  @override
  ConsumerState<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends ConsumerState<DocumentDetailPage> {
  DocumentModel? _document;
  bool _isGeneratingPdf = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  void _loadDocument() {
    final document = ref.read(documentsProvider.notifier).getDocument(widget.documentId);
    setState(() {
      _document = document;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_document == null) {
      return Scaffold(appBar: AppBar(title: const Text('Document Not Found')), body: const Center(child: Text('Document not found or has been deleted.')));
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(_document!.name),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(value),
            itemBuilder:
                (context) => [
                  const PopupMenuItem(value: 'rename', child: ListTile(leading: Icon(Icons.edit), title: Text('Rename'))),
                  const PopupMenuItem(value: 'share', child: ListTile(leading: Icon(Icons.share), title: Text('Share'))),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.delete, color: Colors.red), title: Text('Delete', style: TextStyle(color: Colors.red)))),
                ],
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: theme.cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_document!.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(
                            '${_document!.imagePaths.length} page${_document!.imagePaths.length != 1 ? 's' : ''}',
                            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                          ),
                          Text('Created: ${_formatDate(_document!.createdAt)}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                          if (_document!.storageLocation != null)
                            Text('Saved to: ${_document!.storageLocation}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary.withOpacity(0.8))),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        if (_document!.isUploaded)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Icon(Icons.cloud_done, color: Colors.green, size: 16), const SizedBox(width: 4), Text('Uploaded', style: TextStyle(color: Colors.green, fontSize: 12))],
                            ),
                          ),
                        if (_document!.isEncrypted)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [Icon(Icons.lock, color: Colors.orange, size: 16), const SizedBox(width: 4), Text('Encrypted', style: TextStyle(color: Colors.orange, fontSize: 12))],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DocumentActions(
                  document: _document!,
                  onGeneratePdf: _generatePdf,
                  onUploadToCloud: _uploadToCloud,
                  onPreviewPdf: _previewPdf,
                  isGeneratingPdf: _isGeneratingPdf,
                  isUploading: _isUploading,
                ),
              ],
            ),
          ),
          Expanded(
            child:
                _document!.imagePaths.isEmpty
                    ? const Center(child: Text('No images in this document'))
                    : ImageGridView(images: _document!.imagePaths.map((p) => File(p)).toList(), onImageTap: (index) => _showImageViewer(index), onReorder: _reorderImages),
          ),
        ],
      ),
    );
  }

  Future<void> _generatePdf() async {
    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      debugPrint('📄 Generating PDF for document: ${_document!.name}');
      debugPrint('📂 Current save location status:');
      final saveStatus = await StorageService.getSaveLocationStatus();
      debugPrint('   - Location: ${saveStatus['location']}');
      debugPrint('   - Can write: ${saveStatus['canWrite']}');
      debugPrint('   - Message: ${saveStatus['message']}');

      // Check if all images exist before generating PDF
      debugPrint('🔍 Checking image files before PDF generation:');
      for (int i = 0; i < _document!.imagePaths.length; i++) {
        final imagePath = _document!.imagePaths[i];
        final exists = await File(imagePath).exists();
        debugPrint('   Image $i: $imagePath (exists: $exists)');
      }

      final pdfData = await PdfService.createPdfFromImages(_document!.imagePaths, _document!.name);

      final fileName = PdfService.generateFileName(_document!.name);
      debugPrint('💾 Saving PDF with filename: $fileName');
      final pdfPath = await StorageService.savePdfFile(pdfData, fileName);
      debugPrint('✅ PDF saved to: $pdfPath');

      // Get storage location info for display
      final storageDisplayName = StorageService.getStorageLocationDisplayName(pdfPath);
      debugPrint('📁 Storage location: $storageDisplayName');

      final updatedDocument = _document!.copyWith(pdfPath: pdfPath, storageLocation: storageDisplayName);
      await ref.read(documentsProvider.notifier).updateDocument(updatedDocument);

      setState(() {
        _document = updatedDocument;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF generated successfully')));
      }
    } catch (e) {
      debugPrint('❌ Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
  }

  Future<void> _uploadToCloud() async {
    if (!OneDriveService.isAuthenticated) {
      _showCloudNotConnectedDialog();
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      Uint8List? dataToUpload;
      String fileName;

      if (_document!.pdfPath != null && await StorageService.fileExists(_document!.pdfPath!)) {
        final pdfFile = File(_document!.pdfPath!);
        dataToUpload = await pdfFile.readAsBytes();
        fileName = '${_document!.name}.pdf';
      } else {
        final pdfData = await PdfService.createPdfFromImages(_document!.imagePaths, _document!.name);
        dataToUpload = pdfData;
        fileName = '${_document!.name}.pdf';
      }

      if (_document!.isEncrypted && _document!.encryptionKeyId != null) {
        dataToUpload = await EncryptionService.encryptData(dataToUpload, _document!.encryptionKeyId!);
        fileName = '$fileName.encrypted';
      }

      final cloudUrl = await OneDriveService.uploadFile(dataToUpload, fileName);

      if (cloudUrl != null) {
        final updatedDocument = _document!.copyWith(isUploaded: true, cloudUrl: cloudUrl);
        await ref.read(documentsProvider.notifier).updateDocument(updatedDocument);

        setState(() {
          _document = updatedDocument;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded to OneDrive')));
        }
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  void _previewPdf() {
    if (_document!.pdfPath != null) {
      context.push('/pdf-preview/${_document!.id}');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please generate PDF first')));
    }
  }

  void _showImageViewer(int initialIndex) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => _ImageViewerPage(imagePaths: _document!.imagePaths, initialIndex: initialIndex)));
  }

  Future<void> _reorderImages(int oldIndex, int newIndex) async {
    final imagePaths = List<String>.from(_document!.imagePaths);
    if (newIndex > oldIndex) {
      newIndex--;
    }
    final item = imagePaths.removeAt(oldIndex);
    imagePaths.insert(newIndex, item);

    final updatedDocument = _document!.copyWith(imagePaths: imagePaths);
    await ref.read(documentsProvider.notifier).updateDocument(updatedDocument);

    setState(() {
      _document = updatedDocument;
    });
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'rename':
        _showRenameDialog();
        break;
      case 'share':
        _shareDocument();
        break;
      case 'delete':
        _showDeleteDialog();
        break;
    }
  }

  void _showRenameDialog() {
    final controller = TextEditingController(text: _document!.name);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rename Document'),
            content: TextField(controller: controller, decoration: const InputDecoration(labelText: 'Document Name', border: OutlineInputBorder())),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isNotEmpty && newName != _document!.name) {
                    final updatedDocument = _document!.copyWith(name: newName);
                    await ref.read(documentsProvider.notifier).updateDocument(updatedDocument);
                    setState(() {
                      _document = updatedDocument;
                    });
                  }
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Rename'),
              ),
            ],
          ),
    );
  }

  void _shareDocument() {
    // TODO: Implement sharing functionality
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sharing feature coming soon')));
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Document'),
            content: const Text('Are you sure you want to delete this document? This action cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  await ref.read(documentsProvider.notifier).deleteDocument(_document!.id);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    context.pop();
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  void _showCloudNotConnectedDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('OneDrive Not Connected'),
            content: const Text('Please connect to OneDrive in Settings before uploading documents.'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/cloud-settings');
                },
                child: const Text('Go to Settings'),
              ),
            ],
          ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _ImageViewerPage extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;

  const _ImageViewerPage({required this.imagePaths, required this.initialIndex});

  @override
  State<_ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<_ImageViewerPage> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.black, foregroundColor: Colors.white, title: Text('${_currentIndex + 1} of ${widget.imagePaths.length}')),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imagePaths.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.file(
                File(widget.imagePaths[index]),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 64));
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
