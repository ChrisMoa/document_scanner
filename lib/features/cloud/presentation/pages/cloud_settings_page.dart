import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:document_scanner/core/services/onedrive_service.dart';

class CloudSettingsPage extends ConsumerStatefulWidget {
  const CloudSettingsPage({super.key});

  @override
  ConsumerState<CloudSettingsPage> createState() => _CloudSettingsPageState();
}

class _CloudSettingsPageState extends ConsumerState<CloudSettingsPage> {
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _authCodeController = TextEditingController();
  bool _isAuthenticating = false;

  @override
  void dispose() {
    _clientIdController.dispose();
    _authCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('OneDrive Settings'), backgroundColor: theme.appBarTheme.backgroundColor, foregroundColor: theme.appBarTheme.foregroundColor),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cloud, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('OneDrive Integration', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      OneDriveService.isAuthenticated ? 'Connected to OneDrive' : 'Not connected to OneDrive',
                      style: theme.textTheme.bodyMedium?.copyWith(color: OneDriveService.isAuthenticated ? Colors.green : theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    if (OneDriveService.isAuthenticated) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () => _signOut(), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Sign Out')),
                    ],
                  ],
                ),
              ),
            ),

            if (!OneDriveService.isAuthenticated) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Setup Instructions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      const Text(
                        '1. Register your app in Azure AD\n'
                        '2. Get your Client ID\n'
                        '3. Enter Client ID below\n'
                        '4. Follow the authentication flow',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Authentication', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(controller: _clientIdController, decoration: const InputDecoration(labelText: 'Client ID', hintText: 'Enter your Azure AD Client ID', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _clientIdController.text.isNotEmpty ? () => _startAuthentication() : null, child: const Text('Get Authorization Code')),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _authCodeController,
                        decoration: const InputDecoration(labelText: 'Authorization Code', hintText: 'Paste the code from browser', border: OutlineInputBorder()),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isAuthenticating || _authCodeController.text.isEmpty ? null : () => _completeAuthentication(),
                        child: _isAuthenticating ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Complete Authentication'),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cloud Storage Features', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildFeatureItem(Icons.backup, 'Automatic Backup', 'Documents are automatically uploaded to OneDrive', theme),
                    _buildFeatureItem(Icons.sync, 'Cross-Device Sync', 'Access your documents from any device', theme),
                    _buildFeatureItem(Icons.security, 'Encrypted Storage', 'Documents can be encrypted before upload', theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                Text(description, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startAuthentication() {
    final clientId = _clientIdController.text.trim();
    if (clientId.isEmpty) return;

    final authUrl = OneDriveService.getAuthUrl(clientId);

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Authorization Required'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Please open this URL in your browser:'),
                const SizedBox(height: 8),
                SelectableText(authUrl, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                const Text('After authorization, copy the code parameter from the redirect URL and paste it in the Authorization Code field.'),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
    );
  }

  Future<void> _completeAuthentication() async {
    final clientId = _clientIdController.text.trim();
    final authCode = _authCodeController.text.trim();

    if (clientId.isEmpty || authCode.isEmpty) return;

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final success = await OneDriveService.authenticate(clientId, authCode);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully connected to OneDrive!'), backgroundColor: Colors.green));
          setState(() {});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Authentication failed. Please try again.'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAuthenticating = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Sign Out'),
            content: const Text('Are you sure you want to sign out of OneDrive?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign Out')),
            ],
          ),
    );

    if (confirm == true) {
      await OneDriveService.signOut();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
      }
    }
  }
}
