import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:document_scanner/core/services/storage_service.dart';
import 'package:document_scanner/core/services/permission_service.dart';
import 'package:document_scanner/core/services/onedrive_service.dart';
import 'package:document_scanner/core/providers/theme_provider.dart';
import 'package:document_scanner/core/router/app_router.dart';
import 'package:document_scanner/core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('🚀 Starting Document Scanner App initialization...');

  debugPrint('⚙️ Loading environment variables...');
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded successfully');
  } catch (e) {
    debugPrint('⚠️ Warning: Could not load .env file: $e');
    debugPrint('📝 App will work without .env file, but some features may be limited');
  }

  debugPrint('📦 Initializing Hive...');
  try {
    await Hive.initFlutter();
    debugPrint('✅ Hive initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Hive: $e');
    rethrow;
  }

  debugPrint('💾 Initializing Storage Service...');
  try {
    await StorageService.initialize();
    debugPrint('✅ Storage Service initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Storage Service: $e');
    rethrow;
  }

  debugPrint('☁️ Initializing OneDrive Service...');
  try {
    await OneDriveService.initialize();
    debugPrint('✅ OneDrive Service initialized successfully');
    if (OneDriveService.isAuthenticated) {
      debugPrint('🔐 OneDrive authentication restored from saved tokens');
    } else {
      debugPrint('🔑 No saved OneDrive authentication found');
    }
  } catch (e) {
    debugPrint('❌ Error initializing OneDrive Service: $e');
    // Don't rethrow - OneDrive is optional
  }

  debugPrint('🔐 Requesting storage permissions...');
  try {
    final permissionsGranted = await PermissionService.requestStoragePermissions();
    debugPrint('📋 Storage permissions granted: $permissionsGranted');
    if (!permissionsGranted) {
      debugPrint('⚠️ Some storage permissions were denied - app will use limited storage');
    }
  } catch (e) {
    debugPrint('❌ Error requesting storage permissions: $e');
  }

  debugPrint('🎨 Starting Document Scanner App...');
  FlutterError.onError = (FlutterErrorDetails details) {
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('📍 Error location: ${details.stack}');
  };

  runApp(const ProviderScope(child: DocumentScannerApp()));
}

class DocumentScannerApp extends ConsumerWidget {
  const DocumentScannerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    debugPrint('🏗️ Building DocumentScannerApp...');

    final themeMode = ref.watch(themeProvider);
    debugPrint('🎨 Current theme mode: $themeMode');

    final router = ref.watch(appRouterProvider);
    debugPrint('🛣️ Router configuration loaded');

    debugPrint('📱 MaterialApp.router being created with theme: ${themeMode.name}');
    return MaterialApp.router(
      title: 'Document Scanner',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        debugPrint('🔨 Building app with ${themeMode.name} theme');
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
