import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';

// Состояние настроек приложения
class AppSettings {
  final double fontSize;
  final bool isSwapped; // поменялись ли местами части экрана
  final String promptText;
  final int selectedCameraIndex;
  final ResolutionPreset resolution;
  final int fps;
  final bool flashEnabled;
  final double exposureOffset;

  const AppSettings({
    this.fontSize = 16.0,
    this.isSwapped = false,
    this.promptText = '',
    this.selectedCameraIndex = 0,
    this.resolution = ResolutionPreset.high,
    this.fps = 30,
    this.flashEnabled = false,
    this.exposureOffset = 0.0,
  });

  AppSettings copyWith({
    double? fontSize,
    bool? isSwapped,
    String? promptText,
    int? selectedCameraIndex,
    ResolutionPreset? resolution,
    int? fps,
    bool? flashEnabled,
    double? exposureOffset,
  }) {
    return AppSettings(
      fontSize: fontSize ?? this.fontSize,
      isSwapped: isSwapped ?? this.isSwapped,
      promptText: promptText ?? this.promptText,
      selectedCameraIndex: selectedCameraIndex ?? this.selectedCameraIndex,
      resolution: resolution ?? this.resolution,
      fps: fps ?? this.fps,
      flashEnabled: flashEnabled ?? this.flashEnabled,
      exposureOffset: exposureOffset ?? this.exposureOffset,
    );
  }
}

// Provider для настроек приложения
class AppSettingsNotifier extends StateNotifier<AppSettings> {
  AppSettingsNotifier() : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Получаем список доступных камер для валидации
    List<CameraDescription> cameras = [];
    try {
      cameras = await availableCameras();
    } catch (e) {
      debugPrint('Ошибка получения списка камер: $e');
    }
    
    final savedCameraIndex = prefs.getInt('selectedCameraIndex') ?? 0;
    final validCameraIndex = cameras.isNotEmpty && savedCameraIndex < cameras.length 
        ? savedCameraIndex 
        : 0;
    
    state = AppSettings(
      fontSize: prefs.getDouble('fontSize') ?? 16.0,
      isSwapped: prefs.getBool('isSwapped') ?? false,
      promptText: prefs.getString('promptText') ?? '',
      selectedCameraIndex: validCameraIndex,
      resolution: ResolutionPreset.values[prefs.getInt('resolution') ?? ResolutionPreset.high.index],
      fps: prefs.getInt('fps') ?? 30,
      flashEnabled: prefs.getBool('flashEnabled') ?? false,
      exposureOffset: prefs.getDouble('exposureOffset') ?? 0.0,
    );
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    await Future.wait([
      prefs.setDouble('fontSize', state.fontSize),
      prefs.setBool('isSwapped', state.isSwapped),
      prefs.setString('promptText', state.promptText),
      prefs.setInt('selectedCameraIndex', state.selectedCameraIndex),
      prefs.setInt('resolution', state.resolution.index),
      prefs.setInt('fps', state.fps),
      prefs.setBool('flashEnabled', state.flashEnabled),
      prefs.setDouble('exposureOffset', state.exposureOffset),
    ]);
  }

  void updateFontSize(double fontSize) {
    state = state.copyWith(fontSize: fontSize);
    _saveSettings();
  }

  void toggleSwapped() {
    state = state.copyWith(isSwapped: !state.isSwapped);
    _saveSettings();
  }

  void updatePromptText(String text) {
    state = state.copyWith(promptText: text);
    _saveSettings();
  }

  void updateCameraSettings({
    int? selectedCameraIndex,
    ResolutionPreset? resolution,
    int? fps,
    bool? flashEnabled,
    double? exposureOffset,
  }) {
    state = state.copyWith(
      selectedCameraIndex: selectedCameraIndex,
      resolution: resolution,
      fps: fps,
      flashEnabled: flashEnabled,
      exposureOffset: exposureOffset,
    );
    _saveSettings();
  }
}

final appSettingsProvider = StateNotifierProvider<AppSettingsNotifier, AppSettings>((ref) {
  return AppSettingsNotifier();
});

// Provider для списка доступных камер
final availableCamerasProvider = FutureProvider<List<CameraDescription>>((ref) async {
  return await availableCameras();
});

// Provider для состояния записи
final isRecordingProvider = StateProvider<bool>((ref) => false);