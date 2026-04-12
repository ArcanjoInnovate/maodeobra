// lib/controllers/chat_controller.dart - VERSÃO HÍBRIDA COM TIMER

import 'package:dartobra_new/services/chat/chat_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:async';
import '../models/chat/chat_model.dart';
import '../models/chat/message_model.dart';
import '../models/chat/participant_model.dart';
import '../services/chat/firebase_service.dart';

class ChatControllerFinal extends ChangeNotifier {
  final ChatServiceFinal _chatService = ChatServiceFinal();
  final FirebaseService _firebase = FirebaseService();

  Chat? _currentChat;
  List<Message> _messages = [];
  ParticipantData? _otherParticipantStatus;
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isSending = false;
  String? _error;

  bool _hasMoreMessages = true;
  bool _isLoadingMore = false;

  StreamSubscription? _messagesSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _unreadCountSubscription;
  
  // ✅ HÍBRIDO: Timer periódico para mark as read contínuo
  Timer? _markReadTimer;

  String? _chatId;
  String? _userRole;
  String? _userId;

  // ========================================
  // GETTERS
  // ========================================

  Chat? get currentChat => _currentChat;
  List<Message> get messages => _messages;
  ParticipantData? get otherParticipantStatus => _otherParticipantStatus;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isSending => _isSending;
  String? get error => _error;
  bool get hasMoreMessages => _hasMoreMessages;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasChat => _currentChat != null;

  bool isSentByMe(Message message) => message.sender == _userRole;

  // ========================================
  // INICIALIZAÇÃO
  // ========================================

  Future<void> initializeChat({
    required String chatId,
    required String contractorId,
    required String employeeId,
    required String userRole,
  }) async {
    _chatId = chatId;
    _userRole = userRole;
    _userId = _firebase.currentUserId;

    _setLoading(true);
    _clearError();

    try {
      _currentChat = await _chatService.initializeChat(
        chatId,
        contractorId,
        employeeId,
        userRole,
      );

      await _chatService.setUserOnline(chatId, userRole);

      _setupMessageListener();
      _setupStatusListener();
      _setupUnreadCountListener();

      // ✅ HÍBRIDO: Mark as read imediato
      await _chatService.markAsRead(chatId, userRole);
      
      // ✅ HÍBRIDO: Inicia timer para mark as read contínuo (da solução sugerida)
      _startContinuousMarkRead(chatId, userRole);

      _setLoading(false);
    } catch (e) {
      _setError('Erro ao inicializar chat: $e');
      _setLoading(false);
    }
  }

  // ✅ HÍBRIDO: Timer periódico para garantir marcação contínua
  void _startContinuousMarkRead(String chatId, String userRole) {
    _markReadTimer?.cancel();
    _markReadTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_chatId != null && _userRole != null) {
        _chatService.markAsRead(chatId, userRole);
      }
    });
  }

  // ========================================
  // LISTENERS
  // ========================================

  void _setupMessageListener() {
    _messagesSubscription?.cancel();

    _messagesSubscription = _chatService
        .getMessagesStream(_chatId!)
        .listen(
          (newMessages) {
            _messages = newMessages;
            notifyListeners();
          },
          onError: (error) => _setError('Erro ao carregar mensagens: $error'),
        );
  }

  void _setupStatusListener() {
    _statusSubscription?.cancel();

    _statusSubscription = _chatService
        .getOtherParticipantStatus(_chatId!, _userRole!)
        .listen(
          (status) {
            _otherParticipantStatus = status;
            notifyListeners();
          },
          onError: (error) => print('Erro ao monitorar status: $error'),
        );
  }

  void _setupUnreadCountListener() {
    _unreadCountSubscription?.cancel();

    _unreadCountSubscription = _chatService
        .getUnreadCountStream(_chatId!, _userRole!)
        .listen(
          (count) {
            _unreadCount = count;
            notifyListeners();
          },
          onError: (error) => print('Erro ao monitorar unreadCount: $error'),
        );
  }

  // ========================================
  // ENVIO DE MENSAGEM
  // ========================================

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || _chatId == null || _userRole == null) return;

    _isSending = true;
    notifyListeners();

    try {
      await _chatService.sendMessage(_chatId!, text.trim(), _userRole!);
      _isSending = false;
      notifyListeners();
    } catch (e) {
      _setError('Erro ao enviar mensagem: $e');
      _isSending = false;
      notifyListeners();
    }
  }

  // ========================================
  // PAGINAÇÃO
  // ========================================

  Future<void> loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final oldestTimestamp = _messages.first.timestamp;
      final olderMessages = await _chatService.loadOlderMessages(
        _chatId!,
        oldestTimestamp: oldestTimestamp,
        limit: 20,
      );

      if (olderMessages.isEmpty) {
        _hasMoreMessages = false;
      } else {
        final existingIds = _messages.map((m) => m.id).toSet();
        final newMessages =
            olderMessages.where((m) => !existingIds.contains(m.id)).toList();
        _messages.insertAll(0, newMessages);
      }

      _isLoadingMore = false;
      notifyListeners();
    } catch (e) {
      _setError('Erro ao carregar mensagens antigas: $e');
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ========================================
  // MARK AS READ
  // ========================================

  Future<void> markAsRead() async {
    if (_chatId == null || _userRole == null) return;
    await _chatService.markAsRead(_chatId!, _userRole!);
  }

  // ========================================
  // ESTADO INTERNO
  // ========================================

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
    notifyListeners();
  }

  // ========================================
  // LIFECYCLE
  // ========================================

  Future<void> leaveChat() async {
    // ✅ HÍBRIDO: Cancela o timer antes de sair
    _markReadTimer?.cancel();
    
    if (_chatId != null && _userRole != null) {
      await _chatService.setUserOffline(_chatId!, _userRole!);
    }

    _messagesSubscription?.cancel();
    _statusSubscription?.cancel();
    _unreadCountSubscription?.cancel();

    _chatService.disposeChat();

    if (_chatId != null) {
      _chatService.clearChatCache(_chatId!);
    }
  }

  @override
  void dispose() {
    // ✅ HÍBRIDO: Garante cancelamento do timer
    _markReadTimer?.cancel();
    leaveChat();
    super.dispose();
  }

  // ========================================
  // AUXILIARES
  // ========================================

  void reset() {
    _markReadTimer?.cancel();
    
    _currentChat = null;
    _messages.clear();
    _otherParticipantStatus = null;
    _unreadCount = 0;
    _isLoading = false;
    _isSending = false;
    _error = null;
    _hasMoreMessages = true;
    _isLoadingMore = false;

    _messagesSubscription?.cancel();
    _statusSubscription?.cancel();
    _unreadCountSubscription?.cancel();

    _chatId = null;
    _userRole = null;
    _userId = null;

    notifyListeners();
  }

  Message? getMessageById(String messageId) {
    try {
      return _messages.firstWhere((m) => m.id == messageId);
    } catch (e) {
      return null;
    }
  }

  Message? get lastMessage => _messages.isEmpty ? null : _messages.last;
  Message? get firstMessage => _messages.isEmpty ? null : _messages.first;
}