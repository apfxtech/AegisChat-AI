import 'package:openai_dart/openai_dart.dart';

void main() async {
  final openaiApiKey = 'sk-YE8SjzWC4ShaQf1wygBbXTgtjwaI5Xvb';
  final client = OpenAIClient(
    apiKey: openaiApiKey,
    baseUrl: 'https://api.proxyapi.ru/openai/v1',  // Без /v1
  );
  print('API Key set and baseUrl configured.');
  try {
    print('Starting stream request...');
    final stream = client.createChatCompletionStream(
      request: CreateChatCompletionRequest(
        model: ChatCompletionModel.modelId('gpt-4o'),  // Или 'gpt-3.5-turbo'
        messages: [
          ChatCompletionMessage.user(
            content: ChatCompletionUserMessageContent.string('Hello'),
          ),
        ],
      ),
    );
    String fullResponse = '';
    await for (final res in stream) {
      final choices = res.choices;  // Локальная переменная для promotion
      if (choices != null && choices.isNotEmpty) {
        final choice = choices.first;
        final delta = choice.delta;
        if (delta != null) {
          final deltaText = delta.content ?? '';
          if (deltaText.isNotEmpty) {
            fullResponse += deltaText;
            print('Delta: $deltaText');
          }
        }
      }
    }
    print('Full response: $fullResponse');
  } catch (e) {
    print('Error: $e');
  }
}