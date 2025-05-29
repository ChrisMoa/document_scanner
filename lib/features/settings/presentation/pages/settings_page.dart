import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

    debugPrint('🔧 Building SettingsPage with theme: $themeMode, saveLocation: $saveLocation');

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
            leading: Icon(Icons.info_outline, color: theme.colorScheme.primary),
            title: const Text('Storage Status'),
            subtitle: const Text('Check current storage configuration'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showStorageStatus(context, ref),
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
                debugPrint('🔄 Auto sync toggle requested: $value');
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
                debugPrint('🔒 Encryption toggle requested: $value');
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
    debugPrint('🎨 Showing theme selection dialog');
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
                      debugPrint('🌞 Light theme selected');
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
                      debugPrint('🌙 Dark theme selected');
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
                      debugPrint('🔄 System theme selected');
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
    debugPrint('📁 Starting save location selection process...');

    try {
      // Check and request storage permissions first
      debugPrint('🔐 Checking storage permissions...');
      final hasPermission = await PermissionService.checkStoragePermissions();

      if (!hasPermission) {
        debugPrint('🔐 Requesting storage permissions...');
        final granted = await PermissionService.requestStoragePermissions();

        if (!granted) {
          debugPrint('❌ Storage permissions denied');
          if (context.mounted) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: const Text('Storage Permission Required'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(PermissionService.getStoragePermissionExplanation()),
                        const SizedBox(height: 12),
                        const Text(
                          'Note: Due to Android storage restrictions, files will be saved to app-specific storage which is accessible through the file manager.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
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

      // Show information about Android storage limitations
      final shouldContinue = await showDialog<bool>(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Select Folder Name'),
              content: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Due to Android storage restrictions, files will be saved to app-specific storage.'),
                  SizedBox(height: 8),
                  Text('You can choose a folder name for better organization. Files will be accessible through the Android file manager.'),
                  SizedBox(height: 8),
                  Text('Location: Android/data/com.example.document_scanner/files/[YourFolderName]'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Continue')),
              ],
            ),
      );

      if (shouldContinue != true) return;

      // Use the storage service method to select and configure directory
      final result = await StorageService.selectSaveDirectory();

      if (result != null) {
        debugPrint('✅ Directory selected and configured: $result');
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

  Future<void> _showStorageStatus(BuildContext context, WidgetRef ref) async {
    debugPrint('📊 Showing storage status dialog...');

    try {
      final status = await ref.read(saveLocationProvider.notifier).getStorageStatus();
      final permissionMessage = await PermissionService.getPermissionStatusMessage();

      if (context.mounted) {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Storage Status'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStatusRow('Location', status['displayLocation']),
                      const SizedBox(height: 8),
                      _buildStatusRow('Full Path', status['location']),
                      const SizedBox(height: 8),
                      _buildStatusRow('Can Write', status['canWrite'] ? 'Yes' : 'No'),
                      const SizedBox(height: 8),
                      _buildStatusRow('Status', status['message']),
                      const SizedBox(height: 8),
                      _buildStatusRow('Default', status['isDefault'] ? 'Yes' : 'No'),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      const Text('Permissions:', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(permissionMessage, style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 12),
                      const Text(
                        'Note: Due to Android storage restrictions, files are saved to app-specific storage which is accessible through your device\'s file manager.',
                        style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
              ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error getting storage status: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error getting storage status: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Widget _buildStatusRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [SizedBox(width: 80, child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold))), Expanded(child: Text(value, style: const TextStyle(fontFamily: 'monospace')))],
    );
  }

  Future<void> _resetSaveLocation(BuildContext context, WidgetRef ref) async {
    debugPrint('🔄 Resetting save location to default...');

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Save Location'),
            content: const Text('This will reset the save location to the default app storage. Continue?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Reset')),
            ],
          ),
    );

    if (confirm == true) {
      await ref.read(saveLocationProvider.notifier).resetToDefault();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save location reset to default'), backgroundColor: Colors.green));
      }
    }
  }

  void _showEncryptionKeysDialog(BuildContext context) {
    debugPrint('🔑 Showing encryption keys dialog');
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
    debugPrint('📄 Showing privacy policy');
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
    debugPrint('❓ Showing help dialog');
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Help & Support'),
            content: const SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('📱 Getting Started:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Tap the camera button to start scanning'),
                  Text('• Multiple pages can be scanned in one session'),
                  Text('• Documents are automatically enhanced'),
                  Text('• PDFs are created from your scanned images'),
                  SizedBox(height: 12),
                  Text('💾 File Storage:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Files are automatically saved to your chosen location'),
                  Text('• External app storage is accessible via file manager'),
                  Text('• Location: Android/data/[app]/files/[folder]/'),
                  SizedBox(height: 12),
                  Text('☁️ Cloud Features:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Enable cloud sync to backup documents'),
                  Text('• Connect to OneDrive in cloud settings'),
                  SizedBox(height: 12),
                  Text('🔒 Security:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text('• Encryption protects your sensitive documents'),
                  Text('• All processing happens locally on your device'),
                ],
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
          ),
    );
  }
}
