# Document Scanner — Technology Stack & Architecture

> **Purpose:** Quick reference for understanding the project structure, patterns, and technologies.

---

## Project Overview

| Property | Value |
|----------|-------|
| **App Name** | Document Scanner (package: `document_scanner`) |
| **Platform Support** | Android, Linux (iOS, Web configured) |
| **Dart SDK** | ^3.7.2 |
| **Flutter Version (CI)** | 3.41.2 stable |
| **Primary Language** | Dart |
| **License** | MIT |

### What It Does

A document scanner application for mobile and desktop:
- Scan documents using camera with auto-detection
- Manual corner adjustment for perspective correction
- Multi-page PDF generation
- Nextcloud/WebDAV cloud sync
- AES-256 document encryption
- Light/dark theme support

---

## Core Dependencies

### State Management & Navigation
| Package | Version | Usage |
|---------|---------|-------|
| `flutter_riverpod` | ^2.4.9 | Riverpod state management |
| `riverpod_annotation` | ^2.3.3 | Riverpod code generation annotations |
| `go_router` | ^13.2.0 | Declarative routing |

### Document Scanning & Image Processing
| Package | Version | Usage |
|---------|---------|-------|
| `cunning_document_scanner` | ^1.2.3 | Native document scanning |
| `image_picker` | ^1.0.4 | Gallery image selection |
| `image` | ^4.1.3 | Image manipulation |
| `camera` | ^0.11.1 | Camera access |

### PDF Generation
| Package | Version | Usage |
|---------|---------|-------|
| `pdf` | ^3.10.6 | PDF document creation |
| `printing` | ^5.11.1 | Print/share PDFs |

### Storage & Persistence
| Package | Version | Usage |
|---------|---------|-------|
| `hive` | ^2.2.3 | NoSQL key-value database |
| `hive_flutter` | ^1.1.0 | Hive Flutter integration |
| `shared_preferences` | ^2.2.2 | Simple key-value storage |
| `path_provider` | ^2.1.2 | App directory paths |

### Cloud & Network
| Package | Version | Usage |
|---------|---------|-------|
| `dio` | ^5.4.0 | HTTP client (WebDAV/Nextcloud) |
| `http` | ^1.1.2 | HTTP utilities |
| `xml` | ^6.5.0 | XML parsing (WebDAV responses) |

### Encryption
| Package | Version | Usage |
|---------|---------|-------|
| `crypto` | ^3.0.3 | Hash functions |
| `encrypt` | ^5.0.3 | AES encryption/decryption |

### Utilities
| Package | Version | Usage |
|---------|---------|-------|
| `uuid` | ^4.2.1 | UUID generation for document IDs |
| `path` | ^1.8.3 | Path manipulation |
| `device_info_plus` | ^10.1.0 | Device information |
| `permission_handler` | ^11.4.0 | Runtime permissions |
| `file_picker` | ^10.1.9 | File selection dialogs |
| `flutter_slidable` | ^4.0.0 | Swipeable list items |

### Dev Dependencies
| Package | Version | Usage |
|---------|---------|-------|
| `flutter_test` | sdk | Test framework |
| `flutter_lints` | ^5.0.0 | Lint rules |
| `riverpod_generator` | ^2.3.9 | Riverpod code generation |
| `build_runner` | ^2.4.7 | Code generation runner |
| `hive_generator` | ^2.0.1 | Hive type adapter generation |
| `json_annotation` | ^4.8.1 | JSON serialization metadata |
| `json_serializable` | ^6.7.1 | JSON code generation |

---

## Architecture

### Directory Structure

```
lib/
├── main.dart                          # App entry point, service initialization
├── core/                              # Cross-cutting concerns
│   ├── models/
│   │   ├── document_model.dart       # Document entity (Hive + JSON)
│   │   ├── document_model.g.dart     # Generated Hive adapter
│   │   ├── scan_session_model.dart   # Scan session entity
│   │   ├── scan_session_model.g.dart # Generated Hive adapter
│   │   └── settings_model.dart       # App settings
│   ├── providers/
│   │   ├── theme_provider.dart       # Theme mode state
│   │   ├── storage_provider.dart     # Document storage state
│   │   └── document_settings_provider.dart # Settings management
│   ├── router/
│   │   └── app_router.dart           # GoRouter configuration (10 routes)
│   ├── services/
│   │   ├── storage_service.dart      # Hive database operations
│   │   ├── document_scanner_service.dart # Scanner integration
│   │   ├── opencv_service.dart       # Image processing
│   │   ├── opencv_document_service.dart # Document-specific CV
│   │   ├── pdf_service.dart          # PDF generation
│   │   ├── nextcloud_service.dart    # Nextcloud WebDAV sync
│   │   ├── download_service.dart     # Cloud download
│   │   ├── auto_backup_service.dart  # Automatic backup
│   │   ├── encryption_service.dart   # AES encryption
│   │   ├── permission_service.dart   # Permission handling
│   │   ├── camera_service.dart       # Camera management
│   │   └── onedrive_service.dart     # OneDrive (legacy)
│   ├── theme/
│   │   └── app_theme.dart           # Material 3 light/dark themes
│   └── widgets/                      # Shared UI kit (planned)
│
└── features/                          # Feature modules
    ├── home/
    │   └── presentation/
    │       ├── pages/                # HomePage
    │       └── widgets/              # DocumentCard, EmptyState, SearchBar
    ├── camera/
    │   └── presentation/
    │       ├── pages/                # CameraPage, EnhancedCameraPage, DocumentCropPage, ScannerTestPage
    │       └── widgets/              # CameraControls, CornerAdjuster, ImagePreview, DetectionOverlay
    ├── document/
    │   └── presentation/
    │       ├── pages/                # DocumentDetailPage, PdfPreviewPage
    │       └── widgets/              # DocumentActions, ImageGridView
    ├── settings/
    │   └── presentation/
    │       └── pages/                # SettingsPage
    └── cloud/
        └── presentation/
            └── pages/                # CloudSettingsPage
```

