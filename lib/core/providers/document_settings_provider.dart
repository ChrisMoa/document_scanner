import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:document_scanner/core/models/settings_model.dart';

class DocumentSettingsNotifier extends StateNotifier<DocumentProcessingSettings> {
  DocumentSettingsNotifier() : super(const DocumentProcessingSettings()) {
    _loadSettings();
  }

  static const String _storageKey = 'document_processing_settings';

  Future<void> _loadSettings() async {
    try {
      debugPrint('📱 Loading document processing settings...');
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = prefs.getString(_storageKey);

      if (settingsJson != null) {
        final Map<String, dynamic> json = jsonDecode(settingsJson);
        final settings = DocumentProcessingSettings.fromJson(json);
        debugPrint('✅ Loaded settings from storage: $settings');
        debugPrint('🔄 Setting enableFiltering to: ${settings.enableFiltering}');
        state = settings;
      } else {
        debugPrint('💡 No saved settings found, using defaults');
        debugPrint('🔄 Default enableFiltering: ${state.enableFiltering}');
      }
    } catch (e) {
      debugPrint('❌ Error loading document settings: $e');
      // Keep default settings if loading fails
      debugPrint('🔄 Fallback enableFiltering: ${state.enableFiltering}');
    }
  }

  Future<void> _saveSettings() async {
    try {
      debugPrint('💾 Saving document processing settings...');
      debugPrint('🔄 Current enableFiltering: ${state.enableFiltering}');
      final prefs = await SharedPreferences.getInstance();
      final settingsJson = jsonEncode(state.toJson());
      await prefs.setString(_storageKey, settingsJson);
      debugPrint('✅ Settings saved successfully: $settingsJson');
    } catch (e) {
      debugPrint('❌ Error saving document settings: $e');
    }
  }

  Future<void> updateBlackWhiteThreshold(double threshold) async {
    debugPrint('🎚️ Updating black/white threshold: $threshold');
    state = state.copyWith(blackWhiteThreshold: threshold);
    await _saveSettings();
  }

  Future<void> updateSharpnessAmount(double amount) async {
    debugPrint('⚡ Updating sharpness amount: $amount');
    state = state.copyWith(sharpnessAmount: amount);
    await _saveSettings();
  }

  Future<void> updateSharpnessRadius(double radius) async {
    debugPrint('📐 Updating sharpness radius: $radius');
    state = state.copyWith(sharpnessRadius: radius);
    await _saveSettings();
  }

  Future<void> updateSharpnessThreshold(int threshold) async {
    debugPrint('🎯 Updating sharpness threshold: $threshold');
    state = state.copyWith(sharpnessThreshold: threshold);
    await _saveSettings();
  }

  Future<void> updateContrastLevel(double contrast) async {
    debugPrint('📈 Updating contrast level: $contrast');
    state = state.copyWith(contrastLevel: contrast);
    await _saveSettings();
  }

  Future<void> updateBrightnessLevel(double brightness) async {
    debugPrint('💡 Updating brightness level: $brightness');
    state = state.copyWith(brightnessLevel: brightness);
    await _saveSettings();
  }

  Future<void> updateGammaCorrection(double gamma) async {
    debugPrint('🌈 Updating gamma correction: $gamma');
    state = state.copyWith(gammaCorrection: gamma);
    await _saveSettings();
  }

  Future<void> resetToDefaults() async {
    debugPrint('🔄 Resetting document settings to defaults');
    state = const DocumentProcessingSettings();
    await _saveSettings();
  }

  Future<void> updateSettings(DocumentProcessingSettings settings) async {
    debugPrint('🔧 Updating all document settings: $settings');
    state = settings;
    await _saveSettings();
  }

  Future<void> toggleFiltering(bool enabled) async {
    debugPrint('🔄 ===== TOGGLE FILTERING CALLED =====');
    debugPrint('🔄 Previous enableFiltering: ${state.enableFiltering}');
    debugPrint('🔄 New enableFiltering: $enabled');

    final oldState = state;
    state = state.copyWith(enableFiltering: enabled);

    debugPrint('🔄 State updated - Old: ${oldState.enableFiltering}, New: ${state.enableFiltering}');

    await _saveSettings();

    debugPrint('🔄 ===== TOGGLE FILTERING COMPLETE =====');
  }
}

// Provider for document processing settings
final documentSettingsProvider = StateNotifierProvider<DocumentSettingsNotifier, DocumentProcessingSettings>((ref) {
  return DocumentSettingsNotifier();
});
