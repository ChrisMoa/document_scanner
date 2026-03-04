import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraService {
  static List<CameraDescription> _cameras = [];
  static CameraController? _controller;
  static bool _isInitialized = false;

  static Future<bool> initialize() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        return false;
      }

      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      return false;
    }
  }

  static Future<bool> initializeController({int cameraIndex = 0}) async {
    try {
      if (_cameras.isEmpty) {
        await initialize();
      }

      if (_cameras.isEmpty || cameraIndex >= _cameras.length) {
        return false;
      }

      _controller = CameraController(_cameras[cameraIndex], ResolutionPreset.high, enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);

      await _controller!.initialize();
      _isInitialized = true;
      return true;
    } catch (e) {
      debugPrint('Camera controller initialization error: $e');
      return false;
    }
  }

  static CameraController? get controller => _controller;
  static bool get isInitialized => _isInitialized && _controller?.value.isInitialized == true;
  static List<CameraDescription> get cameras => _cameras;

  static Future<String?> takePicture() async {
    if (!isInitialized || _controller == null) {
      return null;
    }

    try {
      final XFile image = await _controller!.takePicture();
      return image.path;
    } catch (e) {
      debugPrint('Take picture error: $e');
      return null;
    }
  }

  static Future<Uint8List?> takePictureAsBytes() async {
    final imagePath = await takePicture();
    if (imagePath == null) return null;

    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      await file.delete();
      return bytes;
    } catch (e) {
      debugPrint('Error reading image bytes: $e');
      return null;
    }
  }

  static Future<void> setFlashMode(FlashMode mode) async {
    if (!isInitialized || _controller == null) return;

    try {
      await _controller!.setFlashMode(mode);
    } catch (e) {
      debugPrint('Set flash mode error: $e');
    }
  }

  static Future<void> setFocusMode(FocusMode mode) async {
    if (!isInitialized || _controller == null) return;

    try {
      await _controller!.setFocusMode(mode);
    } catch (e) {
      debugPrint('Set focus mode error: $e');
    }
  }

  static Future<void> setExposureMode(ExposureMode mode) async {
    if (!isInitialized || _controller == null) return;

    try {
      await _controller!.setExposureMode(mode);
    } catch (e) {
      debugPrint('Set exposure mode error: $e');
    }
  }

  static Future<void> setZoomLevel(double zoom) async {
    if (!isInitialized || _controller == null) return;

    try {
      final maxZoom = await _controller!.getMaxZoomLevel();
      final minZoom = await _controller!.getMinZoomLevel();
      final clampedZoom = zoom.clamp(minZoom, maxZoom);
      await _controller!.setZoomLevel(clampedZoom);
    } catch (e) {
      debugPrint('Set zoom level error: $e');
    }
  }

  static Future<void> focusOnPoint(Offset point) async {
    if (!isInitialized || _controller == null) return;

    try {
      await _controller!.setFocusPoint(point);
      await _controller!.setExposurePoint(point);
    } catch (e) {
      debugPrint('Focus on point error: $e');
    }
  }

  static Future<bool> switchCamera() async {
    if (_cameras.length < 2) return false;

    try {
      final currentIndex = _cameras.indexOf(_controller!.description);
      final nextIndex = (currentIndex + 1) % _cameras.length;

      await dispose();
      return await initializeController(cameraIndex: nextIndex);
    } catch (e) {
      debugPrint('Switch camera error: $e');
      return false;
    }
  }

  static Future<void> dispose() async {
    if (_controller != null) {
      await _controller!.dispose();
      _controller = null;
      _isInitialized = false;
    }
  }

  static Future<bool> hasFlash() async {
    if (!isInitialized || _controller == null) return false;

    try {
      final cameras = await availableCameras();
      final currentCamera = _controller!.description;
      return cameras.any((camera) => camera.name == currentCamera.name && camera.lensDirection == currentCamera.lensDirection);
    } catch (e) {
      return false;
    }
  }

  static FlashMode get currentFlashMode {
    return _controller?.value.flashMode ?? FlashMode.off;
  }

  static bool get hasMultipleCameras => _cameras.length > 1;

  static String get currentCameraDirection {
    if (_controller == null) return 'Unknown';
    return _controller!.description.lensDirection == CameraLensDirection.back ? 'Back' : 'Front';
  }
}
