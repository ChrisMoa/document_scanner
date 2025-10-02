# Document Scanner App

A powerful Flutter mobile application for scanning documents using OpenCV, with PDF creation and cloud storage capabilities.

## Key Features Now Available ✨

The document scanner app now includes all the implemented features:

- 📱 **Camera Interface**: Professional document scanning UI with camera controls
- 🔍 **Auto Document Detection**: OpenCV-powered edge detection and contour analysis
- ✋ **Manual Corner Adjustment**: Samsung/Apple-style interactive corner fine-tuning
- 📐 **Perspective Correction**: Real-time document flattening and cropping
- 🎯 **Visual Feedback**: Corner handles, grid overlay, and visual guides
- 🔄 **Complete Workflow**: Capture → Detection → Manual Adjustment → Crop → Export

## Features

### 📱 Document Scanning

- **OpenCV Integration**: Automatic document detection and edge cropping
- **Camera Controls**: Manual focus, flash, zoom, and camera switching
- **Multi-page Sessions**: Scan multiple pages in one session
- **Image Enhancement**: Automatic brightness and contrast adjustment
- **Real-time Preview**: Live camera preview with document outline detection

### 📄 PDF Generation

- **Multi-page PDFs**: Create PDFs from scanned images
- **Custom Formatting**: A4 format with configurable margins
- **Metadata Support**: Add title, author, and creation info
- **File Management**: Automatic file naming with timestamps

### ☁️ Cloud Storage (Nextcloud)

- **WebDAV Authentication**: Secure Nextcloud integration (server URL, username, app password)
- **Automatic Upload**: Background sync to your Nextcloud storage
- **Cross-device Access**: Access documents from any device
- **Conflict Resolution**: Smart handling of file conflicts

### 🔒 Security & Encryption

- **AES Encryption**: Documents encrypted before cloud upload
- **Custom Key Management**: Secure key storage without flutter_secure_storage
- **Local Encryption**: Optional local document encryption
- **Privacy First**: No data collection, all processing local

### 🎨 User Experience

- **Material Design 3**: Modern, responsive UI
- **Dark/Light Themes**: System-aware theme switching
- **Persistent Storage**: Hive-based local database
- **Search & Filter**: Quick document discovery
- **Drag & Drop**: Reorder document pages

### 📸 Enhanced Document Scanning

- **Automatic Document Detection**: Uses OpenCV computer vision to automatically detect document boundaries in captured images
- **Manual Corner Adjustment**: Interactive corner adjustment interface allowing users to fine-tune document boundaries
- **Perspective Correction**: Automatically flattens and crops documents using perspective transformation
- **Real-time Preview**: Visual feedback showing detected document boundaries during capture
- **Grid Overlay**: Helpful grid lines during manual adjustment for better alignment

### 🔧 Document Processing Pipeline

1. **Capture**: Take a photo using the camera interface
2. **Detection**: Automatic edge detection and corner identification using OpenCV
3. **Adjustment**: Manual fine-tuning of corner points with intuitive drag-and-drop interface
4. **Transformation**: Perspective correction and document flattening
5. **Enhancement**: Optional image enhancement (brightness, contrast, noise reduction)
6. **Export**: Save as high-quality images and generate PDF documents

### 🎨 User Interface

- **Interactive Corner Handles**: Drag corner points to adjust document boundaries
- **Visual Feedback**: Color-coded corner indicators (TL, TR, BR, BL)
- **Grid Lines**: Helper grid for better document alignment
- **Semi-transparent Overlay**: Clear distinction between document area and background
- **Touch-friendly Controls**: Large touch targets for easy manipulation

## Installation

### Prerequisites

```bash
Flutter SDK >= 3.10.0
Dart SDK >= 3.0.0
```

### Dependencies Installation

```bash
flutter pub get
flutter packages pub run build_runner build
```

### Platform Setup

#### Android

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.INTERNET" />
```

#### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to save scanned documents</string>
```

## Project Structure

```
lib/
├── main.dart                           # App entry point
├── core/                              # Core functionality
│   ├── models/                        # Data models
│   │   ├── document_model.dart        # Document entity
│   │   └── scan_session_model.dart    # Scanning session entity
│   ├── providers/                     # State management
│   │   ├── theme_provider.dart        # Theme state
│   │   └── storage_provider.dart      # Document storage state
│   ├── router/                        # Navigation
│   │   └── app_router.dart           # GoRouter configuration
│   ├── services/                      # Business logic
│   │   ├── camera_service.dart       # Camera management
│   │   ├── opencv_service.dart       # Image processing
│   │   ├── pdf_service.dart          # PDF generation
│   │   ├── storage_service.dart      # Local storage
│   │   ├── encryption_service.dart   # Security & encryption
│   │   └── onedrive_service.dart     # Cloud integration
│   └── theme/                        # Theming
│       └── app_theme.dart           # Theme definitions
└── features/                         # Feature modules
    ├── home/                         # Home screen
    │   └── presentation/
    │       ├── pages/
    │       │   └── home_page.dart
    │       └── widgets/
    │           ├── document_card.dart
    │           ├── empty_state_widget.dart
    │           └── search_bar_widget.dart
    ├── camera/                       # Document scanning
    │   └── presentation/
    │       ├── pages/
    │       │   └── camera_page.dart
    │       └── widgets/
    │           ├── camera_controls.dart
    │           └── captured_images_preview.dart
    ├── document/                     # Document management
    │   └── presentation/
    │       └── pages/
    │           ├── document_detail_page.dart
    │           └── pdf_preview_page.dart
    ├── settings/                     # App settings
    │   └── presentation/
    │       └── pages/
    │           └── settings_page.dart
    └── cloud/                        # Cloud configuration
        └── presentation/
            └── pages/
                └── cloud_settings_page.dart
```

