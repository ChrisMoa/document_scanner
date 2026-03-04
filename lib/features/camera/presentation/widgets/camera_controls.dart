import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CameraControls extends StatefulWidget {
  final VoidCallback onCapture;
  final bool isCapturing;
  final int capturedCount;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onSettingsTap;
  final bool enableAutoCapture;
  final VoidCallback? onAutoCaptureTap;

  const CameraControls({
    super.key,
    required this.onCapture,
    required this.isCapturing,
    required this.capturedCount,
    this.onGalleryTap,
    this.onSettingsTap,
    this.enableAutoCapture = false,
    this.onAutoCaptureTap,
  });

  @override
  State<CameraControls> createState() => _CameraControlsState();
}

class _CameraControlsState extends State<CameraControls> with TickerProviderStateMixin {
  late AnimationController _captureAnimationController;
  late AnimationController _pulseAnimationController;
  late Animation<double> _captureAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _captureAnimationController = AnimationController(duration: const Duration(milliseconds: 200), vsync: this);

    _pulseAnimationController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this);

    _captureAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _captureAnimationController, curve: Curves.easeInOut));

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut));

    // Start pulse animation if auto-capture is enabled
    if (widget.enableAutoCapture) {
      _pulseAnimationController.repeat(reverse: true);
    }

    debugPrint('CameraControls initialized with ${widget.capturedCount} captured images');
  }

  @override
  void didUpdateWidget(CameraControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle auto-capture animation
    if (widget.enableAutoCapture != oldWidget.enableAutoCapture) {
      if (widget.enableAutoCapture) {
        _pulseAnimationController.repeat(reverse: true);
      } else {
        _pulseAnimationController.stop();
        _pulseAnimationController.reset();
      }
    }

    // Handle capture state changes
    if (widget.isCapturing != oldWidget.isCapturing) {
      if (widget.isCapturing) {
        _captureAnimationController.forward();
      } else {
        _captureAnimationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _captureAnimationController.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, crossAxisAlignment: CrossAxisAlignment.center, children: [_buildGalleryButton(), _buildCaptureButton(), _buildSettingsButton()]),
    );
  }

  Widget _buildGalleryButton() {
    return GestureDetector(
      onTap: widget.onGalleryTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
          color: widget.capturedCount > 0 ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.3),
        ),
        child: Stack(
          children: [
            Center(child: Icon(Icons.photo_library, color: Colors.white, size: 24)),
            if (widget.capturedCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: AnimatedScale(
                  scale: widget.capturedCount > 0 ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    child: Text(widget.capturedCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap:
          widget.isCapturing
              ? null
              : () {
                _triggerHapticFeedback();
                widget.onCapture();
              },
      child: AnimatedBuilder(
        animation: Listenable.merge([_captureAnimation, _pulseAnimation]),
        builder: (context, child) {
          final scale = _captureAnimation.value * (widget.enableAutoCapture ? _pulseAnimation.value : 1.0);

          return Transform.scale(
            scale: scale,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), color: Colors.transparent),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(shape: BoxShape.circle, color: widget.isCapturing ? Colors.grey.withOpacity(0.8) : Colors.white),
                child: widget.isCapturing ? _buildCaptureLoadingIndicator() : _buildCaptureIcon(),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCaptureLoadingIndicator() {
    return const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 3));
  }

  Widget _buildCaptureIcon() {
    return Icon(widget.enableAutoCapture ? Icons.auto_fix_high : Icons.camera_alt, color: Colors.black, size: 32);
  }

  Widget _buildSettingsButton() {
    return GestureDetector(
      onTap: widget.onAutoCaptureTap ?? widget.onSettingsTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
          color: widget.enableAutoCapture ? Colors.green.withOpacity(0.3) : Colors.black.withOpacity(0.3),
        ),
        child: Icon(widget.enableAutoCapture ? Icons.auto_fix_high : Icons.tune, color: widget.enableAutoCapture ? Colors.green : Colors.white, size: 24),
      ),
    );
  }

  void _triggerHapticFeedback() {
    try {
      HapticFeedback.mediumImpact();
      debugPrint('Camera capture haptic feedback triggered');
    } catch (e) {
      debugPrint('Haptic feedback error: $e');
    }
  }
}

class CameraControlsAdvanced extends StatefulWidget {
  final VoidCallback onCapture;
  final bool isCapturing;
  final int capturedCount;
  final VoidCallback? onGalleryTap;
  final VoidCallback? onFlashToggle;
  final VoidCallback? onCameraSwitch;
  final VoidCallback? onGridToggle;
  final VoidCallback? onTimerToggle;
  final String flashMode;
  final bool isGridEnabled;
  final bool isTimerEnabled;
  final bool hasMultipleCameras;

  const CameraControlsAdvanced({
    super.key,
    required this.onCapture,
    required this.isCapturing,
    required this.capturedCount,
    this.onGalleryTap,
    this.onFlashToggle,
    this.onCameraSwitch,
    this.onGridToggle,
    this.onTimerToggle,
    this.flashMode = 'off',
    this.isGridEnabled = false,
    this.isTimerEnabled = false,
    this.hasMultipleCameras = true,
  });

  @override
  State<CameraControlsAdvanced> createState() => _CameraControlsAdvancedState();
}

class _CameraControlsAdvancedState extends State<CameraControlsAdvanced> {
  bool _showAdvancedControls = false;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [if (_showAdvancedControls) _buildAdvancedControls(), _buildMainControls()]);
  }

  Widget _buildAdvancedControls() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: _showAdvancedControls ? 60 : 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildAdvancedButton(icon: _getFlashIcon(), isActive: widget.flashMode != 'off', onTap: widget.onFlashToggle, tooltip: 'Flash: ${widget.flashMode}'),
            if (widget.hasMultipleCameras) _buildAdvancedButton(icon: Icons.flip_camera_android, isActive: false, onTap: widget.onCameraSwitch, tooltip: 'Switch Camera'),
            _buildAdvancedButton(icon: Icons.grid_on, isActive: widget.isGridEnabled, onTap: widget.onGridToggle, tooltip: 'Grid Lines'),
            _buildAdvancedButton(icon: Icons.timer, isActive: widget.isTimerEnabled, onTap: widget.onTimerToggle, tooltip: 'Timer'),
          ],
        ),
      ),
    );
  }

  Widget _buildMainControls() {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [_buildGalleryButton(), _buildCaptureButton(), _buildMoreButton()]),
    );
  }

  Widget _buildGalleryButton() {
    return GestureDetector(
      onTap: widget.onGalleryTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          color: widget.capturedCount > 0 ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.3),
        ),
        child: Stack(
          children: [
            const Center(child: Icon(Icons.photo_library, color: Colors.white, size: 24)),
            if (widget.capturedCount > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: Text(widget.capturedCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: widget.isCapturing ? null : widget.onCapture,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4)),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(shape: BoxShape.circle, color: widget.isCapturing ? Colors.grey : Colors.white),
          child:
              widget.isCapturing
                  ? const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Icon(Icons.camera_alt, color: Colors.black, size: 32),
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showAdvancedControls = !_showAdvancedControls;
        });
        debugPrint('Advanced camera controls toggled: $_showAdvancedControls');
      },
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          color: _showAdvancedControls ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
        ),
        child: Icon(_showAdvancedControls ? Icons.expand_less : Icons.more_horiz, color: Colors.white, size: 24),
      ),
    );
  }

  Widget _buildAdvancedButton({required IconData icon, required bool isActive, required VoidCallback? onTap, required String tooltip}) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3),
            border: Border.all(color: isActive ? Colors.white : Colors.white.withOpacity(0.5), width: 1),
          ),
          child: Icon(icon, color: isActive ? Colors.white : Colors.white.withOpacity(0.7), size: 20),
        ),
      ),
    );
  }

  IconData _getFlashIcon() {
    switch (widget.flashMode.toLowerCase()) {
      case 'auto':
        return Icons.flash_auto;
      case 'on':
      case 'always':
        return Icons.flash_on;
      case 'torch':
        return Icons.flashlight_on;
      default:
        return Icons.flash_off;
    }
  }
}
