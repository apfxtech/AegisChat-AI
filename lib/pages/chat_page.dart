// lib/pages/chat_page.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
  StreamSubscription<QuerySnapshot>? _historySubscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _currentChat = widget.repository.chats.firstWhere(
      (chat) => chat.id == widget.chatId,
      orElse: () => throw StateError('Chat with ID ${widget.chatId} not found.'),
    );
    final history = await widget.repository.getHistory(_currentChat);

    final globals = await ChatRepository.getGlobalSettings();
    final apiKey = globals['apiKey'] as String? ?? '';
    final baseUrl = globals['baseUrl'] as String? ?? 'https://api.openai.com/v1';

    _setProvider(history, apiKey, baseUrl, _currentChat.model, _currentChat.temperature, _currentChat.topP, _currentChat.maxTokens);

    // Start real-time listener for history changes
    final historyCollection = FirebaseFirestore.instance
        .collection('users')
        .doc(ChatRepository.user!.uid)
        .collection('chats')
        .doc(widget.chatId)
        .collection('history');
    _historySubscription = historyCollection.snapshots().listen(_onHistorySnapshot);
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
    _provider = OpenAIProvider(
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      initialHistory: history ?? [],
    );
    if (mounted) {
      setState(() {});
    }
    _provider!.addListener(_onHistoryChanged);
  }

  // Handle real-time snapshot updates
  Future<void> _onHistorySnapshot(QuerySnapshot snapshot) async {
    debugPrint('History snapshot received with ${snapshot.docs.length} docs');
    final indexedMessages = <int, ChatMessage>{};
    for (final doc in snapshot.docs) {
      try {
        final data = doc.data() as Map<String, dynamic>;
        final index = int.tryParse(doc.id) ?? 0;
        final message = ChatMessage.fromJson(data);
        indexedMessages[index] = message;
        debugPrint('Processed message at index $index: ${message.text?.substring(0, 50) ?? ''}...');
      } catch (e) {
        debugPrint('Skipping invalid message doc ${doc.id}: $e');
      }
    }

    final newHistory = indexedMessages.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final sortedHistory = newHistory.map((e) => e.value).toList();

    // Update provider only if history has changed
    if (_provider != null && _isHistoryDifferent(sortedHistory, _provider!.history.toList())) {
      debugPrint('History changed, updating provider');
      final globals = await ChatRepository.getGlobalSettings();
      final apiKey = globals['apiKey'] as String? ?? '';
      final baseUrl = globals['baseUrl'] as String? ?? 'https://api.openai.com/v1';
      _setProvider(sortedHistory, apiKey, baseUrl, _currentChat.model, _currentChat.temperature, _currentChat.topP, _currentChat.maxTokens);
      widget.onTitleChanged?.call();
    } else {
      debugPrint('No history change detected');
    }
  }

  // Compare histories to detect changes efficiently
  bool _isHistoryDifferent(List<ChatMessage> newHistory, List<ChatMessage> oldHistory) {
    if (newHistory.length != oldHistory.length) return true;
    for (var i = 0; i < newHistory.length; i++) {
      final newMsg = newHistory[i];
      final oldMsg = oldHistory[i];
      if (newMsg.text != oldMsg.text || newMsg.origin != oldMsg.origin) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _provider?.removeListener(_onHistoryChanged);
    _historySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_provider == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final colorScheme = Theme.of(context).colorScheme;
    final submitButtonStyle = ActionButtonStyle(
      iconColor: colorScheme.onPrimary,
    );

    final attachFileButtonStyle = ActionButtonStyle(
      iconColor: colorScheme.onPrimary,
    );

    final chatStyle = LlmChatViewStyle(
      backgroundColor: colorScheme.surface,
      userMessageStyle: UserMessageStyle(
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: TextStyle(color: colorScheme.onPrimaryContainer),
      ),
      llmMessageStyle: LlmMessageStyle(
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        markdownStyle: MarkdownStyleSheet(
          p: TextStyle(color: colorScheme.onSecondaryContainer),
        ),
      ),
      chatInputStyle: ChatInputStyle(
        backgroundColor: colorScheme.surfaceContainer,
        textStyle: TextStyle(color: colorScheme.onSurface),
      ),
      submitButtonStyle: submitButtonStyle,
      attachFileButtonStyle: attachFileButtonStyle,
    );

    return ListenableBuilder(
      listenable: _provider!,
      builder: (context, child) => LlmChatView(
        provider: _provider!,
        style: chatStyle,
      ),
    );
  }

  Future<void> _onHistoryChanged() async {
    if (!mounted || _provider == null) return;
    final history = _provider!.history.toList();
    debugPrint('History changed, length: ${history.length}, last message: ${history.last.text?.substring(0, 50) ?? ''}...');

    await widget.repository.updateHistory(_currentChat, history);

    if (history.length != 2 || _currentChat.title != ChatRepository.newChatTitle) {
      return;
    }

    assert(history[0].origin.isUser);
    assert(history[1].origin.isLlm);

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
    try {
      final stream = tempProvider.sendMessageStream(
        'Please give me a short title for this chat based on the user message: "${history[0].text}". It should be a single short phrase, max 50 characters, no markdown.',
      );

      StringBuffer titleBuffer = StringBuffer();
      await for (var chunk in stream) {
        titleBuffer.write(chunk);
        debugPrint('Title stream chunk: $chunk');
      }
      final title = titleBuffer.toString().trim();
      debugPrint('Generated title: $title');

      final newTitle = title.isNotEmpty ? title : 'New Chat ${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}'; // Fallback with date
      if (newTitle == _currentChat.title) return;

      final chatWithNewTitle = _currentChat.copyWith(title: newTitle);
      await widget.repository.updateChat(chatWithNewTitle);

      if (mounted) {
        setState(() => _currentChat = chatWithNewTitle);
        widget.onTitleChanged?.call();
      }
    } catch (e) {
      debugPrint('Error generating chat title: $e');
      // Use fallback title
      final newTitle = 'New Chat ${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}';
      final chatWithNewTitle = _currentChat.copyWith(title: newTitle);
      await widget.repository.updateChat(chatWithNewTitle);
      if (mounted) {
        setState(() => _currentChat = chatWithNewTitle);
        widget.onTitleChanged?.call();
      }
    }
  }
}

extension ChatCopyWith on Chat {
  Chat copyWith({
    String? id,
    String? title,
    String? model,
    double? temperature,
    double? topP,
    double? maxTokens,
  }) {
    return Chat(
      id: id ?? this.id,
      title: title ?? this.title,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }
}