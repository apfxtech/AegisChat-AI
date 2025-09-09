// lib/pages/chat_page.dart (updated: check for 'Untitled' in _onHistoryChanged, display title in appbar if needed, but since shared, use display in tab)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';

import '../data/chat.dart';
import '../data/chat_repository.dart';
import '../providers/openai_provider.dart';

class ChatView extends StatefulWidget {
  final String chatId;
  final ChatRepository repository;
  final VoidCallback? onTitleChanged;

  const ChatView({
    super.key,
    required this.chatId,
    required this.repository,
    this.onTitleChanged,
  });

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  LlmProvider? _provider;
  late Chat _currentChat;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentChat = widget.repository.chats.singleWhere((chat) => chat.id == widget.chatId);
    final history = await widget.repository.getHistory(_currentChat);
    
    // Load globals and chat-specific settings (static call)
    final globals = await ChatRepository.getGlobalSettings();
    final apiKey = globals['apiKey'] as String? ?? '';
    final baseUrl = globals['baseUrl'] as String? ?? 'https://api.openai.com/v1';
    
    _setProvider(history, apiKey, baseUrl, _currentChat.model, _currentChat.temperature, _currentChat.topP, _currentChat.maxTokens);
  }

  void _setProvider(
    Iterable<ChatMessage>? history,
    String apiKey,
    String baseUrl,
    String model,
    double temperature,
    double topP,
    double maxTokens,
  ) {
    _provider?.removeListener(_onHistoryChanged);
    if (mounted) {
      setState(() => _provider = OpenAIProvider(
        apiKey: apiKey,
        baseUrl: baseUrl,
        model: model,
        temperature: temperature,
        topP: topP,
        maxTokens: maxTokens,
        initialHistory: history ?? [],
      ));
    }
    _provider!.addListener(_onHistoryChanged);
  }

  @override
  void dispose() {
    _provider?.removeListener(_onHistoryChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return LlmChatView(provider: _provider!);
  }

  Future<void> _onHistoryChanged() async {
    if (!mounted || _provider == null) return;
    final history = _provider!.history.toList();

    await widget.repository.updateHistory(_currentChat, history);

    if (history.length != 2) return;
    if (_currentChat.title != ChatRepository.newChatTitle) return;

    assert(history[0].origin.isUser);
    assert(history[1].origin.isLlm);
    // Use static calls for globals in tempProvider
    final globals = await ChatRepository.getGlobalSettings();
    final tempProvider = OpenAIProvider(
      apiKey: globals['apiKey'] as String? ?? '',
      baseUrl: globals['baseUrl'] as String? ?? 'https://api.openai.com/v1',
      model: _currentChat.model,
      temperature: _currentChat.temperature,
      topP: _currentChat.topP,
      maxTokens: _currentChat.maxTokens,
      initialHistory: history,
    );
    final stream = tempProvider.sendMessageStream(
      'Please give me a short title for this chat. It should be a single, '
      'short phrase with no markdown',
    );

    final title = await stream.join();
    if (title.trim().isEmpty) return;
    final chatWithNewTitle = Chat(
      id: _currentChat.id, 
      title: title.trim(),
      model: _currentChat.model,
      temperature: _currentChat.temperature,
      topP: _currentChat.topP,
      maxTokens: _currentChat.maxTokens,
    );
    await widget.repository.updateChat(chatWithNewTitle);
    if (mounted) {
      setState(() => _currentChat = chatWithNewTitle);
      widget.onTitleChanged?.call();
    }
  }
}