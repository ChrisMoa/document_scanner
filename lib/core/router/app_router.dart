import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:document_scanner/features/home/presentation/pages/home_page.dart';
import 'package:document_scanner/features/camera/presentation/pages/camera_page.dart';
import 'package:document_scanner/features/document/presentation/pages/document_detail_page.dart';
import 'package:document_scanner/features/document/presentation/pages/pdf_preview_page.dart';
import 'package:document_scanner/features/settings/presentation/pages/settings_page.dart';
import 'package:document_scanner/features/cloud/presentation/pages/cloud_settings_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', name: 'home', builder: (context, state) => const HomePage()),
      GoRoute(path: '/camera', name: 'camera', builder: (context, state) => const CameraPage()),
      GoRoute(
        path: '/document/:id',
        name: 'document-detail',
        builder: (context, state) {
          final documentId = state.pathParameters['id']!;
          return DocumentDetailPage(documentId: documentId);
        },
      ),
      GoRoute(
        path: '/pdf-preview/:id',
        name: 'pdf-preview',
        builder: (context, state) {
          final documentId = state.pathParameters['id']!;
          return PdfPreviewPage(documentId: documentId);
        },
      ),
      GoRoute(path: '/settings', name: 'settings', builder: (context, state) => const SettingsPage()),
      GoRoute(path: '/cloud-settings', name: 'cloud-settings', builder: (context, state) => const CloudSettingsPage()),
    ],
    errorBuilder:
        (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Page not found: ${state.uri}'),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => context.go('/'), child: const Text('Go Home')),
              ],
            ),
          ),
        ),
  );
});
