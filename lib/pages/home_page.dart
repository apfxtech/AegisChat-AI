// lib/pages/home_page.dart (added reload mechanism for ChatView after settings save)
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../data/chat.dart';
import '../data/chat_repository.dart';
import '../login_info.dart';
import 'chat_list_view.dart';
import 'chat_page.dart';
import 'settings_view.dart'; // Импортируем новый файл с настройками
import 'split_or_tabs.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

// Добавляем TickerProviderStateMixin для TabController
class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  ChatRepository? _repository;
  String? _currentChatId;
  TabController? _tabController;
  int _reloadKey = 0; // Key for reloading ChatView after settings change

  @override
  void initState() {
    super.initState();
    unawaited(_setRepository());
  }
  
  @override
  void dispose() {
    _tabController?.dispose(); // Не забываем освобождать ресурсы
    super.dispose();
  }

  Future<void> _setRepository() async {
    assert(_repository == null);
    _repository = await ChatRepository.forCurrentUser;
    // Принудительная синхронизация globals при запуске/перезапуске
    await ChatRepository.getGlobalSettings();
    if (_repository!.chats.isNotEmpty) {
      _currentChatId = _repository!.chats.last.id;
    }
    _initializeOrUpdateTabController(); // Инициализируем контроллер
    setState(() {});
  }
  
  void _initializeOrUpdateTabController({int? initialIndex}) {
    _tabController?.dispose();
    final tabCount = _currentChatId != null ? 2 : 1;
    _tabController = TabController(
      length: tabCount,
      vsync: this,
      initialIndex: initialIndex ?? 0,
    );
    // Добавляем слушателя, чтобы перерисовывать AppBar при смене вкладок
    _tabController!.addListener(() => setState(() {}));
  }


  Chat? _getCurrentChat() {
    if (_repository == null || _currentChatId == null) return null;
    return _repository!.chats.singleWhere((chat) => chat.id == _currentChatId!);
  }

  String _getCurrentTitle() {
    final chat = _getCurrentChat();
    return chat?.title ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final currentChat = _getCurrentChat();
    final currentTabIndex = _tabController?.index ?? 0;

    List<Widget> actions = [];

    // Кнопки для вкладки "Список чатов" (индекс 0)
    if (currentTabIndex == 0) {
      if (_repository != null) {
        actions.add(
          IconButton(
            onPressed: _onAdd,
            tooltip: 'Новый чат',
            icon: const Icon(Icons.add),
          ),
        );
      }
      actions.add(
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Выход: ${LoginInfo.instance.displayName!}',
          onPressed: () async => LoginInfo.instance.logout(),
        ),
      );
    } 
    // Кнопки для вкладки "Чата" (индекс 1)
    else if (currentTabIndex == 1 && currentChat != null) {
      actions.add(
        IconButton(
          onPressed: () => _onRenameChat(currentChat),
          tooltip: 'Переименовать чат',
          icon: const Icon(Icons.edit),
        ),
      );
      actions.add(
        IconButton(
          icon: const Icon(Icons.more_vert),
          tooltip: 'Настройки',
          onPressed: () => _showSettings(context),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter AI Chat'),
        actions: actions,
      ),
      body: _repository == null || _tabController == null
          ? const Center(child: CircularProgressIndicator())
          : SplitOrTabs(
              // Передаем контроллер в ваш виджет
              controller: _tabController,
              tabs: [
                const Tab(text: 'Чаты'),
                if (_currentChatId != null) Tab(text: _getCurrentTitle()),
              ],
              children: [
                ChatListView(
                  chats: _repository!.chats,
                  selectedChatId: _currentChatId ?? '',
                  onChatSelected: _onChatSelected,
                  onRenameChat: _onRenameChat,
                  onDeleteChat: _onDeleteChat,
                ),
                if (_currentChatId != null)
                  ChatView(
                    key: ValueKey('${_currentChatId!}_$_reloadKey'), // Reload key to recreate state after settings
                    chatId: _currentChatId!,
                    repository: _repository!,
                    onTitleChanged: () => setState(() {}),
                  ),
              ],
            ),
    );
  }

  void _showSettings(BuildContext context) async {
    final currentChat = _getCurrentChat();
    if (currentChat == null || _repository == null) return;

    // Load current settings (static call)
    final globalSettings = await ChatRepository.getGlobalSettings();
    final chatSettings = {
      'model': currentChat.model,
      'temperature': currentChat.temperature,
      'topP': currentChat.topP,
      'maxTokens': currentChat.maxTokens,
    };

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SettingsView(
        globalSettings: globalSettings,
        chatSettings: chatSettings,
        onSaveGlobal: (updatedGlobal) async {
          await ChatRepository.updateGlobalSettings(updatedGlobal, _repository!.userDoc); // Use public getter
          if (mounted) setState(() { _reloadKey++; }); // Reload ChatView to recreate provider with new globals
        },
        onSaveChat: (updatedChat) async {
          final updatedChatObj = Chat(
            id: currentChat.id,
            title: currentChat.title,
            model: updatedChat['model'] as String,
            temperature: updatedChat['temperature'] as double,
            topP: updatedChat['topP'] as double,
            maxTokens: updatedChat['maxTokens'] as double,
          );
          await _repository!.updateChat(updatedChatObj);
          if (mounted) setState(() { _reloadKey++; }); // Reload ChatView to recreate provider with new chat settings
        },
      ),
    );
  }

  Future<void> _onAdd() async {
    final chat = await _repository!.addChat();
    final defaultTitle = 'Новый чат';
    final updatedChat = Chat(id: chat.id, title: defaultTitle);
    await _repository!.updateChat(updatedChat);
    
    setState(() {
      _currentChatId = updatedChat.id;
      _reloadKey++; // Ensure new chat loads fresh
    });
    _initializeOrUpdateTabController(initialIndex: 1); // Обновляем контроллер и переходим на новую вкладку
  }

  void _onChatSelected(Chat chat) {
    setState(() {
      _currentChatId = chat.id;
      _reloadKey++; // Reload to apply settings for new chat
    });

    if (_tabController?.length != 2) {
      _initializeOrUpdateTabController(initialIndex: 1);
    } else {
      _tabController?.animateTo(1);
    }
  }

  Future<void> _onRenameChat(Chat chat) async {
    final controller = TextEditingController(text: chat.title);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Переименовать чат: ${chat.title}'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Новое название"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Переименовать'),
          ),
        ],
      ),
    );

    if (newTitle != null && newTitle.isNotEmpty) {
      final updatedChat = Chat(
        id: chat.id, 
        title: newTitle,
        model: chat.model,
        temperature: chat.temperature,
        topP: chat.topP,
        maxTokens: chat.maxTokens,
      );
      await _repository!.updateChat(updatedChat);
      setState(() { _reloadKey++; }); // Reload if needed
    }
  }

  Future<void> _onDeleteChat(Chat chat) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить чат: ${chat.title}'),
        content: const Text('Вы уверены, что хотите удалить этот чат?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (shouldDelete ?? false) {
      await _repository!.deleteChat(chat);
      final isDeletingCurrent = _currentChatId == chat.id;

      setState(() {
        if (isDeletingCurrent) {
          if (_repository!.chats.isNotEmpty) {
            _currentChatId = _repository!.chats.last.id;
          } else {
            _currentChatId = null;
          }
          _reloadKey++; // Reload for new current chat
        }
      });

      // Если удалили текущий чат, пересоздаем контроллер
      if (isDeletingCurrent) {
         _initializeOrUpdateTabController(initialIndex: 0);
      }
    }
  }
}