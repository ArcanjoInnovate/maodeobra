// lib/services/firebase_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/constants/firebase_paths.dart';

/// Service base para operações Firebase
/// Responsável por: conexão, referências, helpers atômicos
class FirebaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Singleton
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  // Getter público para acesso ao database
  FirebaseDatabase get database => _database;

  // ========================================
  // REFERÊNCIAS PRINCIPAIS
  // ========================================

  DatabaseReference get chatsRef => _database.ref(FirebasePaths.chats);
  
  DatabaseReference get messagesRef => _database.ref(FirebasePaths.chatMessages);
  
  DatabaseReference chatMetadataRef(String chatId) => 
    _database.ref('${FirebasePaths.chatPath(chatId)}/metadata');

  DatabaseReference chatRef(String chatId) => 
      _database.ref(FirebasePaths.chatPath(chatId));

  DatabaseReference chatMessagesRef(String chatId) => 
      _database.ref(FirebasePaths.chatMessagesPath(chatId));

  // ========================================
  // AUTENTICAÇÃO
  // ========================================

  String? get currentUserId => _auth.currentUser?.uid;

  bool get isAuthenticated => _auth.currentUser != null;

  // ========================================
  // OPERAÇÕES ATÔMICAS
  // ========================================

  /// Atualização atômica de múltiplos paths
  Future<void> updateMultiplePaths(Map<String, dynamic> updates) async {
    try {
      await _database.ref().update(updates);
    } catch (e) {
      throw Exception('Erro na atualização atômica: $e');
    }
  }

  /// Set com retry (útil para conexões instáveis)
  Future<void> setWithRetry(
    DatabaseReference ref,
    dynamic value, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;
    while (attempts < maxRetries) {
      try {
        await ref.set(value);
        return;
      } catch (e) {
        attempts++;
        if (attempts >= maxRetries) rethrow;
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
  }

  /// Push com ID customizado (para mensagens)
  Future<String> pushWithId(DatabaseReference ref, Map<String, dynamic> data) async {
    final newRef = ref.push();
    await newRef.set(data);
    return newRef.key!;
  }

  // ========================================
  // HELPERS DE EXISTÊNCIA
  // ========================================

  /// Verifica se um caminho existe
  Future<bool> exists(String path) async {
    try {
      final snapshot = await _database.ref(path).get();
      return snapshot.exists;
    } catch (e) {
      return false;
    }
  }

  /// Pega snapshot com fallback
  Future<DataSnapshot?> getSnapshot(String path) async {
    try {
      final snapshot = await _database.ref(path).get();
      return snapshot.exists ? snapshot : null;
    } catch (e) {
      return null;
    }
  }

  // ========================================
  // INICIALIZAÇÃO DE ESTRUTURAS VAZIAS
  // ========================================

  /// Cria estrutura de mensagens vazia se não existir
  /// REGRA FUNDAMENTAL: Chat nunca pode falhar por falta de mensagens
  Future<void> ensureChatMessagesStructure(String chatId) async {
    final messagesPath = FirebasePaths.chatMessagesPath(chatId);
    final exists = await this.exists(messagesPath);
    
    if (!exists) {
      // Cria estrutura vazia (placeholder removível)
      await _database.ref(messagesPath).set({
        '_placeholder': {
          'created_at': ServerValue.timestamp,
          'note': 'Este chat ainda não tem mensagens'
        }
      });
    }
  }

  /// Remove placeholder quando primeira mensagem for enviada
  Future<void> removePlaceholderIfExists(String chatId) async {
    final placeholderPath = '${FirebasePaths.chatMessagesPath(chatId)}/_placeholder';
    await _database.ref(placeholderPath).remove();
  }

  // ========================================
  // TRANSAÇÕES (para contadores, etc)
  // ========================================

  Future<T?> runTransaction<T>(
    DatabaseReference ref,
    T? Function(dynamic) transactionUpdate,
  ) async {
    try {
      final result = await ref.runTransaction((currentValue) {
        return Transaction.success(transactionUpdate(currentValue));
      });
      return result.snapshot.value as T?;
    } catch (e) {
      print('Erro na transação: $e');
      return null;
    }
  }

  // ========================================
  // CLEANUP & DISCONNECT HANDLERS
  // ========================================

  /// Configura ações ao desconectar (crítico para status online)
  void setOnDisconnect(String path, dynamic value) {
    _database.ref(path).onDisconnect().set(value);
  }

  /// Cancela onDisconnect (quando usuário volta)
  Future<void> cancelOnDisconnect(String path) async {
    await _database.ref(path).onDisconnect().cancel();
  }

  // ========================================
  // TIMESTAMP SERVER-SIDE
  // ========================================

  dynamic get serverTimestamp => ServerValue.timestamp;

  // ========================================
  // CONEXÃO
  // ========================================

  Stream<bool> get connectionState {
    return _database.ref('.info/connected').onValue.map((event) {
      return event.snapshot.value as bool? ?? false;
    });
  }

  // ========================================
  // LIMPEZA
  // ========================================

  void dispose() {
    // Limpar listeners se necessário
  }
}