### Feature Module Structure

Each feature follows a presentation-focused pattern:

```
feature/
└── presentation/
    ├── pages/         # Full-screen widgets
    └── widgets/       # Reusable UI components
```

Business logic lives in `core/services/` with state managed via `core/providers/`.

---

## Key Patterns & Conventions

### State Management: Riverpod

```dart
// Provider definition
final themeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>(...);

// Consuming in widget
class MyWidget extends ConsumerWidget {
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    // ...
  }
}
```

### Navigation: GoRouter

```dart
// Defined in core/router/app_router.dart
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomePage()),
      GoRoute(path: '/document/:id', builder: (_, state) {
        return DocumentDetailPage(documentId: state.pathParameters['id']!);
      }),
      // ...
    ],
  );
});
```

### Routes
| Path | Page |
|------|------|
| `/` | HomePage |
| `/camera` | CameraPage |
| `/enhanced-camera` | EnhancedCameraPage |
| `/scanner-test` | ScannerTestPage |
| `/document-crop` | DocumentCropPage |
| `/document/:id` | DocumentDetailPage |
| `/pdf-preview/:id` | PdfPreviewPage |
| `/settings` | SettingsPage |
| `/cloud-settings` | CloudSettingsPage |

---

## Key Data Models

### DocumentModel (Hive)
- `String id` — UUID
- `String name` — Document title (underscores, no spaces)
- `List<String> imagePaths` — Scanned page images
- `String? pdfPath` — Generated PDF path
- `DateTime createdAt`, `updatedAt`
- `bool isEncrypted`

### ScanSessionModel (Hive)
- `String id` — UUID
- `String documentId` — FK to document
- `List<String> capturedImages` — Raw captures
- `DateTime sessionDate`

### SettingsModel
- Theme mode, default scan settings
- Nextcloud credentials (server URL, username, password)
- Encryption preferences

---

## Database: Hive

Hive boxes for local persistence:
- Documents box — stores `DocumentModel` entries
- Settings box — stores app preferences
- Sessions box — stores scan session data

Initialization in `StorageService.initialize()` with custom app data directory.

---

## Sync Architecture (Nextcloud/WebDAV)

- **Protocol:** WebDAV via Dio HTTP client
- **Auth:** Basic authentication
- **Operations:** Upload, download, list, delete via WebDAV methods (PUT, GET, PROPFIND, DELETE)
- **Directory:** Auto-creates remote folder structure via MKCOL

---

## App Initialization Flow

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `StorageService.initialize()` — Hive setup with custom directory
3. `NextcloudService.initialize()` — Restore saved credentials
4. `PermissionService.requestStoragePermissions()` — Android permissions
5. `runApp(ProviderScope(child: DocumentScannerApp()))`
6. `MaterialApp.router` with `BlocBuilder`-style theme switching via Riverpod

---

## CI/CD Pipeline

**File:** `.github/workflows/flutter_build.yml` (Gitea Actions)

### Jobs

1. **test** (debian-latest, Flutter 3.41.2)
   - `flutter analyze --no-fatal-infos`
   - `flutter test test/core/ test/features/`
   - Gates all build jobs

2. **version-bump** (needs: test, push to main only)
   - Increments patch version in `pubspec.yaml`
   - Commits with `[skip ci]`, creates annotated tag

3. **build-android** (needs: test + version-bump)
   - Builds APK + AAB
   - Uploads to Gitea Release

4. **build-linux** (needs: test + version-bump)
   - Builds release bundle
   - Creates `.deb` package + tarball
   - Uploads to Gitea Release

### Triggers
- Push to `main`
- Pull request to `main`
- Manual dispatch

---

## Quick Reference Commands

```bash
# Development
flutter run
flutter run -d linux

# Testing
flutter test test/core/ test/features/
flutter analyze

# Code Generation (Hive, JSON)
dart run build_runner build --delete-conflicting-outputs

# Dependencies
flutter pub get
flutter pub upgrade
flutter pub outdated

# Building
flutter build apk --release
flutter build linux --release

# Clean
flutter clean
```

---

## Adding New Features Checklist

1. Create feature directory under `lib/features/<feature_name>/`
2. Add pages in `presentation/pages/`
3. Add widgets in `presentation/widgets/`
4. Add models in `core/models/` if needed (with Hive/JSON annotations)
5. Add services in `core/services/` if needed
6. Add providers in `core/providers/` if needed
7. Add route in `core/router/app_router.dart`
8. Add tests in `test/features/<feature_name>/`
9. Run `flutter test test/core/ test/features/` and `flutter analyze` — 0 errors
10. Update `test/TEST_COVERAGE.md` with test inventory
11. Update this document if significant architectural additions

---

*Last updated: 2026-03-04*
