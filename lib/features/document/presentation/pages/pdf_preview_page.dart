// lib/features/document/presentation/pages/pdf_preview_page.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
import 'package:document_scanner/core/models/document_model.dart';
import 'package:document_scanner/core/services/pdf_service.dart';

class PdfPreviewPage extends ConsumerStatefulWidget {
  final String documentId;

  const PdfPreviewPage({super.key, required this.documentId});

  @override
  ConsumerState<PdfPreviewPage> createState() => _PdfPreviewPageState();
}

class _PdfPreviewPageState extends ConsumerState<PdfPreviewPage> {
  DocumentModel? _document;
  Uint8List? _pdfData;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    debugPrint('PDF Preview initialized for document: ${widget.documentId}');
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final document = ref.read(documentsProvider.notifier).getDocument(widget.documentId);

      if (document == null) {
        setState(() {
          _error = 'Document not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _document = document;
      });

      await _loadPdfData();
    } catch (e) {
      debugPrint('Error loading document: $e');
      setState(() {
        _error = 'Failed to load document: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPdfData() async {
    if (_document == null) return;

    try {
      Uint8List? pdfData;

      // Try to load existing PDF first
      if (_document!.pdfPath != null) {
        final pdfFile = File(_document!.pdfPath!);
        if (await pdfFile.exists()) {
          pdfData = await pdfFile.readAsBytes();
          debugPrint('Loaded existing PDF from: ${_document!.pdfPath}');
        }
      }

      // Generate PDF if not exists or failed to load
      if (pdfData == null) {
        debugPrint('Generating new PDF from ${_document!.imagePaths.length} images');
        setState(() {
          _isGenerating = true;
        });

        pdfData = await PdfService.createPdfFromImages(_document!.imagePaths, _document!.name);
      }

      setState(() {
        _pdfData = pdfData;
        _isLoading = false;
        _isGenerating = false;
      });
    } catch (e) {
      debugPrint('Error loading/generating PDF: $e');
      setState(() {
        _error = 'Failed to load PDF: $e';
        _isLoading = false;
        _isGenerating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(_document?.name ?? 'PDF Preview'),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
        actions: [
          if (_pdfData != null) ...[
            IconButton(icon: const Icon(Icons.share), onPressed: () => _sharePdf(), tooltip: 'Share PDF'),
            IconButton(icon: const Icon(Icons.print), onPressed: () => _printPdf(), tooltip: 'Print PDF'),
            PopupMenuButton<String>(
              onSelected: _handleMenuAction,
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(value: 'save', child: ListTile(leading: Icon(Icons.save), title: Text('Save to Device'))),
                    const PopupMenuItem(value: 'regenerate', child: ListTile(leading: Icon(Icons.refresh), title: Text('Regenerate PDF'))),
                  ],
            ),
          ],
        ],
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isLoading) {
      return _buildLoadingState(theme);
    }

    if (_error != null) {
      return _buildErrorState(theme);
    }

    if (_pdfData == null) {
      return _buildEmptyState(theme);
    }

    return _buildPdfPreview(theme);
  }

  Widget _buildLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(_isGenerating ? 'Generating PDF...' : 'Loading PDF...', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          if (_isGenerating) ...[const SizedBox(height: 8), Text('This may take a few moments', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)))],
        ],
      ),
    );
  }

  Widget _buildErrorState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Error Loading PDF', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(onPressed: _loadDocument, icon: const Icon(Icons.refresh), label: const Text('Retry')),
                const SizedBox(width: 16),
                OutlinedButton.icon(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.arrow_back), label: const Text('Go Back')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf, size: 64, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('No PDF Available', style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
          const SizedBox(height: 8),
          Text('Generate a PDF first to preview it here', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(ThemeData theme) {
    return Column(
      children: [
        if (_document != null) _buildPdfInfo(theme),
        Expanded(
          child: PdfPreview(
            build: (format) => _pdfData!,
            allowPrinting: true,
            allowSharing: true,
            canChangePageFormat: false,
            canChangeOrientation: false,
            canDebug: false,
            maxPageWidth: 700,
            pdfFileName: '${_document?.name ?? 'document'}.pdf',
            previewPageMargin: const EdgeInsets.all(16),
            scrollViewDecoration: BoxDecoration(color: theme.colorScheme.surface),
            loadingWidget: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
            onError: (context, error) {
              debugPrint('PDF Preview error: $error');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error, size: 48, color: theme.colorScheme.error),
                    const SizedBox(height: 16),
                    Text('Failed to display PDF', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.error)),
                    const SizedBox(height: 8),
                    Text(error.toString(), style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)), textAlign: TextAlign.center),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPdfInfo(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: theme.cardColor, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_document!.name}.pdf', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${_document!.imagePaths.length} page${_document!.imagePaths.length != 1 ? 's' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          if (_pdfData != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Text('${(_pdfData!.length / 1024).round()} KB', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }

  Future<void> _sharePdf() async {
    if (_pdfData == null) return;

    try {
      await Printing.sharePdf(bytes: _pdfData!, filename: '${_document?.name ?? 'document'}.pdf');
      debugPrint('PDF shared successfully');
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to share PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _printPdf() async {
    if (_pdfData == null) return;

    try {
      await Printing.layoutPdf(onLayout: (format) => _pdfData!, name: _document?.name ?? 'Document');
      debugPrint('PDF print dialog opened');
    } catch (e) {
      debugPrint('Error printing PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to print PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'save':
        _savePdfToDevice();
        break;
      case 'regenerate':
        _regeneratePdf();
        break;
    }
  }

  Future<void> _savePdfToDevice() async {
    if (_pdfData == null || _document == null) return;

    try {
      // Use the existing PDF service to save
      final fileName = PdfService.generateFileName(_document!.name);
      // This would save to the configured save location
      // The actual implementation would depend on your file picker/saver

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF save feature coming soon'), backgroundColor: Colors.orange));

      debugPrint('PDF save requested: $fileName');
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save PDF: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _regeneratePdf() async {
    if (_document == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Regenerate PDF'),
            content: const Text('This will create a new PDF from the current images. Continue?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Regenerate')),
            ],
          ),
    );

    if (confirm == true) {
      setState(() {
        _pdfData = null;
        _isLoading = true;
        _isGenerating = true;
      });

      await _loadPdfData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF regenerated successfully'), backgroundColor: Colors.green));
      }
    }
  }
}
