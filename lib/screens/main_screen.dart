import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../widgets/prompt_panel.dart';
import '../widgets/camera_panel.dart';

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            // Первая часть (1/3 или 2/3 в зависимости от isSwapped)
            Expanded(
              flex: settings.isSwapped ? 2 : 1,
              child: settings.isSwapped 
                ? const CameraPanel() 
                : const PromptPanel(),
            ),
            
            // Вторая часть (2/3 или 1/3 в зависимости от isSwapped)
            Expanded(
              flex: settings.isSwapped ? 1 : 2,
              child: settings.isSwapped 
                ? const PromptPanel() 
                : const CameraPanel(),
            ),
          ],
        ),
      ),
    );
  }
}