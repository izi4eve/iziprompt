import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';

class PromptPanel extends ConsumerWidget {
  const PromptPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final settingsNotifier = ref.read(appSettingsProvider.notifier);

    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Текстовое поле для ввода
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: TextEditingController(text: settings.promptText)
                  ..selection = TextSelection.collapsed(offset: settings.promptText.length),
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(fontSize: settings.fontSize),
                decoration: const InputDecoration(
                  hintText: 'Введите текст для чтения...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12.0),
                ),
                onChanged: (text) {
                  settingsNotifier.updatePromptText(text);
                },
              ),
            ),
          ),
          
          // Панель управления внизу
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                // Слайдер размера шрифта
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      const Icon(Icons.text_fields, size: 16),
                      Expanded(
                        child: Slider(
                          value: settings.fontSize,
                          min: 10.0,
                          max: 30.0,
                          divisions: 20,
                          label: '${settings.fontSize.round()}',
                          onChanged: (value) {
                            settingsNotifier.updateFontSize(value);
                          },
                        ),
                      ),
                      Text('${settings.fontSize.round()}'),
                    ],
                  ),
                ),
                
                const SizedBox(width: 8),
                
                // Кнопка смены местами панелей
                IconButton(
                  onPressed: () {
                    settingsNotifier.toggleSwapped();
                  },
                  icon: const Icon(Icons.swap_horiz),
                  tooltip: 'Поменять местами панели',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}