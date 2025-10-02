import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:document_scanner/core/providers/theme_provider.dart';
import 'package:document_scanner/core/providers/storage_provider.dart';
import 'package:document_scanner/core/providers/document_settings_provider.dart';
import 'package:document_scanner/core/services/permission_service.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/services/auto_backup_service.dart';
import 'package:document_scanner/core/services/nextcloud_service.dart';
import 'package:document_scanner/core/services/encryption_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final themeMode = ref.watch(themeProvider);
    final saveLocation = ref.watch(saveLocationProvider);
    final documentSettings = ref.watch(documentSettingsProvider);

    debugPrint('🔧 Building SettingsPage with theme: $themeMode, saveLocation: $saveLocation, documentSettings: $documentSettings');

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(title: const Text('Settings'), backgroundColor: theme.appBarTheme.backgroundColor, foregroundColor: theme.appBarTheme.foregroundColor),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle('Document Processing', theme),
          _buildDocumentProcessingSettings(context, ref, documentSettings, theme),

          const SizedBox(height: 24),
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
            title: const Text('Nextcloud Integration'),
            subtitle: Text(NextcloudService.isAuthenticated ? 'Connected' : 'Configure cloud storage'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/cloud-settings'),
          ),
          const Divider(height: 1),
          // Auto Backup Toggle
          StatefulBuilder(
            builder: (context, setState) => ListTile(
              leading: Icon(Icons.sync, color: theme.colorScheme.primary),
              title: const Text('Auto Backup'),
              subtitle: Text(NextcloudService.isAuthenticated ? 'Automatically upload PDFs to Nextcloud' : 'Connect Nextcloud to enable auto backup'),
              trailing: Switch(
                value: NextcloudService.isAuthenticated ? AutoBackupService.isAutoBackupEnabled : false,
                onChanged: NextcloudService.isAuthenticated
                    ? (value) async {
                        debugPrint('🔄 Auto backup toggle requested: $value');
                        await AutoBackupService.setAutoBackupEnabled(value);
                        setState(() {});

                        if (value) {
                          final folderId = await AutoBackupService.createBackupFolder();
                          if (folderId != null) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Auto backup enabled! Created "Document Scanner Backup" folder in Nextcloud'), backgroundColor: Colors.green),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Auto backup enabled! Documents will be uploaded to Nextcloud root'), backgroundColor: Colors.green),
                              );
                            }
                          }
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auto backup disabled'), backgroundColor: Colors.orange));
                          }
                        }
                      }
                    : null,
              ),
            ),
          ),
          // Manual Sync Button
          if (NextcloudService.isAuthenticated) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.cloud_sync, color: theme.colorScheme.primary),
              title: const Text('Sync All Documents'),
              subtitle: const Text('Upload all PDFs to Nextcloud now'),
              trailing: const Icon(Icons.upload),
              onTap: () => _performManualSync(context),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecuritySettings(BuildContext context, ThemeData theme) {
    return Card(
      child: Column(
        children: [
          // Encryption Toggle
          StatefulBuilder(
            builder:
                (context, setState) => ListTile(
                  leading: Icon(Icons.security, color: theme.colorScheme.primary),
                  title: const Text('Document Encryption'),
                  subtitle: Text(EncryptionService.hasUserKey ? 'Encrypt documents before cloud upload' : 'Set up encryption password first'),
                  trailing: Switch(
                    value: EncryptionService.isEncryptionEnabled,
                    onChanged:
                        EncryptionService.hasUserKey
                            ? (value) async {
                              debugPrint('🔒 Encryption toggle requested: $value');
                              await EncryptionService.setEncryptionEnabled(value);
                              setState(() {}); // Update the toggle state

                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text('Encryption ${value ? 'enabled' : 'disabled'}'), backgroundColor: value ? Colors.green : Colors.orange));
                              }
                            }
                            : null,
                  ),
                ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.key, color: theme.colorScheme.primary),
            title: Text(EncryptionService.hasUserKey ? 'Change Encryption Password' : 'Set Up Encryption'),
            subtitle: Text(EncryptionService.hasUserKey ? 'Change your encryption password' : 'Create a password to encrypt your documents'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEncryptionSetupDialog(context),
          ),
          if (EncryptionService.hasUserKey) ...[
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Clear Encryption'),
              subtitle: const Text('Remove encryption and password'),
              onTap: () => _showClearEncryptionDialog(context),
            ),
          ],
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

  Widget _buildDocumentProcessingSettings(BuildContext context, WidgetRef ref, dynamic documentSettings, ThemeData theme) {
    debugPrint('🎛️ Building document processing settings - enableFiltering: ${documentSettings.enableFiltering}');

    return Card(
      child: Column(
        children: [
          // Main toggle with better visibility
          Container(
            decoration: BoxDecoration(
              color: documentSettings.enableFiltering ? theme.colorScheme.primaryContainer.withOpacity(0.3) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
            ),
            child: ListTile(
              leading: Icon(
                documentSettings.enableFiltering ? Icons.auto_fix_high : Icons.auto_fix_off,
                color: documentSettings.enableFiltering ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
              ),
              title: Text(
                'Document Enhancement',
                style: TextStyle(fontWeight: FontWeight.bold, color: documentSettings.enableFiltering ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
              ),
              subtitle: Text(
                documentSettings.enableFiltering ? 'Advanced text sharpening & processing enabled' : 'Only basic grayscale conversion (faster)',
                style: TextStyle(color: documentSettings.enableFiltering ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurfaceVariant),
              ),
              trailing: Switch(
                value: documentSettings.enableFiltering,
                onChanged: (value) {
                  debugPrint('🔄 Toggle filtering: $value');
                  ref.read(documentSettingsProvider.notifier).toggleFiltering(value);
                },
                activeColor: theme.colorScheme.primary,
              ),
            ),
          ),
          if (documentSettings.enableFiltering) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Advanced Text Enhancement Settings', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                    'These settings control the advanced 6-stage text sharpening pipeline for maximum readability.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.tune, color: theme.colorScheme.primary),
              title: const Text('Black/White Threshold'),
              subtitle: Text('Text clarity adjustment: ${(documentSettings.blackWhiteThreshold * 100).round()}%'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Slider(
                value: documentSettings.blackWhiteThreshold,
                min: 0.3,
                max: 0.9,
                divisions: 30,
                label: '${(documentSettings.blackWhiteThreshold * 100).round()}%',
                onChanged: (value) => ref.read(documentSettingsProvider.notifier).updateBlackWhiteThreshold(value),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.auto_fix_high, color: theme.colorScheme.primary),
              title: const Text('Sharpness Amount'),
              subtitle: Text('Edge enhancement strength: ${documentSettings.sharpnessAmount.toStringAsFixed(1)}'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Slider(
                value: documentSettings.sharpnessAmount,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                label: documentSettings.sharpnessAmount.toStringAsFixed(1),
                onChanged: (value) => ref.read(documentSettingsProvider.notifier).updateSharpnessAmount(value),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.blur_on, color: theme.colorScheme.primary),
              title: const Text('Sharpness Radius'),
              subtitle: Text('Sharpening area size: ${documentSettings.sharpnessRadius.toStringAsFixed(1)}'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Slider(
                value: documentSettings.sharpnessRadius,
                min: 0.5,
                max: 3.0,
                divisions: 25,
                label: documentSettings.sharpnessRadius.toStringAsFixed(1),
                onChanged: (value) => ref.read(documentSettingsProvider.notifier).updateSharpnessRadius(value),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.contrast, color: theme.colorScheme.primary),
              title: const Text('Contrast Level'),
              subtitle: Text('Text contrast enhancement: ${documentSettings.contrastLevel.toStringAsFixed(1)}'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Slider(
                value: documentSettings.contrastLevel,
                min: 0.8,
                max: 2.0,
                divisions: 24,
                label: documentSettings.contrastLevel.toStringAsFixed(1),
                onChanged: (value) => ref.read(documentSettingsProvider.notifier).updateContrastLevel(value),
              ),
            ),
            const Divider(height: 1),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.secondaryContainer.withOpacity(0.3),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSecondaryContainer),
                      const SizedBox(width: 8),
                      Text('Enhancement Pipeline Active', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSecondaryContainer)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'CLAHE → Unsharp Mask → Morphology → Gradient → Frequency → Text Optimization',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(Icons.speed, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Fast Mode: Only grayscale conversion (Enable enhancement for better text quality)',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: Icon(Icons.refresh, color: theme.colorScheme.primary),
            title: const Text('Reset to Defaults'),
            subtitle: const Text('Restore original processing settings'),
            onTap: () => _showResetDialog(context, ref),
          ),
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

  void _showEncryptionSetupDialog(BuildContext context) {
    debugPrint('🔒 Showing encryption setup dialog');
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(EncryptionService.hasUserKey ? 'Change Encryption Password' : 'Set Up Encryption'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(EncryptionService.hasUserKey ? 'Enter a new password to change your encryption:' : 'Enter a password to encrypt your documents:'),
                const SizedBox(height: 16),
                TextField(controller: passwordController, obscureText: true, decoration: const InputDecoration(hintText: 'Enter password (min 8 characters)', border: OutlineInputBorder())),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  final password = passwordController.text;
                  if (password.length < 8) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 8 characters'), backgroundColor: Colors.red));
                    return;
                  }

                  Navigator.of(context).pop();

                  final success = await EncryptionService.setupEncryption(password);
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(success ? 'Encryption set up successfully' : 'Failed to set up encryption'), backgroundColor: success ? Colors.green : Colors.red));
                  }
                },
                child: const Text('Set Up'),
              ),
            ],
          ),
    );
  }

  void _showClearEncryptionDialog(BuildContext context) {
    debugPrint('🔑 Showing clear encryption dialog');
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Encryption'),
            content: const Text('Are you sure you want to remove encryption and password?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await EncryptionService.clearEncryption();
                },
                child: const Text('Clear'),
              ),
            ],
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

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    debugPrint('🔄 Showing document settings reset dialog');
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Reset Document Settings'),
            content: const Text('This will reset all document processing settings to their default values. Continue?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await ref.read(documentSettingsProvider.notifier).resetToDefaults();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document settings reset to defaults'), backgroundColor: Colors.green));
                  }
                },
                child: const Text('Reset'),
              ),
            ],
          ),
    );
  }

  Future<void> _performManualSync(BuildContext context) async {
    debugPrint('🔄 Manual sync requested by user');

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Synchronizing documents...'),
                Text('Please wait while we upload your PDFs to Nextcloud', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
    );

    try {
      final result = await AutoBackupService.synchronizeAllDocuments();

      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        final message = result['message'] as String;
        final success = result['success'] as bool;
        final uploaded = result['uploaded'] as int;
        final failed = result['failed'] as int;
        final skipped = result['skipped'] as int;

        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(success ? 'Sync Complete' : 'Sync Finished with Issues'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message),
                    if (uploaded > 0) ...[const SizedBox(height: 8), Text('✅ Uploaded: $uploaded documents')],
                    if (skipped > 0) ...[const SizedBox(height: 4), Text('⏭️ Skipped: $skipped documents (already synced or no PDF)')],
                    if (failed > 0) ...[const SizedBox(height: 4), Text('❌ Failed: $failed documents', style: const TextStyle(color: Colors.red))],
                  ],
                ),
                actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
              ),
        );
      }
    } catch (e) {
      debugPrint('❌ Manual sync error: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}
