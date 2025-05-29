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
  void initState() {
    super.initState();
    // Add listeners to update UI when text changes
    _clientIdController.addListener(() => setState(() {}));
    _authCodeController.addListener(() => setState(() {}));
  }

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
      body: SingleChildScrollView(
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
                      if (OneDriveService.hasDefaultClientId) ...[
                        const Text(
                          'Quick Setup (Recommended):\n'
                          '• App is pre-configured for easy access\n'
                          '• You\'ll log in with your personal Microsoft account\n'
                          '• Access your personal OneDrive storage\n\n'
                          'Advanced Setup:\n'
                          '• Register your own app in Azure AD\n'
                          '• Enter your custom Client ID below',
                        ),
                      ] else ...[
                        const Text(
                          'To enable OneDrive integration:\n\n'
                          'Option 1 - Manual Setup:\n'
                          '• Register app in Azure AD\n'
                          '• Enter your Client ID below\n'
                          '• Follow authentication flow\n\n'
                          'Option 2 - Ask Developer:\n'
                          '• Request pre-configured setup\n'
                          '• Easier for end users',
                          style: TextStyle(height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              if (OneDriveService.hasDefaultClientId) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Quick Setup', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        const Text('✨ Easy OneDrive connection - just authenticate with your Microsoft account!'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => _startQuickAuthentication(),
                          style: ElevatedButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                          child: const Text('Quick Connect to OneDrive'),
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 8),
                        Text('Or use custom settings below:', style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(OneDriveService.hasDefaultClientId ? 'Custom Authentication' : 'Authentication', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
            title: const Text('Microsoft Account Login'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('🔵 You will now log in with your personal Microsoft account (Outlook, Hotmail, Xbox, etc.)'),
                const SizedBox(height: 12),
                const Text('1. Open this URL in your browser:'),
                const SizedBox(height: 8),
                SelectableText(authUrl, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                const Text('2. Log in with your Microsoft account'),
                const Text('3. Allow access to your OneDrive'),
                const Text('4. Copy the authorization code from the redirect URL'),
                const Text('5. Paste it below and complete authentication'),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
    );
  }

  void _startQuickAuthentication() {
    if (!OneDriveService.hasDefaultClientId) return;

    final authUrl = OneDriveService.getDefaultAuthUrl();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('🚀 Quick Microsoft Login'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('✨ Ready to connect your personal OneDrive!'),
                const SizedBox(height: 12),
                const Text('🔵 You\'ll log in with your Microsoft account (Outlook, Hotmail, Xbox, etc.)'),
                const SizedBox(height: 12),
                const Text('1. Open this URL in your browser:'),
                const SizedBox(height: 8),
                SelectableText(authUrl, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 12),
                const Text('2. Log in with your Microsoft account'),
                const Text('3. Allow access to your OneDrive'),
                const Text('4. Copy the authorization code from the redirect URL'),
                const Text('5. Paste it in the "Authorization Code" field below'),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
    );
  }

  Future<void> _completeAuthentication() async {
    final clientId = _clientIdController.text.trim();
    final authCode = _authCodeController.text.trim();

    // Use default client ID if custom one is not provided and default is available
    final finalClientId = clientId.isNotEmpty ? clientId : (OneDriveService.hasDefaultClientId ? OneDriveService.defaultClientId : '');

    if (finalClientId.isEmpty || authCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please provide authorization code'), backgroundColor: Colors.red));
      return;
    }

    setState(() {
      _isAuthenticating = true;
    });

    try {
      final success = await OneDriveService.authenticate(finalClientId, authCode);

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
