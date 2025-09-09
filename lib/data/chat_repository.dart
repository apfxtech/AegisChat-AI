// lib/data/chat_repository.dart (fixed updateHistory to always set messages, ensuring assistant text updates during streaming and persists in DB)
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartx/dartx.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ai_toolkit/flutter_ai_toolkit.dart';
import 'package:uuid/uuid.dart';

import 'chat.dart';

class ChatRepository extends ChangeNotifier {
  ChatRepository._({
    required CollectionReference collection,
    required DocumentReference userDoc,
    List<Chat> chats = const [], // Initial empty; listener will populate
  })  : _chatsCollection = collection,
        _userDoc = userDoc,
        _chats = chats;

  static const newChatTitle = 'Untitled';
  static User? _currentUser;
  static ChatRepository? _currentUserRepository;
  static Map<String, dynamic>? _globalSettings; // Cache for globals

  static bool get hasCurrentUser => _currentUser != null;
  static Future<ChatRepository> get forCurrentUser async {
    // no user, no repository
    if (_currentUser == null) throw Exception('No user logged in');

    // load the repository for the current user if it's not already loaded
    if (_currentUserRepository == null) {
      assert(_currentUser != null);
      final userDoc = FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid);
      final collection = userDoc.collection('chats');

      // Start listeners for real-time sync
      final repo = ChatRepository._(
        collection: collection,
        userDoc: userDoc,
        chats: [], // Start empty; listeners will load
      );
      repo._startChatListeners();
      repo._startGlobalListeners();

      _currentUserRepository = repo;

      // if there are no chats after initial load, add a new one (listener will handle, but check after delay if needed)
      // For now, let UI handle empty state
    }

