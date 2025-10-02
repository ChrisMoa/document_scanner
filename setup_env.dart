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
    print('   1. Edit .env file and fill:');
    print('      NEXTCLOUD_SERVER_URL, NEXTCLOUD_USERNAME, NEXTCLOUD_APP_PASSWORD');
    print('   2. Create an App Password in your Nextcloud settings (Security)');
    print('   3. Put the values into the .env file');
    print('   4. Run: flutter run');
    print('\n🔒 Security reminder:');
    print('   - Never commit the .env file to version control');
    print('   - Keep your app password confidential');
    print('   - The .env file is already in .gitignore');
  } catch (e) {
    print('❌ Error creating .env file: $e');
    exit(1);
  }
}
