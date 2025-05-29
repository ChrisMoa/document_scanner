import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
import 'package:document_scanner/core/providers/theme_provider.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/services/pdf_service.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/services/onedrive_service.dart';
import 'package:document_scanner/core/services/encryption_service.dart';
import 'package:document_scanner/core/services/document_scanner_service.dart';
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
  bool _isAddingPages = false;
  Map<String, dynamic>? _pdfInfo;

  @override
  void initState() {
    super.initState();
    debugPrint('📄 DocumentDetailPage initialized for document: ${widget.documentId}');
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    debugPrint('📖 Loading document: ${widget.documentId}');

    final document = ref.read(documentsProvider.notifier).getDocument(widget.documentId);

    if (document != null) {
      debugPrint('🔍 Retrieved document: ${document.name} (ID: ${document.id})');
      setState(() {
        _document = document;
      });

      // If it's a PDF, get detailed info
      if (document.pdfPath != null) {
        await _analyzePdfFile(document.pdfPath!);
      }

      debugPrint('📖 Document loaded: ${document.name}');
    } else {
      debugPrint('❌ Document not found: ${widget.documentId}');
    }
  }

  Future<void> _analyzePdfFile(String pdfPath) async {
    try {
      debugPrint('🔍 Analyzing PDF file: $pdfPath');

      final file = File(pdfPath);
      final exists = await file.exists();

      final info = <String, dynamic>{'path': pdfPath, 'exists': exists, 'size': 0, 'isValid': false, 'error': null};

      if (exists) {
        try {
          final size = await file.length();
          info['size'] = size;

          if (size > 0) {
            // Check PDF header
            final bytes = await file.readAsBytes();
            if (bytes.length >= 4 && bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46) {
              info['isValid'] = true;
              debugPrint('✅ PDF file is valid: $size bytes');
            } else {
              info['error'] = 'Invalid PDF header';
              debugPrint('❌ Invalid PDF header');
            }
          } else {
            info['error'] = 'Empty file';
            debugPrint('❌ PDF file is empty');
          }
        } catch (e) {
          info['error'] = 'Read error: $e';
          debugPrint('❌ Error reading PDF: $e');
        }
      } else {
        info['error'] = 'File does not exist';
        debugPrint('❌ PDF file does not exist: $pdfPath');
      }

      setState(() {
        _pdfInfo = info;
      });
    } catch (e) {
      debugPrint('❌ Error analyzing PDF: $e');
      setState(() {
        _pdfInfo = {'error': 'Analysis failed: $e'};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider) == ThemeMode.dark ? Theme.of(context).copyWith(brightness: Brightness.dark) : Theme.of(context).copyWith(brightness: Brightness.light);

    if (_document == null) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(title: const Text('Document Not Found'), backgroundColor: theme.appBarTheme.backgroundColor, foregroundColor: theme.appBarTheme.foregroundColor),
        body: const Center(child: Text('Document not found or has been deleted.')),
      );
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
                  onAddPages: _addPages,
                  isGeneratingPdf: _isGeneratingPdf,
                  isUploading: _isUploading,
                  isAddingPages: _isAddingPages,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PDF Debug Information (if available)
                  if (_pdfInfo != null && _document?.pdfPath != null) ...[
                    Card(
                      color: _pdfInfo!['isValid'] == true ? Colors.green.shade50 : Colors.red.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(_pdfInfo!['isValid'] == true ? Icons.check_circle : Icons.error, color: _pdfInfo!['isValid'] == true ? Colors.green : Colors.red),
                                const SizedBox(width: 8),
                                Text('PDF File Information', style: TextStyle(fontWeight: FontWeight.bold, color: _pdfInfo!['isValid'] == true ? Colors.green.shade700 : Colors.red.shade700)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildInfoRow('File Exists', _pdfInfo!['exists']?.toString() ?? 'Unknown'),
                            _buildInfoRow('File Size', '${_pdfInfo!['size'] ?? 0} bytes'),
                            _buildInfoRow('Valid PDF', _pdfInfo!['isValid']?.toString() ?? 'Unknown'),
                            if (_pdfInfo!['error'] != null) _buildInfoRow('Error', _pdfInfo!['error'].toString()),
                            const SizedBox(height: 8),
                            Text('Path: ${_pdfInfo!['path']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Document metadata
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Document Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildInfoRow('Name', _document!.name),
                          _buildInfoRow('Created', _formatDate(_document!.createdAt)),
                          _buildInfoRow('Updated', _formatDate(_document!.updatedAt)),
                          _buildInfoRow('Type', _document!.pdfPath != null ? 'PDF Document' : 'Image Document'),
                          if (_document!.pdfPath != null) _buildInfoRow('Pages', _document!.imagePaths.isEmpty ? 'Unknown' : '${_document!.imagePaths.length}'),
                          if (_document!.imagePaths.isNotEmpty) _buildInfoRow('Images', '${_document!.imagePaths.length}'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
    debugPrint('📄 Starting PDF generation for document: ${_document!.name}');
    setState(() {
      _isGeneratingPdf = true;
    });

    try {
      debugPrint('📂 Checking storage location status...');
      final saveStatus = await StorageService.getSaveLocationStatus();
      debugPrint('📂 Save location: ${saveStatus['location']}');
      debugPrint('📂 Can write: ${saveStatus['canWrite']}');
      debugPrint('📂 Message: ${saveStatus['message']}');

      // Check if all images exist before generating PDF
      debugPrint('🔍 Validating image files before PDF generation:');
      for (int i = 0; i < _document!.imagePaths.length; i++) {
        final imagePath = _document!.imagePaths[i];
        final exists = await File(imagePath).exists();
        debugPrint('   Image $i: $imagePath (exists: $exists)');
        if (!exists) {
          throw Exception('Image file not found: $imagePath');
        }
      }

      debugPrint('📄 Creating PDF from ${_document!.imagePaths.length} images...');
      final pdfData = await PdfService.createPdfFromImages(
        _document!.imagePaths,
        _document!.name,
      ).timeout(const Duration(minutes: 2), onTimeout: () => throw Exception('PDF generation timed out after 2 minutes'));

      final fileName = PdfService.generateFileName(_document!.name);
      debugPrint('💾 Generated PDF filename: $fileName');
      debugPrint('📄 PDF generated successfully, size: ${pdfData.length} bytes');

      // Show user choice for PDF saving with timeout
      final saveChoice = await _showPdfSaveDialog().timeout(
        const Duration(minutes: 1),
        onTimeout: () {
          debugPrint('⚠️ PDF save dialog timed out, using app storage');
          return 'app';
        },
      );

      String pdfPath;
      if (saveChoice == 'saf') {
        // Use SAF to let user choose location
        debugPrint('💾 User chose SAF for PDF saving');
        try {
          pdfPath = await StorageService.savePdfFile(pdfData, fileName).timeout(const Duration(minutes: 2), onTimeout: () => throw Exception('File save operation timed out'));
        } catch (e) {
          debugPrint('❌ SAF save failed: $e, falling back to app storage');
          pdfPath = await StorageService.savePdfFileToAppStorage(pdfData, fileName);
        }
      } else {
        // Save to app storage
        debugPrint('💾 User chose app storage for PDF saving');
        pdfPath = await StorageService.savePdfFileToAppStorage(pdfData, fileName);
      }

      debugPrint('✅ PDF saved successfully to: $pdfPath');

      // Verify the saved file exists
      final savedFile = File(pdfPath);
      if (!await savedFile.exists()) {
        throw Exception('PDF file was not saved properly');
      }

      final fileSize = await savedFile.length();
      debugPrint('✅ PDF file verified: $pdfPath (${fileSize} bytes)');

      // Get storage location info for display
      final storageDisplayName = StorageService.getStorageLocationDisplayName(pdfPath);
      debugPrint('📁 Storage location display name: $storageDisplayName');

      final updatedDocument = _document!.copyWith(pdfPath: pdfPath, storageLocation: storageDisplayName);
      await ref.read(documentsProvider.notifier).updateDocument(updatedDocument);

      setState(() {
        _document = updatedDocument;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF generated successfully'), backgroundColor: Colors.green));
      }
    } catch (e) {
      debugPrint('❌ Error generating PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() {
        _isGeneratingPdf = false;
      });
    }
  }

  Future<String?> _showPdfSaveDialog() async {
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Save PDF'),
            content: const Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose where to save your PDF:'),
                SizedBox(height: 12),
                Text('• Choose Location: Select any folder on your device'),
                Text('• App Storage: Save to app folder (accessible via file manager)'),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop('app'), child: const Text('App Storage')),
              ElevatedButton(onPressed: () => Navigator.of(context).pop('saf'), child: const Text('Choose Location')),
            ],
          ),
    );
  }

  Future<void> _uploadToCloud() async {
    if (!OneDriveService.isAuthenticated) {
      debugPrint('☁️ OneDrive not authenticated, showing dialog');
      _showCloudNotConnectedDialog();
      return;
    }

    debugPrint('☁️ Starting cloud upload for document: ${_document!.name}');
    setState(() {
      _isUploading = true;
    });

    try {
      Uint8List? dataToUpload;
      String fileName;

      if (_document!.pdfPath != null && await StorageService.fileExists(_document!.pdfPath!)) {
        debugPrint('📄 Uploading existing PDF file');
        final pdfFile = File(_document!.pdfPath!);
        dataToUpload = await pdfFile.readAsBytes();
        fileName = '${_document!.name}.pdf';
      } else {
        debugPrint('📄 Generating PDF for upload');
        final pdfData = await PdfService.createPdfFromImages(_document!.imagePaths, _document!.name);
        dataToUpload = pdfData;
        fileName = '${_document!.name}.pdf';
      }

      if (_document!.isEncrypted && _document!.encryptionKeyId != null) {
        debugPrint('🔒 Encrypting data before upload');
        dataToUpload = await EncryptionService.encryptData(dataToUpload, _document!.encryptionKeyId!);
        fileName = '$fileName.encrypted';
      }

      debugPrint('☁️ Uploading to OneDrive: $fileName (${dataToUpload.length} bytes)');
      final cloudUrl = await OneDriveService.uploadFile(dataToUpload, fileName);

      if (cloudUrl != null) {
        debugPrint('✅ Upload successful: $cloudUrl');
        final updatedDocument = _document!.copyWith(isUploaded: true, cloudUrl: cloudUrl);
        await ref.read(documentsProvider.notifier).updateDocument(updatedDocument);

        setState(() {
          _document = updatedDocument;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded to OneDrive'), backgroundColor: Colors.green));
        }
      } else {
        throw Exception('Upload failed - no URL returned');
      }
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red));
      }
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _addPages() async {
    debugPrint('📄 Starting add pages for document: ${_document!.name}');
    setState(() {
      _isAddingPages = true;
    });

    try {
      // Use DocumentScannerService to add pages to existing document
      final updatedDocument = await DocumentScannerService.addPagesToDocument(_document!, maxNewPages: 5);

      if (updatedDocument != null) {
        debugPrint('✅ Successfully added pages to document');

        // Update the document in storage
        await ref.read(documentsProvider.notifier).updateDocument(updatedDocument);

        setState(() {
          _document = updatedDocument;
        });

        // Re-analyze the new PDF if it exists
        if (updatedDocument.pdfPath != null) {
          await _analyzePdfFile(updatedDocument.pdfPath!);
        }

        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Added pages successfully! Total pages: ${updatedDocument.imagePaths.length}'), backgroundColor: Colors.green, duration: const Duration(seconds: 2)));
        }
      } else {
        debugPrint('⚠️ No new pages were added');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No new pages were scanned'), backgroundColor: Colors.orange, duration: Duration(seconds: 2)));
        }
      }
    } catch (e) {
      debugPrint('❌ Error adding pages: $e');
      if (mounted) {
        String errorMessage = 'Error adding pages';
        if (e.toString().contains('permissions')) {
          errorMessage = 'Permission error - please grant camera and storage permissions';
        } else if (e.toString().contains('camera')) {
          errorMessage = 'Camera error - please check camera permissions';
        } else {
          errorMessage = 'Error adding pages: ${e.toString().split(':').last.trim()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAddingPages = false;
        });
      }
    }
  }

  Future<void> _previewPdf() async {
    if (_document!.pdfPath != null) {
      debugPrint('👁️ Opening PDF preview for: ${_document!.pdfPath}');
      context.push('/pdf-preview/${_document!.id}');
    } else {
      debugPrint('⚠️ No PDF available for preview');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please generate PDF first')));
    }
  }

  void _showImageViewer(int initialIndex) {
    debugPrint('🖼️ Opening image viewer at index: $initialIndex');
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => _ImageViewerPage(imagePaths: _document!.imagePaths, initialIndex: initialIndex)));
  }

  Future<void> _reorderImages(int oldIndex, int newIndex) async {
    debugPrint('🔄 Reordering images: $oldIndex -> $newIndex');
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
    debugPrint('✅ Images reordered successfully');
  }

  void _handleMenuAction(String action) {
    debugPrint('🔧 Handling menu action: $action');
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
                    debugPrint('✏️ Renaming document to: $newName');
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
    debugPrint('📤 Share document feature requested');
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
                  debugPrint('🗑️ Deleting document: ${_document!.id}');
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))],
    );
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
    debugPrint('🖼️ ImageViewer initialized at index: $_currentIndex');
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
        onPageChanged: (index) {
          debugPrint('🖼️ Image viewer page changed to: $index');
          setState(() => _currentIndex = index);
        },
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.file(
                File(widget.imagePaths[index]),
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  debugPrint('❌ Error loading image in viewer: $error');
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
