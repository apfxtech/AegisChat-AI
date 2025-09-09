// lib/providers/openai_provider.dart (fixed initialHistory by using setter to notifyListeners on load, ensuring all history messages display)
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:openai_dart/openai_dart.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

class OpenAIProvider extends ChangeNotifier implements LlmProvider {
  late final OpenAIClient _client;
  List<ChatMessage> _history = [];

  @override
  Iterable<ChatMessage> get history => _history;

  @override
  set history(Iterable<ChatMessage> h) {
    _history = h.toList();
    notifyListeners();
  }

  OpenAIProvider({
    required String apiKey,
    required String baseUrl,
    required String model,
    required double temperature,
    required double topP,
    required double maxTokens,
    Iterable<ChatMessage>? initialHistory,
  })  : _model = model,
        _temperature = temperature,
        _topP = topP,
        _maxTokens = maxTokens.toInt() {
    // Debug для проверки применения настроек
    debugPrint('OpenAIProvider init: apiKey=${apiKey.isEmpty ? "EMPTY" : apiKey.substring(0, 5)}..., baseUrl=$baseUrl, model=$model, temperature=$temperature, topP=$_topP, maxTokens=$_maxTokens');
    _client = OpenAIClient(
      apiKey: apiKey,
      baseUrl: baseUrl,
    );
    // Use setter to set initial history and notifyListeners for UI to render all messages
    if (initialHistory != null) {
      history = initialHistory;
    }
  }

  final String _model;
  final double _temperature;
  final double _topP;
  final int _maxTokens;

  @override
  Stream<String> sendMessageStream(String prompt, {Iterable<Attachment>? attachments}) async* {
    final userMessage = ChatMessage.user(prompt, attachments ?? const []);
    _history.add(userMessage);
    notifyListeners();

    final List<ChatCompletionMessage> openaiMessages = [];
    openaiMessages.add(ChatCompletionMessage.system(
      content: 'You are a helpful assistant.',
    ));
    for (final msg in _history) {
      final text = msg.text ?? '';
      if (msg.origin.isUser) {
        openaiMessages.add(ChatCompletionMessage.user(
          content: ChatCompletionUserMessageContent.string(text),
        ));
      } else {
        openaiMessages.add(ChatCompletionMessage.assistant(
          content: text,
        ));
      }
    }

    Stream<CreateChatCompletionStreamResponse> stream;
    try {
      stream = _client.createChatCompletionStream(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(_model),
          messages: openaiMessages,
          stream: true,
          temperature: _temperature,
          topP: _topP,
          maxTokens: _maxTokens,
        ),
      );
      debugPrint('OpenAI stream started successfully with model=$_model');
    } catch (e) {
      debugPrint('Error starting OpenAI stream: $e');
      yield '';
      return;
    }

    final assistantMessage = ChatMessage(
      origin: MessageOrigin.llm,
      text: '',
      attachments: const [],
    );
    _history.add(assistantMessage);
    notifyListeners();

    String buffer = '';
    try {
      await for (final res in stream) {
        final choices = res.choices;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices.first;
          final delta = choice.delta;
          if (delta != null) {
            final deltaText = delta.content ?? '';
            if (deltaText.isNotEmpty) {
              buffer += deltaText;
              assistantMessage.text = buffer;
              notifyListeners();
              yield deltaText;
            }
          }
        }
      }
      debugPrint('OpenAI stream completed.');
    } catch (e) {
      debugPrint('Error in OpenAI stream: $e');
      assistantMessage.text = 'Ошибка: $e';
      notifyListeners();
    }
  }

  @override
  Stream<String> generateStream(String prompt, {Iterable<Attachment>? attachments}) async* {
    final List<ChatCompletionMessage> openaiMessages = [
      ChatCompletionMessage.system(content: 'You are a helpful assistant.'),
      ChatCompletionMessage.user(
        content: ChatCompletionUserMessageContent.string(prompt),
      ),
    ];

    Stream<CreateChatCompletionStreamResponse> stream;
    try {
      stream = _client.createChatCompletionStream(
        request: CreateChatCompletionRequest(
          model: ChatCompletionModel.modelId(_model),
          messages: openaiMessages,
          stream: true,
          temperature: _temperature,
          topP: _topP,
          maxTokens: _maxTokens,
        ),
      );
      debugPrint('OpenAI generate stream started.');
    } catch (e) {
      debugPrint('Error starting generate stream: $e');
      yield '';
      return;
    }

    String buffer = '';
    try {
      await for (final res in stream) {
        final choices = res.choices;
        if (choices != null && choices.isNotEmpty) {
          final choice = choices.first;
          final delta = choice.delta;
          if (delta != null) {
            final deltaText = delta.content ?? '';
            if (deltaText.isNotEmpty) {
              buffer += deltaText;
              yield deltaText;
            }
          }
        }
      }
      debugPrint('Generate stream completed.');
    } catch (e) {
      debugPrint('Error in generate stream: $e');
    }
  }
}