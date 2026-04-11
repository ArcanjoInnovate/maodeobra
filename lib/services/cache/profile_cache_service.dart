import 'package:firebase_database/firebase_database.dart';

/// Serviço de cache para validações do Firebase
/// Reduz leituras desnecessárias do banco de dados
class ValidationCache {
  // Cache de emails verificados
  static final Map<String, _CacheEntry<bool>> _emailCache = {};
  
  // Cache de telefones verificados  
  static final Map<String, _CacheEntry<bool>> _phoneCache = {};
  
  // Duração do cache: 5 minutos
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  /// Verifica se um email já existe no Firebase (com cache)
  /// 
  /// Reduz de 2 leituras para 1 na primeira vez
  /// Reduz para 0 leituras em tentativas subsequentes (dentro de 5 min)
  static Future<bool> checkEmailExists({
    required String email,
    required String currentUserId,
    required DatabaseReference database,
  }) async {
    // Verificar cache primeiro
    if (_emailCache.containsKey(email)) {
      final entry = _emailCache[email]!;
      if (DateTime.now().difference(entry.timestamp) < _cacheDuration) {
        print('✅ Cache HIT para email: $email');
        return entry.value;
      } else {
        print('⏰ Cache EXPIRADO para email: $email');
        _emailCache.remove(email);
      }
    }
    
    print('❌ Cache MISS para email: $email - Consultando Firebase...');
    
    try {
      // Verificar em email_contact (otimizado com limitToFirst)
      final emailContactSnapshot = await database
          .child('Users')
          .orderByChild('email_contact')
          .equalTo(email)
          .limitToFirst(1) // ✅ OTIMIZAÇÃO: Limita resultado
          .once();
      
      if (emailContactSnapshot.snapshot.value != null) {
        final data = emailContactSnapshot.snapshot.value as Map;
        // Se encontrou e não é o próprio usuário
        if (!data.containsKey(currentUserId)) {
          _emailCache[email] = _CacheEntry(true, DateTime.now());
          return true;
        }
      }
      
      // Verificar em email (otimizado com limitToFirst)
      final emailSnapshot = await database
          .child('Users')
          .orderByChild('email')
          .equalTo(email)
          .limitToFirst(1) // ✅ OTIMIZAÇÃO: Limita resultado
          .once();
      
      if (emailSnapshot.snapshot.value != null) {
        final data = emailSnapshot.snapshot.value as Map;
        if (!data.containsKey(currentUserId)) {
          _emailCache[email] = _CacheEntry(true, DateTime.now());
          return true;
        }
      }
      
      // Email disponível
      _emailCache[email] = _CacheEntry(false, DateTime.now());
      return false;
      
    } catch (e) {
      print('❌ Erro ao verificar email: $e');
      // Em caso de erro, não cachear e retornar false
      return false;
    }
  }
  
  /// Verifica se um telefone já existe no Firebase (com cache)
  /// 
  /// Reduz para 0 leituras em tentativas subsequentes (dentro de 5 min)
  static Future<bool> checkPhoneExists({
    required String phone,
    required String currentUserId,
    required DatabaseReference database,
  }) async {
    // Limpar apenas números
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Verificar cache primeiro
    if (_phoneCache.containsKey(cleanPhone)) {
      final entry = _phoneCache[cleanPhone]!;
      if (DateTime.now().difference(entry.timestamp) < _cacheDuration) {
        print('✅ Cache HIT para telefone: $cleanPhone');
        return entry.value;
      } else {
        print('⏰ Cache EXPIRADO para telefone: $cleanPhone');
        _phoneCache.remove(cleanPhone);
      }
    }
    
    print('❌ Cache MISS para telefone: $cleanPhone - Consultando Firebase...');
    
    try {
      // Consulta otimizada com limitToFirst
      final snapshot = await database
          .child('Users')
          .orderByChild('telefone')
          .equalTo(cleanPhone)
          .limitToFirst(1) // ✅ OTIMIZAÇÃO: Limita resultado
          .once();
      
      if (snapshot.snapshot.value != null) {
        Map<dynamic, dynamic> users = snapshot.snapshot.value as Map<dynamic, dynamic>;
        
        // Se encontrou apenas um usuário e é o próprio, pode usar
        if (users.length == 1 && users.keys.first == currentUserId) {
          _phoneCache[cleanPhone] = _CacheEntry(false, DateTime.now());
          return false;
        }
        
        // Telefone já está em uso por outro usuário
        _phoneCache[cleanPhone] = _CacheEntry(true, DateTime.now());
        return true;
      }
      
      // Telefone disponível
      _phoneCache[cleanPhone] = _CacheEntry(false, DateTime.now());
      return false;
      
    } catch (e) {
      print('❌ Erro ao verificar telefone: $e');
      return false;
    }
  }
  
  /// Limpa todo o cache
  /// Use quando usuário fizer logout ou após tempo prolongado
  static void clearAll() {
    _emailCache.clear();
    _phoneCache.clear();
    print('🧹 Cache limpo completamente');
  }
  
  /// Limpa apenas o cache de emails
  static void clearEmailCache() {
    _emailCache.clear();
    print('🧹 Cache de emails limpo');
  }
  
  /// Limpa apenas o cache de telefones
  static void clearPhoneCache() {
    _phoneCache.clear();
    print('🧹 Cache de telefones limpo');
  }
  
  /// Remove um email específico do cache
  /// Use quando um email for alterado com sucesso
  static void invalidateEmail(String email) {
    _emailCache.remove(email);
    print('🔄 Cache invalidado para email: $email');
  }
  
  /// Remove um telefone específico do cache
  /// Use quando um telefone for alterado com sucesso
  static void invalidatePhone(String phone) {
    String cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    _phoneCache.remove(cleanPhone);
    print('🔄 Cache invalidado para telefone: $cleanPhone');
  }
  
  /// Retorna estatísticas do cache (útil para debugging)
  static Map<String, dynamic> getStats() {
    int validEmails = _emailCache.values
        .where((e) => DateTime.now().difference(e.timestamp) < _cacheDuration)
        .length;
    
    int validPhones = _phoneCache.values
        .where((e) => DateTime.now().difference(e.timestamp) < _cacheDuration)
        .length;
    
    return {
      'total_emails_cached': _emailCache.length,
      'valid_emails_cached': validEmails,
      'total_phones_cached': _phoneCache.length,
      'valid_phones_cached': validPhones,
      'cache_duration_minutes': _cacheDuration.inMinutes,
    };
  }
}

/// Classe interna para armazenar valores cacheados com timestamp
class _CacheEntry<T> {
  final T value;
  final DateTime timestamp;
  
  _CacheEntry(this.value, this.timestamp);
}