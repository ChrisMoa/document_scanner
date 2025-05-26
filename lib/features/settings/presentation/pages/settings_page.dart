import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:document_scanner/core/providers/theme_provider.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
import 'package:document_scanner/core/services/permission_service.dart';
import 'package:document_scanner/core/services/storage_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final saveLocation = ref.watch(saveLocationProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: theme.appBarTheme.backgroundColor, foregroundColor: theme.appBarTheme.foregroundColor),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Appearance', theme),
          _buildThemeSettings(context, ref, themeMode, theme),

          const SizedBox(height: 24),
          _buildSectionTitle('Storage', theme),
          _buildStorageSettings(context, ref, saveLocation, theme),

          const SizedBox(height: 24),
          _buildSectionTitle('Cloud & Sync', theme),
          _buildCloudSettings(context, theme),

          const SizedBox(height: 24),
          _buildSectionTitle('Security', theme),
          _buildSecuritySettings(context, theme),

          const SizedBox(height: 24),
          _buildSectionTitle('About', theme),
          _buildAboutSettings(context, theme),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(title, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)));
  }

  Widget _buildThemeSettings(BuildContext context, WidgetRef ref, ThemeMode themeMode, ThemeData theme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.palette, color: theme.colorScheme.primary),
            title: const Text('Theme'),
            subtitle: Text(_getThemeModeText(themeMode)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, ref, themeMode),
          ),
        ],
      ),
    );
  }

  Widget _buildStorageSettings(BuildContext context, WidgetRef ref, String? saveLocation, ThemeData theme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.folder, color: theme.colorScheme.primary),
            title: const Text('Save Location'),
            subtitle: Text(saveLocation ?? 'Loading...'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _selectSaveLocation(context, ref),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.restore, color: theme.colorScheme.primary),
            title: const Text('Reset to Default'),
            subtitle: const Text('Reset save location to default'),
            onTap: () => _resetSaveLocation(context, ref),
          ),
        ],
      ),
    );
  }

  Widget _buildCloudSettings(BuildContext context, ThemeData theme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.cloud, color: theme.colorScheme.primary),
            title: const Text('OneDrive Integration'),
            subtitle: const Text('Configure cloud storage'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/cloud-settings'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.sync, color: theme.colorScheme.primary),
            title: const Text('Auto Sync'),
            subtitle: const Text('Automatically upload to cloud'),
            trailing: Switch(
              value: false, // TODO: Implement auto sync setting
              onChanged: (value) {
                // TODO: Implement auto sync toggle
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecuritySettings(BuildContext context, ThemeData theme) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: Icon(Icons.security, color: theme.colorScheme.primary),
            title: const Text('Encryption'),
            subtitle: const Text('Enable document encryption'),
            trailing: Switch(
              value: true, // TODO: Implement encryption setting
              onChanged: (value) {
                // TODO: Implement encryption toggle
              },
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.key, color: theme.colorScheme.primary),
            title: const Text('Encryption Keys'),
            subtitle: const Text('Manage encryption keys'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEncryptionKeysDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAboutSettings(BuildContext context, ThemeData theme) {
    return Card(
      child: Column(
        children: [
          ListTile(leading: Icon(Icons.info, color: theme.colorScheme.primary), title: const Text('App Version'), subtitle: const Text('1.0.0')),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.description, color: theme.colorScheme.primary),
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.open_in_new),
            onTap: () => _showPrivacyPolicy(context),
          ),
          const Divider(height: 1),
          ListTile(leading: Icon(Icons.help, color: theme.colorScheme.primary), title: const Text('Help & Support'), trailing: const Icon(Icons.open_in_new), onTap: () => _showHelp(context)),
        ],
      ),
    );
  }

  String _getThemeModeText(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System Default';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Choose Theme'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('Light'),
                  value: ThemeMode.light,
                  groupValue: currentMode,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeProvider.notifier).setTheme(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark'),
                  value: ThemeMode.dark,
                  groupValue: currentMode,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeProvider.notifier).setTheme(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  value: ThemeMode.system,
                  groupValue: currentMode,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(themeProvider.notifier).setTheme(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _selectSaveLocation(BuildContext context, WidgetRef ref) async {
    try {
      // Check and request storage permissions first
      debugPrint('🔐 Checking storage permissions before folder selection...');
      final hasPermission = await PermissionService.checkStoragePermissions();

      if (!hasPermission) {
        debugPrint('🔐 Requesting storage permissions...');
        final granted = await PermissionService.requestStoragePermissions();

        if (!granted) {
          if (context.mounted) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Storage Permission Required'),
                    content: const Text('To save files to a custom location, please grant storage permissions in the app settings.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          await PermissionService.openSettings();
                        },
                        child: const Text('Open Settings'),
                      ),
                    ],
                  ),
            );
          }
          return;
        }
      }

      debugPrint('✅ Storage permissions granted, opening folder picker...');

      // Use our new storage service method that handles directory selection and persistent access
      final result = await StorageService.selectSaveDirectory();

      if (result != null) {
        debugPrint('📁 Selected and configured save location: $result');
        await ref.read(saveLocationProvider.notifier).setSaveLocation(result);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Save location updated to: ${result.split('/').last}'), backgroundColor: Colors.green, duration: const Duration(seconds: 3)));
        }
      } else {
        debugPrint('❌ No folder selected or permission denied');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No folder selected'), duration: Duration(seconds: 2)));
        }
      }
    } catch (e) {
      debugPrint('❌ Error selecting save location: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error selecting location: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 3)));
      }
    }
  }

  Future<void> _resetSaveLocation(BuildContext context, WidgetRef ref) async {
    await ref.read(saveLocationProvider.notifier).resetToDefault();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save location reset to default')));
    }
  }

  void _showEncryptionKeysDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Encryption Keys'),
            content: const Text('Encryption keys are managed automatically and stored securely on your device.'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
    );
  }

  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Privacy Policy'),
            content: const SingleChildScrollView(
              child: Text(
                'This app processes documents locally on your device. '
                'No data is shared unless you explicitly choose to upload to cloud storage. '
                'Encryption keys are stored securely on your device.',
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
    );
  }

  void _showHelp(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Help & Support'),
            content: const SingleChildScrollView(
              child: Text(
                '• Tap the camera button to start scanning\n'
                '• Multiple pages can be scanned in one session\n'
                '• Documents are automatically enhanced\n'
                '• PDFs are created from your scanned images\n'
                '• Enable cloud sync to backup documents\n'
                '• Encryption protects your sensitive documents',
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
    );
  }
}
