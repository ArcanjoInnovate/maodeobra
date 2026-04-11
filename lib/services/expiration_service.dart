// lib/services/expiration_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

/// Serviço responsável por gerenciar a expiração de vagas e perfis profissionais
/// Período de expiração: 7 dias
class ExpirationService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  
  static const int _expirationDays = 2;
  static const int _millisecondsInDay = 86400000; // 24h * 60m * 60s * 1000ms
  
  static final ExpirationService _instance = ExpirationService._internal();
  factory ExpirationService() => _instance;
  ExpirationService._internal();
  DateTime getCurrentNow() {
  return _now;
}

  // ════════════════════════════════════════════════
  // CÁLCULO DE EXPIRAÇÃO
  // ════════════════════════════════════════════════

  // 🧪 TESTE: Quando não for null, todas as verificações usarão esta data
  static DateTime? testDate;

  // Método auxiliar para pegar a data atual (ou de teste)
  // ✅ TODOS os métodos devem usar _now em vez de DateTime.now()
  DateTime get _now => testDate ?? DateTime.now();

  // Retorna a data de expiração (2 dias a partir de agora, no final do dia)
  /// ✅ CORRIGIDO: expira no final do dia para garantir dias completos
  DateTime getExpirationDate() {
    final expirationDay = _now.add(Duration(days: _expirationDays));
    return DateTime(
      expirationDay.year,
      expirationDay.month,
      expirationDay.day,
      23, 59, 59, 999
    );
  }

  /// Retorna a data de expiração em formato ISO 8601
  String getExpirationDateISO() {
    return getExpirationDate().toIso8601String();
  }

  /// Retorna a data de expiração em milissegundos desde epoch
  int getExpirationTimestamp() {
    return getExpirationDate().millisecondsSinceEpoch;
  }

  /// Verifica se uma data/timestamp expirou
  /// ✅ CORRIGIDO: usa _now em vez de DateTime.now()
  /// Verifica se uma data/timestamp expirou
  bool isExpired(dynamic expirationDate) {
    if (expirationDate == null) return false;

    final DateTime expiration;
    
    if (expirationDate is int) {
      expiration = DateTime.fromMillisecondsSinceEpoch(expirationDate);
    } else if (expirationDate is String) {
      expiration = DateTime.tryParse(expirationDate) ?? _now;
    } else {
      return false;
    }

    return _now.isAfter(expiration);
  }

  /// Calcula quantos dias faltam para expirar
  /// ✅ CORRIGIDO: usa _now em vez de DateTime.now()
  /// ✅ CORRIGIDO: arredonda corretamente usando ceil()
  int daysUntilExpiration(dynamic expirationDate) {
    if (expirationDate == null) return 0;

    final DateTime expiration;
    
    if (expirationDate is int) {
      expiration = DateTime.fromMillisecondsSinceEpoch(expirationDate);
    } else if (expirationDate is String) {
      expiration = DateTime.tryParse(expirationDate) ?? _now;
    } else {
      return 0;
    }

    final difference = expiration.difference(_now);
    
    // Se ainda falta tempo (positivo), arredonda para cima
    // Exemplo: 1 dia e 23 horas = 2 dias
    if (difference.inHours > 0) {
      return (difference.inHours / 24).ceil();
    }
    
    // Se já passou ou é exatamente 0
    return 0;
  }

  /// ✅ CORRIGIDO: Verifica se está próximo da expiração (apenas 1 dia restante)
  /// Isso evita que o alerta apareça logo após renovar (quando ainda há 2 dias)
  bool isNearExpiration(dynamic expirationDate) {
    final daysLeft = daysUntilExpiration(expirationDate);
    return daysLeft > 0 && daysLeft <= 1;
  }

  /// Formata a mensagem de expiração para o usuário
  String getExpirationMessage(dynamic expirationDate) {
    final daysLeft = daysUntilExpiration(expirationDate);
    
    if (daysLeft <= 0) {
      return 'Expirado';
    } else if (daysLeft == 1) {
      return 'Expira amanhã';
    } else {
      return 'Expira em $daysLeft dias';
    }
  }

  // ════════════════════════════════════════════════
  // RENOVAÇÃO
  // ════════════════════════════════════════════════

  /// Renova a expiração (adiciona mais 2 dias a partir de _now)
  /// ✅ CORRIGIDO: usa _now em vez de DateTime.now()
  /// ✅ CORRIGIDO: expira no final do dia (23:59:59) para evitar truncamento
  DateTime renewExpiration() {
    // Adiciona 2 dias e define para o final do dia
    final expirationDay = _now.add(const Duration(days: _expirationDays));
    return DateTime(
      expirationDay.year,
      expirationDay.month,
      expirationDay.day,
      23, 59, 59, 999
    );
  }

  /// Renova a expiração em formato ISO 8601
  String renewExpirationISO() {
    return renewExpiration().toIso8601String();
  }

  /// Renova a expiração em timestamp
  int renewExpirationTimestamp() {
    return renewExpiration().millisecondsSinceEpoch;
  }

  // ════════════════════════════════════════════════
  // VAGAS - EXPIRAÇÃO
  // ════════════════════════════════════════════════

  /// Verifica e expira vagas automaticamente
  Future<List<String>> checkAndExpireVacancies() async {
    try {
      print('🕐 Verificando vagas expiradas...');
      
      final snapshot = await _database.child('vacancy').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        print('ℹ️ Nenhuma vaga encontrada');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<String> expiredVacancies = [];

      for (final entry in data.entries) {
        final vacancyId = entry.key.toString();
        final vacancyData = Map<String, dynamic>.from(entry.value as Map);
        
        final expiresAt = vacancyData['expires_at'];
        final status = vacancyData['status']?.toString().toLowerCase() ?? '';
        
        // Só verifica vagas abertas
        if (status == 'aberta' && expiresAt != null) {
          if (isExpired(expiresAt)) {
            // ✅ CORRIGIDO: usa _now.toIso8601String() em vez de DateTime.now()
            await _database.child('vacancy/$vacancyId').update({
              'status': 'Expirada',
              'expired_at': _now.toIso8601String(),
              'updated_at': _now.toIso8601String(),
            });
            
            expiredVacancies.add(vacancyId);
            print('⏰ Vaga $vacancyId expirada');
          }
        }
      }

      print('✅ Verificação concluída: ${expiredVacancies.length} vagas expiradas');
      return expiredVacancies;
    } catch (e) {
      print('❌ Erro ao verificar vagas expiradas: $e');
      return [];
    }
  }

  /// Renova uma vaga específica
  Future<bool> renewVacancy(String vacancyId) async {
    try {
      final newExpirationDate = renewExpirationISO();
      final newExpirationTimestamp = renewExpirationTimestamp();
      
      await _database.child('vacancy/$vacancyId').update({
        'expires_at': newExpirationDate,
        'expiration_timestamp': newExpirationTimestamp,
        'renewed_at': _now.toIso8601String(),
        'updated_at': _now.toIso8601String(),
        'status': 'Aberta', // Reativa se estava expirada
      });

      print('✅ Vaga $vacancyId renovada até $newExpirationDate');
      return true;
    } catch (e) {
      print('❌ Erro ao renovar vaga: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // PERFIS PROFISSIONAIS - EXPIRAÇÃO
  // ════════════════════════════════════════════════

  /// Verifica e expira perfis profissionais automaticamente
  Future<List<String>> checkAndExpireProfessionals() async {
    try {
      print('🕐 Verificando perfis profissionais expirados...');
      
      final snapshot = await _database.child('professionals').get();
      
      if (!snapshot.exists || snapshot.value == null) {
        print('ℹ️ Nenhum perfil profissional encontrado');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<String> expiredProfessionals = [];

      for (final entry in data.entries) {
        final professionalId = entry.key.toString();
        final professionalData = Map<String, dynamic>.from(entry.value as Map);
        
        final expiresAt = professionalData['expires_at'];
        final status = professionalData['status']?.toString().toLowerCase() ?? '';
        
        // Só verifica perfis ativos
        if (status == 'active' && expiresAt != null) {
          if (isExpired(expiresAt)) {
            // ✅ CORRIGIDO: usa _now.toIso8601String()
            await _database.child('professionals/$professionalId').update({
              'status': 'expired',
              'expired_at': _now.toIso8601String(),
              'updated_at': _now.toIso8601String(),
            });
            
            // Atualiza o status do usuário
            final localId = professionalData['local_id'];
            if (localId != null) {
              await _database.child('Users/$localId/isActive').set(false);
            }
            
            expiredProfessionals.add(professionalId);
            print('⏰ Perfil profissional $professionalId expirado');
          }
        }
      }

      print('✅ Verificação concluída: ${expiredProfessionals.length} perfis expirados');
      return expiredProfessionals;
    } catch (e) {
      print('❌ Erro ao verificar perfis expirados: $e');
      return [];
    }
  }

  /// Renova um perfil profissional específico
  Future<bool> renewProfessional(String professionalId) async {
    try {
      final newExpirationDate = renewExpirationISO();
      final newExpirationTimestamp = renewExpirationTimestamp();
      
      await _database.child('professionals/$professionalId').update({
        'expires_at': newExpirationDate,
        'expiration_timestamp': newExpirationTimestamp,
        'renewed_at': _now.toIso8601String(),
        'updated_at': _now.toIso8601String(),
        'status': 'active', // Reativa se estava expirado
      });

      print('✅ Perfil profissional $professionalId renovado até $newExpirationDate');
      return true;
    } catch (e) {
      print('❌ Erro ao renovar perfil profissional: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // VERIFICAÇÃO PERIÓDICA
  // ════════════════════════════════════════════════

  /// Inicia verificação periódica automática (executa a cada 6 horas)
  Timer startPeriodicCheck() {
    print('🔄 Iniciando verificação periódica de expiração...');
    
    // Executa imediatamente
    _runPeriodicCheck();
    
    // Depois executa a cada 6 horas
    return Timer.periodic(const Duration(hours: 6), (_) {
      _runPeriodicCheck();
    });
  }

  Future<void> _runPeriodicCheck() async {
    print('🔍 Executando verificação periódica...');
    await checkAndExpireVacancies();
    await checkAndExpireProfessionals();
  }

  // ════════════════════════════════════════════════
  // UTILITÁRIOS
  // ════════════════════════════════════════════════

  /// Retorna informações sobre uma vaga
  Future<Map<String, dynamic>?> getVacancyExpirationInfo(String vacancyId) async {
    try {
      final snapshot = await _database.child('vacancy/$vacancyId').get();
      
      if (!snapshot.exists || snapshot.value == null) return null;
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final expiresAt = data['expires_at'];
      
      return {
        'expires_at': expiresAt,
        'is_expired': isExpired(expiresAt),
        'days_until_expiration': daysUntilExpiration(expiresAt),
        'is_near_expiration': isNearExpiration(expiresAt),
        'expiration_message': getExpirationMessage(expiresAt),
        'status': data['status'],
      };
    } catch (e) {
      print('❌ Erro ao obter info de expiração: $e');
      return null;
    }
  }

  /// Retorna informações sobre um perfil profissional
  Future<Map<String, dynamic>?> getProfessionalExpirationInfo(String professionalId) async {
    try {
      final snapshot = await _database.child('professionals/$professionalId').get();
      
      if (!snapshot.exists || snapshot.value == null) return null;
      
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      final expiresAt = data['expires_at'];
      
      return {
        'expires_at': expiresAt,
        'is_expired': isExpired(expiresAt),
        'days_until_expiration': daysUntilExpiration(expiresAt),  // ✅ CORRIGIDO
        'is_near_expiration': isNearExpiration(expiresAt),
        'expiration_message': getExpirationMessage(expiresAt),
        'status': data['status'],
      };
    } catch (e) {
      print('❌ Erro ao obter info de expiração: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════
  // 🧪 HELPER DE DEBUG (remover em produção)
  // ════════════════════════════════════════════════

  /// Imprime o estado atual do testDate para debug
  void debugTestDate() {
    if (testDate != null) {
      print('🧪 testDate ativo: $testDate');
      print('   _now = $_now');
      print('   expiração gerada = ${getExpirationDate()}');
      print('   renovação gerada = ${renewExpiration()}');
    } else {
      print('🧪 testDate null — usando DateTime.now() real');
    }
  }
}