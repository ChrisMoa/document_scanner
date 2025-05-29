#!/usr/bin/env dart

import 'dart:io';

/// Simple setup script to create .env file from template
void main() async {
  print('🚀 Document Scanner App - Environment Setup');
  print('===========================================\n');

  final templateFile = File('template.env');
  final envFile = File('.env');

  // Check if template exists
  if (!templateFile.existsSync()) {
    print('❌ Error: template.env file not found!');
    print('   Make sure you\'re running this from the project root.');
    exit(1);
  }

  // Check if .env already exists
  if (envFile.existsSync()) {
    print('⚠️  .env file already exists.');
    stdout.write('   Do you want to overwrite it? (y/N): ');
    final response = stdin.readLineSync()?.toLowerCase() ?? 'n';

    if (response != 'y' && response != 'yes') {
      print('   Setup cancelled.');
      exit(0);
    }
  }

  try {
    // Copy template to .env
    final templateContent = await templateFile.readAsString();
    await envFile.writeAsString(templateContent);

    print('✅ Created .env file from template');
    print('\n📝 Next steps:');
    print('   1. Edit .env file and replace dummy values');
    print('   2. Get your Azure AD Client ID from:');
    print('      https://portal.azure.com → Azure Active Directory → App registrations');
    print('   3. Update ONEDRIVE_CLIENT_ID in .env file');
    print('   4. Run: flutter run');
    print('\n🔒 Security reminder:');
    print('   - Never commit the .env file to version control');
    print('   - Keep your Client ID confidential');
    print('   - The .env file is already in .gitignore');
  } catch (e) {
    print('❌ Error creating .env file: $e');
    exit(1);
  }
}