## Assets Structure

The application defines asset folders in `pubspec.yaml` but currently uses minimal assets:

```yaml
flutter:
  assets:
    - assets/images/ # App icons, logos, placeholder images
    - assets/icons/ # Custom icons for specific features
```

### Asset Usage Locations

#### Currently Referenced Assets:

- **No direct asset references** in the current codebase - the app uses Material Design icons and generated content

#### Potential Asset Usage:

1. **App Logo**: Could be placed in `assets/images/logo.png`
   - Used in: Splash screen, About page, Empty state
2. **Custom Icons**: Could be placed in `assets/icons/`

   - Document type icons (PDF, Image, etc.)
   - Cloud service logos (OneDrive, etc.)
   - Feature illustrations for empty states

3. **Placeholder Images**: Could be placed in `assets/images/placeholders/`
   - Document thumbnail placeholders
   - Error state illustrations
   - Tutorial/onboarding images

#### Asset Implementation Examples:

```dart
// In empty_state_widget.dart - could use custom illustration
Image.asset('assets/images/empty_documents.png')

// In cloud_settings_page.dart - could use OneDrive logo
Image.asset('assets/icons/onedrive_logo.png')

// In app_theme.dart - could use app logo
AssetImage('assets/images/app_logo.png')
```

## Configuration

### Nextcloud Setup

1. Create an App Password in your Nextcloud account (Settings → Security)
2. Open the app and go to Settings → Cloud & Sync → Nextcloud Integration
3. Enter your server URL, username, and app password, then Connect

### Storage Configuration

- Default location: `Documents/DocumentScanner/`
- Configurable via Settings
- Supports external storage selection

### Encryption Setup

- Automatic key generation
- Keys stored in device keystore
- No additional configuration required

## Usage

### Scanning Documents

1. Tap camera button on home screen
2. Point camera at document
3. App automatically detects document edges
4. Tap capture button
5. Review and retake if needed
6. Tap "Done" to save session

### Managing Documents

1. View all documents on home screen
2. Tap document to view details
3. Generate PDF, upload to cloud, or share
4. Rename or delete documents via menu

### Cloud Sync

1. Go to Settings → Nextcloud Integration
2. Enter server URL, username, and app password
3. Tap Connect
4. Documents automatically sync when connected

## Development

### Code Generation

```bash
# Generate Hive adapters and other generated code
flutter packages pub run build_runner build

# Watch for changes during development
flutter packages pub run build_runner watch
```

### Debug Messages

The app includes comprehensive debug logging:

- Camera operations
- Image processing steps
- PDF generation progress
- Cloud upload status
- Encryption operations

### Architecture Patterns

- **Riverpod**: State management
- **Feature-first**: Modular organization
- **Clean Architecture**: Separation of concerns
- **Provider Pattern**: Service injection

## Performance Considerations

### Image Processing

- OpenCV operations run on background isolates
- Images are compressed before storage
- Thumbnail generation for quick preview

### Storage Optimization

- Hive for fast local database operations
- Lazy loading of document images
- Automatic cleanup of temporary files

### Memory Management

- Proper disposal of camera controllers
- Image caching with size limits
- Background processing for heavy operations

## Security Features

### Local Security

- Documents encrypted with AES-256
- Keys derived from device-specific information
- Secure key storage without external dependencies

### Cloud Security

- OAuth2 authentication flow
- Documents encrypted before upload
- No plain text data transmission

### Privacy

- No analytics or tracking
- All processing happens locally
- User controls all data sharing

## Troubleshooting

### Common Issues

#### Camera Not Working

- Check camera permissions
- Ensure device has camera capability
- Restart app after permission grant

#### PDF Generation Fails

- Check storage permissions
- Ensure sufficient storage space
- Verify image files exist

#### Nextcloud Connection Issues

- Verify server URL, username, and app password
- Check internet connection
- Clear app data and re-authenticate

#### OpenCV Processing Slow

- Reduce image resolution in camera settings
- Close other apps to free memory
- Update to latest OpenCV version

### Debug Tools

```bash
# Enable debug prints
flutter run --debug

# Check storage usage
flutter run --verbose

# Profile performance
flutter run --profile
```

## Contributing

### Development Setup

1. Fork the repository
2. Create feature branch
3. Follow existing code style
4. Add tests for new features
5. Submit pull request

### Code Style

- Use provided analysis options
- Follow Dart/Flutter conventions
- Add documentation for public APIs
- Include debug print statements

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For issues and feature requests, please use the GitHub issue tracker.

---

**Note**: This app prioritizes user privacy and data security. All document processing happens locally on your device, and you control when and what data is shared with cloud services.
