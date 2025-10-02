import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:document_scanner/core/services/nextcloud_service.dart';

class CloudSettingsPage extends ConsumerStatefulWidget {
  const CloudSettingsPage({super.key});

  @override
  ConsumerState<CloudSettingsPage> createState() => _CloudSettingsPageState();
}

class _CloudSettingsPageState extends ConsumerState<CloudSettingsPage> {
  final TextEditingController _serverUrlController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _appPasswordController = TextEditingController();
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    // Update UI when text changes
    _serverUrlController.addListener(() => setState(() {}));
    _usernameController.addListener(() => setState(() {}));
    _appPasswordController.addListener(() => setState(() {}));

    // Prefill with stored values if available
    final savedServer = NextcloudService.serverUrl;
    final savedUser = NextcloudService.username;
    if (savedServer != null && savedServer.isNotEmpty) {
      _serverUrlController.text = savedServer;
    }
    if (savedUser != null && savedUser.isNotEmpty) {
      _usernameController.text = savedUser;
    }
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _usernameController.dispose();
    _appPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Nextcloud Settings'), backgroundColor: theme.appBarTheme.backgroundColor, foregroundColor: theme.appBarTheme.foregroundColor),
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
                        Text('Nextcloud Integration', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      NextcloudService.isAuthenticated ? 'Connected to Nextcloud' : 'Not connected to Nextcloud',
                      style: theme.textTheme.bodyMedium?.copyWith(color: NextcloudService.isAuthenticated ? Colors.green : theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    if (NextcloudService.isAuthenticated) ...[
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: () => _signOut(), style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text('Sign Out')),
                    ],
                  ],
                ),
              ),
            ),

            if (!NextcloudService.isAuthenticated) ...[
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
                        'To enable Nextcloud integration:\n\n'
                        '• Enter your Nextcloud server URL (e.g., https://cloud.example.com)\n'
                        '• Enter your Nextcloud username\n'
                        '• Create an App Password in Nextcloud settings and paste it here\n'
                        '• Tap Connect',
                        style: TextStyle(height: 1.4),
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
                      Text('Connection', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(controller: _serverUrlController, decoration: const InputDecoration(labelText: 'Server URL', hintText: 'https://cloud.example.com', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextField(controller: _usernameController, decoration: const InputDecoration(labelText: 'Username', hintText: 'your-username', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      TextField(controller: _appPasswordController, obscureText: true, decoration: const InputDecoration(labelText: 'App Password', hintText: 'Nextcloud app password', border: OutlineInputBorder())),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _isConnecting || _serverUrlController.text.isEmpty || _usernameController.text.isEmpty || _appPasswordController.text.isEmpty ? null : () => _connect(),
                        child: _isConnecting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Connect'),
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
                    _buildFeatureItem(Icons.backup, 'Automatic Backup', 'Documents are automatically uploaded to Nextcloud', theme),
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

  Future<void> _connect() async {
    final serverUrl = _serverUrlController.text.trim();
    final username = _usernameController.text.trim();
    final appPassword = _appPasswordController.text.trim();

    if (serverUrl.isEmpty || username.isEmpty || appPassword.isEmpty) return;

    setState(() {
      _isConnecting = true;
    });

    try {
      final success = await NextcloudService.authenticate(serverUrl, username, appPassword);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully connected to Nextcloud!'), backgroundColor: Colors.green));
          setState(() {});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connection failed. Please check credentials.'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isConnecting = false;
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
            content: const Text('Are you sure you want to sign out of Nextcloud?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sign Out')),
            ],
          ),
    );

    if (confirm == true) {
      await NextcloudService.signOut();
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
      }
    }
  }
}
