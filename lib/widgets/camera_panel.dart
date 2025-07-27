import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/app_state.dart';

class CameraPanel extends ConsumerStatefulWidget {
  const CameraPanel({super.key});

  @override
  ConsumerState<CameraPanel> createState() => _CameraPanelState();
}

class _CameraPanelState extends ConsumerState<CameraPanel> {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    final cameraStatus = await Permission.camera.request();
    final microphoneStatus = await Permission.microphone.request();
    final storageStatus = await Permission.storage.request();
    
    if (cameraStatus.isGranted && microphoneStatus.isGranted) {
      setState(() {
        _permissionGranted = true;
      });
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await ref.read(availableCamerasProvider.future);
      final settings = ref.read(appSettingsProvider);
      
      if (cameras.isEmpty) return;
      
      // Фильтруем только основные камеры (исключаем телефото и ультраширокие)
      final mainCameras = cameras.where((camera) {
        // Оставляем только основные камеры по направлению
        return camera.lensDirection == CameraLensDirection.back || 
               camera.lensDirection == CameraLensDirection.front;
      }).toList();
      
      // Берем первую заднюю и первую переднюю
      final uniqueCameras = <CameraDescription>[];
      CameraDescription? backCamera;
      CameraDescription? frontCamera;
      
      for (final camera in mainCameras) {
        if (camera.lensDirection == CameraLensDirection.back && backCamera == null) {
          backCamera = camera;
        }
        if (camera.lensDirection == CameraLensDirection.front && frontCamera == null) {
          frontCamera = camera;
        }
      }
      
      if (backCamera != null) uniqueCameras.add(backCamera);
      if (frontCamera != null) uniqueCameras.add(frontCamera);
      
      if (uniqueCameras.isEmpty) return;
      
      final cameraIndex = settings.selectedCameraIndex < uniqueCameras.length 
          ? settings.selectedCameraIndex 
          : 0;
      
      _cameraController = CameraController(
        uniqueCameras[cameraIndex],
        settings.resolution,
        enableAudio: true,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Ошибка инициализации камеры: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);
    final isRecording = ref.watch(isRecordingProvider);
    final camerasAsync = ref.watch(availableCamerasProvider);

    return Container(
      color: Colors.black,
      child: Column(
        children: [
          // Область камеры
          Expanded(
            child: Stack(
              children: [
                // Камера выровнена по верху
                Align(
                  alignment: Alignment.topCenter,
                  child: _buildCameraPreview(),
                ),
                // Композиционная сетка
                if (_isInitialized) _buildCompositionGrid(),
              ],
            ),
          ),
          
          // Панель управления камерой - выровнена по низу
          Container(
            height: 80,
            width: double.infinity, // Растягиваем на всю ширину
            color: Colors.grey[900],
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: camerasAsync.when(
              data: (cameras) => _buildCameraControls(cameras, settings, settingsNotifier, isRecording),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(child: Text('Ошибка: $error', style: TextStyle(color: Colors.white))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (!_permissionGranted) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.camera_alt, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'Требуется разрешение на использование камеры',
              style: TextStyle(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (!_isInitialized || _cameraController == null || !_cameraController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    // Обеспечиваем соотношение 16:9 и фиксируем ориентацию
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CameraPreview(_cameraController!),
    );
  }

  // Композиционная сетка 4x4
  Widget _buildCompositionGrid() {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: CustomPaint(
        painter: CompositionGridPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildCameraControls(
    List<CameraDescription> cameras,
    AppSettings settings,
    AppSettingsNotifier settingsNotifier,
    bool isRecording,
  ) {
    // Фильтруем камеры так же, как в _initializeCamera
    final mainCameras = cameras.where((camera) {
      return camera.lensDirection == CameraLensDirection.back || 
             camera.lensDirection == CameraLensDirection.front;
    }).toList();
    
    final uniqueCameras = <CameraDescription>[];
    CameraDescription? backCamera;
    CameraDescription? frontCamera;
    
    for (final camera in mainCameras) {
      if (camera.lensDirection == CameraLensDirection.back && backCamera == null) {
        backCamera = camera;
      }
      if (camera.lensDirection == CameraLensDirection.front && frontCamera == null) {
        frontCamera = camera;
      }
    }
    
    if (backCamera != null) uniqueCameras.add(backCamera);
    if (frontCamera != null) uniqueCameras.add(frontCamera);

    return Row(
      children: [
        // Выбор камеры
        SizedBox(
          width: 80,
          child: DropdownButton<int>(
            value: settings.selectedCameraIndex < uniqueCameras.length 
                ? settings.selectedCameraIndex 
                : 0,
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white, fontSize: 11),
            isExpanded: true,
            underline: Container(),
            items: uniqueCameras.asMap().entries.map((entry) {
              return DropdownMenuItem<int>(
                value: entry.key,
                child: Text(
                  entry.value.lensDirection == CameraLensDirection.back 
                      ? 'Задняя' 
                      : 'Перед',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null && value != settings.selectedCameraIndex) {
                settingsNotifier.updateCameraSettings(selectedCameraIndex: value);
                Future.microtask(() => _reinitializeCamera());
              }
            },
          ),
        ),
        
        const SizedBox(width: 4),
        
        // Выбор разрешения
        SizedBox(
          width: 60,
          child: DropdownButton<ResolutionPreset>(
            value: settings.resolution,
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white, fontSize: 11),
            isExpanded: true,
            underline: Container(),
            items: [
              ResolutionPreset.medium,
              ResolutionPreset.high,
              ResolutionPreset.veryHigh,
              ResolutionPreset.ultraHigh,
            ].map((preset) {
              String label;
              switch (preset) {
                case ResolutionPreset.medium:
                  label = 'HD';
                  break;
                case ResolutionPreset.high:
                  label = 'FHD';
                  break;
                case ResolutionPreset.veryHigh:
                  label = 'UHD';
                  break;
                case ResolutionPreset.ultraHigh:
                  label = '4K';
                  break;
                default:
                  label = 'HD';
              }
              return DropdownMenuItem<ResolutionPreset>(
                value: preset,
                child: Text(label),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null && value != settings.resolution) {
                settingsNotifier.updateCameraSettings(resolution: value);
                Future.microtask(() => _reinitializeCamera());
              }
            },
          ),
        ),
        
        const SizedBox(width: 4),
        
        // FPS
        SizedBox(
          width: 60,
          child: DropdownButton<int>(
            value: settings.fps,
            dropdownColor: Colors.grey[800],
            style: const TextStyle(color: Colors.white, fontSize: 11),
            isExpanded: true,
            underline: Container(),
            items: [24, 30, 60].map((fps) {
              return DropdownMenuItem<int>(
                value: fps,
                child: Text('${fps}fps'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                settingsNotifier.updateCameraSettings(fps: value);
              }
            },
          ),
        ),
        
        const SizedBox(width: 4),
        
        // Экспозиция - увеличили ширину и добавили защиту от ошибок
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('EV', style: TextStyle(color: Colors.white, fontSize: 10)),
              Slider(
                value: settings.exposureOffset,
                min: -2.0,
                max: 2.0,
                divisions: 40,
                activeColor: Colors.white,
                inactiveColor: Colors.grey,
                onChanged: _cameraController != null && _isInitialized ? (value) {
                  settingsNotifier.updateCameraSettings(exposureOffset: value);
                  // Вызываем setExposureOffset с защитой от ошибок
                  _setExposureOffset(value);
                } : null,
              ),
            ],
          ),
        ),
        
        const SizedBox(width: 8),
        
        // Кнопка записи
        IconButton(
          onPressed: _cameraController != null && _isInitialized ? () {
            if (isRecording) {
              _stopRecording();
            } else {
              _startRecording();
            }
          } : null,
          icon: Icon(
            isRecording ? Icons.stop : Icons.play_arrow,
            color: isRecording ? Colors.red : Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }

  Future<void> _reinitializeCamera() async {
    try {
      if (_cameraController != null) {
        final wasRecording = ref.read(isRecordingProvider);
        
        // Останавливаем запись если была активна
        if (wasRecording && _cameraController!.value.isRecordingVideo) {
          try {
            await _cameraController!.stopVideoRecording();
            ref.read(isRecordingProvider.notifier).state = false;
          } catch (e) {
            debugPrint('Ошибка остановки записи при переинициализации: $e');
          }
        }
        
        // Сначала меняем состояние, чтобы UI не пытался использовать контроллер
        setState(() {
          _isInitialized = false;
        });
        
        await _cameraController!.dispose();
        _cameraController = null;
        
        // Небольшая задержка для завершения dispose
        await Future.delayed(const Duration(milliseconds: 200));
      }
      
      await _initializeCamera();
    } catch (e) {
      debugPrint('Ошибка переинициализации камеры: $e');
      if (mounted) {
        setState(() {
          _isInitialized = false;
        });
      }
    }
  }

  // Безопасная установка экспозиции
  void _setExposureOffset(double value) {
    if (_cameraController != null && _isInitialized && _cameraController!.value.isInitialized) {
      _cameraController!.setExposureOffset(value).catchError((error) {
        debugPrint('Ошибка установки экспозиции: $error');
        return 0.0; // Возвращаем значение по умолчанию
      });
    }
  }

  Future<String> _getVideoSavePath() async {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Для Android используем внешнее хранилище
      directory = await getExternalStorageDirectory();
      if (directory != null) {
        // Создаем папку в DCIM/IziPrompter
        final dcimPath = directory.path.replaceAll('/Android/data/com.example.iziprompt/files', '/DCIM/IziPrompter');
        directory = Directory(dcimPath);
      } else {
        // Fallback к Documents если внешнее хранилище недоступно
        directory = await getApplicationDocumentsDirectory();
        directory = Directory('${directory.path}/IziPrompt_Videos');
      }
    } else {
      // Для iOS используем Documents
      directory = await getApplicationDocumentsDirectory();
      directory = Directory('${directory.path}/IziPrompt_Videos');
    }
    
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory.path}/video_$timestamp.mp4';
  }

  Future<void> _startRecording() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || !_isInitialized) {
      debugPrint('Камера не инициализирована для записи');
      return;
    }

    try {
      await _cameraController!.startVideoRecording();
      ref.read(isRecordingProvider.notifier).state = true;
      debugPrint('Запись видео начата');
    } catch (e) {
      debugPrint('Ошибка начала записи: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка начала записи: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (_cameraController == null || !_cameraController!.value.isRecordingVideo) {
      debugPrint('Камера не записывает видео');
      return;
    }

    try {
      final videoFile = await _cameraController!.stopVideoRecording();
      ref.read(isRecordingProvider.notifier).state = false;
      
      // Получаем путь для сохранения
      final savePath = await _getVideoSavePath();
      final savedFile = await File(videoFile.path).copy(savePath);
      
      // Удаляем временный файл
      try {
        await File(videoFile.path).delete();
      } catch (e) {
        debugPrint('Не удалось удалить временный файл: $e');
      }
      
      debugPrint('Видео сохранено: $savePath');
      
      // Показываем уведомление о сохранении
      if (mounted) {
        final fileName = savePath.split('/').last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Видео сохранено: $fileName'),
                Text(
                  'Путь: ${Platform.isAndroid ? '/DCIM/IziPrompter/' : 'Documents/IziPrompt_Videos/'}',
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Ошибка остановки записи: $e');
      ref.read(isRecordingProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка остановки записи: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// Класс для рисования композиционной сетки 4x4
class CompositionGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // Рисуем вертикальные линии (3 линии для создания 4 столбцов)
    for (int i = 1; i < 4; i++) {
      final x = size.width / 4 * i;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // Рисуем горизонтальные линии (3 линии для создания 4 строк)
    for (int i = 1; i < 4; i++) {
      final y = size.height / 4 * i;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}