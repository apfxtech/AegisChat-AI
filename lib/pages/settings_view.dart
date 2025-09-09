// lib/pages/settings_view.dart (no direct changes; lastModel update handled in HomePage's onSaveChat callback)
import 'package:flutter/material.dart';

class SettingsView extends StatefulWidget {
  final Map<String, dynamic> globalSettings;
  final Map<String, dynamic> chatSettings;
  final void Function(Map<String, dynamic>) onSaveGlobal;
  final void Function(Map<String, dynamic>) onSaveChat;

  const SettingsView({
    super.key,
    required this.globalSettings,
    required this.chatSettings,
    required this.onSaveGlobal,
    required this.onSaveChat,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _apiKeyController;
  late final TextEditingController _modelController;
  late double _temperature;
  late double _topP;
  late double _maxTokens;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.globalSettings['baseUrl'] ?? 'https://api.openai.com/v1');
    _apiKeyController = TextEditingController(text: widget.globalSettings['apiKey'] ?? '');
    _modelController = TextEditingController(text: widget.chatSettings['model'] ?? 'gpt-4o');
    _temperature = widget.chatSettings['temperature'] ?? 0.7;
    _topP = widget.chatSettings['topP'] ?? 1.0;
    _maxTokens = widget.chatSettings['maxTokens'] ?? 2048.0;
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16.0, 16.0, 16.0, 
          16.0 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Настройки нейро-чата', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            Text('Глобальные настройки (для всех чатов)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlController,
              decoration: const InputDecoration(
                labelText: 'Base URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'API Ключ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            Text('Настройки чата', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: 'Model',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            _buildSlider(
              label: 'Temperature',
              value: _temperature,
              min: 0.0,
              max: 2.0,
              divisions: 20,
              onChanged: (value) => setState(() => _temperature = value),
            ),
            _buildSlider(
              label: 'Top P',
              value: _topP,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (value) => setState(() => _topP = value),
            ),
            _buildSlider(
              label: 'Максимальное количество токенов',
              value: _maxTokens,
              min: 256.0,
              max: 8192.0,
              divisions: (8192 - 256) ~/ 256,
              onChanged: (value) => setState(() => _maxTokens = value),
              isInt: true,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: _onSave,
                  child: const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onSave() {
    // Save global
    final updatedGlobal = {
      'baseUrl': _baseUrlController.text,
      'apiKey': _apiKeyController.text,
    };
    debugPrint('SettingsView saving global: apiKey=${_apiKeyController.text.substring(0, 10)}..., baseUrl=${_baseUrlController.text}');
    widget.onSaveGlobal(updatedGlobal);

    // Save chat-specific
    final updatedChat = {
      'model': _modelController.text,
      'temperature': _temperature,
      'topP': _topP,
      'maxTokens': _maxTokens,
    };
    widget.onSaveChat(updatedChat);

    Navigator.of(context).pop();
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    bool isInt = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: ${isInt ? value.toInt() : value.toStringAsFixed(2)}'),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          label: isInt ? value.toInt().toString() : value.toStringAsFixed(2),
          onChanged: onChanged,
        ),
      ],
    );
  }
}