    return _currentUserRepository!;
  }

  // Start real-time listener for chats collection
  void _startChatListeners() {
    _chatsSubscription ??= _chatsCollection.snapshots().listen((snapshot) {
      try {
        final chats = <Chat>[];
        for (final doc in snapshot.docs) {
          chats.add(Chat.fromJson(doc.data()! as Map<String, dynamic>));
        }
        _chats = chats;
        notifyListeners(); // Trigger UI update
      } catch (e) {
        debugPrint('Error in chat listener: $e');
      }
    }, onError: (error) {
      debugPrint('Chat listener error: $error');
    });
  }

  // Start real-time listener for global settings (user doc)
  void _startGlobalListeners() {
    _globalsSubscription ??= _userDoc.snapshots().listen((doc) {
      try {
        if (doc.exists) {
          final data = doc.data() as Map<String, dynamic>? ?? {};
          _globalSettings = {
            'baseUrl': data['baseUrl'] ?? 'https://api.openai.com/v1',
            'apiKey': data['apiKey'] ?? '',
            'lastModel': data['lastModel'] ?? 'gpt-4o', // New field
          };
          notifyListeners(); // If UI depends on globals
          debugPrint('Global settings updated via listener: lastModel=${_globalSettings!['lastModel']}');
        }
      } catch (e) {
        debugPrint('Error in global listener: $e');
      }
    }, onError: (error) {
      debugPrint('Global listener error: $error');
    });
  }

  static Future<void> _loadGlobalSettings(DocumentReference userDoc) async {
    if (_globalSettings != null) return;
    try {
      final doc = await userDoc.get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        _globalSettings = {
          'baseUrl': data['baseUrl'] ?? 'https://api.openai.com/v1',
          'apiKey': data['apiKey'] ?? '',
          'lastModel': data['lastModel'] ?? 'gpt-4o', // New field
        };
        debugPrint('Loaded global settings from users/${_currentUser!.uid}: apiKey=${_globalSettings!['apiKey'].toString().substring(0, 10)}..., baseUrl=${_globalSettings!['baseUrl']}, lastModel=${_globalSettings!['lastModel']}');
      } else {
        // Create user doc with defaults if not exists
        _globalSettings = {
          'baseUrl': 'https://api.openai.com/v1',
          'apiKey': '',
          'lastModel': 'gpt-4o', // Default
        };
        await updateGlobalSettings(_globalSettings!, userDoc);
      }
    } catch (e) {
      debugPrint('Error loading global settings: $e');
      _globalSettings = {'baseUrl': 'https://api.openai.com/v1', 'apiKey': '', 'lastModel': 'gpt-4o'};
    }
  }

  static Future<Map<String, dynamic>> getGlobalSettings() async {
    await forCurrentUser; // Ensure loaded
    // Force reload if cache empty (for sync)
    if (_globalSettings == null || _globalSettings!.isEmpty) {
      await _loadGlobalSettings(_currentUserRepository!._userDoc);
    }
    return Map<String, dynamic>.from(_globalSettings ?? {'baseUrl': 'https://api.openai.com/v1', 'apiKey': '', 'lastModel': 'gpt-4o'});
  }

  static Future<void> updateGlobalSettings(Map<String, dynamic> settings, [DocumentReference? userDoc]) async {
    try {
      await forCurrentUser; // Ensure user
      final docRef = userDoc ?? _currentUserRepository!._userDoc;
      await docRef.set({
        'baseUrl': settings['baseUrl'],
        'apiKey': settings['apiKey'],
        'lastModel': settings['lastModel'], // Include lastModel
      }, SetOptions(merge: true)); // Merge to not overwrite other fields
      _globalSettings = settings;
      debugPrint('Global settings saved to users/${_currentUser!.uid}: apiKey=${settings['apiKey'].toString().substring(0, 10)}..., baseUrl=${settings['baseUrl']}, lastModel=${settings['lastModel']}');
      _currentUserRepository?.notifyListeners(); // Refresh if repo exists
    } catch (e) {
      debugPrint('Error saving global settings: $e');
    }
  }

  static User? get user => _currentUser;

  static set user(User? user) {
    // Cancel listeners and clear cache on logout or user change
    if (user == null) {
      _currentUserRepository?._chatsSubscription?.cancel();
      _currentUserRepository?._globalsSubscription?.cancel();
      _currentUser = null;
      _currentUserRepository = null;
      _globalSettings = null;
      return;
    }

    // Ignore if same user
    if (user.uid == _currentUser?.uid) return;

    // Cancel old listeners
    _currentUserRepository?._chatsSubscription?.cancel();
    _currentUserRepository?._globalsSubscription?.cancel();

    // Clear cache for new user
    _currentUser = user;
    _currentUserRepository = null;
    _globalSettings = null; // Will reload with listeners
  }

  final CollectionReference _chatsCollection;
  final DocumentReference _userDoc;
  List<Chat> _chats;

  // Public getter for userDoc
  DocumentReference get userDoc => _userDoc;

  // Subscriptions for listeners
  StreamSubscription<QuerySnapshot>? _chatsSubscription;
  StreamSubscription<DocumentSnapshot>? _globalsSubscription;

  // Public dispose for cleanup if needed (e.g., in HomePage dispose)
  void dispose() {
    _chatsSubscription?.cancel();
    _globalsSubscription?.cancel();
    super.dispose();
  }

  CollectionReference _historyCollection(Chat chat) =>
      _chatsCollection.doc(chat.id).collection('history');

  List<Chat> get chats => _chats;

  Future<Chat> addChat() async {
    final globals = await getGlobalSettings();
    final lastModel = globals['lastModel'] as String? ?? 'gpt-4o'; // Use lastModel
    final chat = Chat(
      id: const Uuid().v4(),
      title: newChatTitle,
      model: lastModel, // Default to last used model
      // Other defaults from constructor
    );

    // Add to DB; listener will update _chats and notify
    await _chatsCollection.doc(chat.id).set(chat.toJson());
    notifyListeners(); // Immediate notify in case listener lags

    return chat;
  }

  Future<void> updateChat(Chat chat) async {
    // Update DB; listener will handle _chats update
    await _chatsCollection.doc(chat.id).update(chat.toJson());
    notifyListeners(); // Immediate notify
  }

  Future<void> deleteChat(Chat chat) async {
    // Delete history
    final querySnapshot = await _historyCollection(chat).get();
    for (final doc in querySnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete chat; listener will remove from _chats
    await _chatsCollection.doc(chat.id).delete();
    notifyListeners(); // Immediate notify

    // if we've deleted the last chat, add a new one (listener will reflect)
    if (_chats.isEmpty) await addChat();
  }

  Future<List<ChatMessage>> getHistory(Chat chat) async {
    final querySnapshot = await _historyCollection(chat).get();

    final indexedMessages = <int, ChatMessage>{};
    for (final doc in querySnapshot.docs) {
      final index = int.parse(doc.id);
      final message = ChatMessage.fromJson(doc.data()! as Map<String, dynamic>);
      indexedMessages[index] = message;
    }

    final messages = indexedMessages.entries
        .sortedBy((e) => e.key)
        .map((e) => e.value)
        .toList();
    return messages;
  }

  Future<void> updateHistory(Chat chat, List<ChatMessage> history) async {
    for (var i = 0; i != history.length; ++i) {
      final id = i.toString().padLeft(3, '0');
      final message = history[i];
      final json = message.toJson();
      // Always set to update text for existing messages (e.g., streaming assistant responses)
      await _historyCollection(chat).doc(id).set(json);
    }
  }
}