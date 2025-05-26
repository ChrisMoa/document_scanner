import 'package:flutter/material.dart';
import 'package:document_scanner/core/models/document_model.dart';

class DocumentActions extends StatelessWidget {
  final DocumentModel document;
  final VoidCallback onGeneratePdf;
  final VoidCallback onUploadToCloud;
  final VoidCallback onPreviewPdf;
  final bool isGeneratingPdf;
  final bool isUploading;

  const DocumentActions({
    super.key,
    required this.document,
    required this.onGeneratePdf,
    required this.onUploadToCloud,
    required this.onPreviewPdf,
    required this.isGeneratingPdf,
    required this.isUploading,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.picture_as_pdf,
                label: isGeneratingPdf ? 'Generating...' : 'Generate PDF',
                onPressed: isGeneratingPdf ? null : onGeneratePdf,
                isLoading: isGeneratingPdf,
                color: Colors.red,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _ActionButton(icon: Icons.visibility, label: 'Preview PDF', onPressed: document.pdfPath != null ? onPreviewPdf : null, color: Colors.blue, theme: theme)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: document.isUploaded ? Icons.cloud_done : Icons.cloud_upload,
                label:
                    isUploading
                        ? 'Uploading...'
                        : document.isUploaded
                        ? 'Uploaded'
                        : 'Upload to Cloud',
                onPressed: isUploading || document.isUploaded ? null : onUploadToCloud,
                isLoading: isUploading,
                color: document.isUploaded ? Colors.green : Colors.orange,
                theme: theme,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _ActionButton(icon: Icons.share, label: 'Share', onPressed: () => _showShareOptions(context, theme), color: Colors.purple, theme: theme)),
          ],
        ),
        if (document.isEncrypted || document.isUploaded) ...[const SizedBox(height: 12), _buildStatusRow(theme)],
      ],
    );
  }

  Widget _buildStatusRow(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        if (document.isEncrypted) _StatusChip(icon: Icons.lock, label: 'Encrypted', color: Colors.orange, theme: theme),
        if (document.isUploaded) _StatusChip(icon: Icons.cloud_done, label: 'Cloud Synced', color: Colors.green, theme: theme),
        if (document.pdfPath != null) _StatusChip(icon: Icons.picture_as_pdf, label: 'PDF Ready', color: Colors.red, theme: theme),
      ],
    );
  }

  void _showShareOptions(BuildContext context, ThemeData theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withOpacity(0.3), borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                Text('Share Document', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _ShareOption(
                  icon: Icons.picture_as_pdf,
                  title: 'Share as PDF',
                  subtitle: document.pdfPath != null ? 'Share the generated PDF file' : 'Generate PDF first',
                  enabled: document.pdfPath != null,
                  onTap: () {
                    Navigator.of(context).pop();
                    _sharePdf(context);
                  },
                  theme: theme,
                ),
                _ShareOption(
                  icon: Icons.photo_library,
                  title: 'Share Images',
                  subtitle: 'Share individual scanned images',
                  enabled: document.imagePaths.isNotEmpty,
                  onTap: () {
                    Navigator.of(context).pop();
                    _shareImages(context);
                  },
                  theme: theme,
                ),
                _ShareOption(
                  icon: Icons.link,
                  title: 'Share Cloud Link',
                  subtitle: document.isUploaded ? 'Share OneDrive link' : 'Upload to cloud first',
                  enabled: document.isUploaded,
                  onTap: () {
                    Navigator.of(context).pop();
                    _shareCloudLink(context);
                  },
                  theme: theme,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _sharePdf(BuildContext context) {
    // TODO: Implement PDF sharing
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF sharing feature coming soon')));
  }

  void _shareImages(BuildContext context) {
    // TODO: Implement image sharing
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Image sharing feature coming soon')));
  }

  void _shareCloudLink(BuildContext context) {
    if (document.cloudUrl != null) {
      // TODO: Implement cloud link sharing
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cloud link: ${document.cloudUrl}')));
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final Color color;
  final ThemeData theme;

  const _ActionButton({required this.icon, required this.label, required this.onPressed, this.isLoading = false, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: onPressed != null ? color : theme.disabledColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: onPressed != null ? 2 : 0,
      ),
      icon:
          isLoading
              ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(onPressed != null ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5))),
              )
              : Icon(icon, size: 18, color: onPressed != null ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5)),
      label: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: onPressed != null ? Colors.white : theme.colorScheme.onSurface.withOpacity(0.5)),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final ThemeData theme;

  const _StatusChip({required this.icon, required this.label, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: color.withOpacity(0.3), width: 1)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color))],
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;
  final ThemeData theme;

  const _ShareOption({required this.icon, required this.title, required this.subtitle, required this.enabled, required this.onTap, required this.theme});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: enabled ? theme.colorScheme.surface : theme.colorScheme.surface.withOpacity(0.5)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: enabled ? theme.colorScheme.primary.withOpacity(0.1) : theme.disabledColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: enabled ? theme.colorScheme.primary : theme.disabledColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: enabled ? theme.colorScheme.onSurface : theme.disabledColor)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: enabled ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.disabledColor.withOpacity(0.7))),
                ],
              ),
            ),
            if (enabled) Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}
