import 'package:flutter/foundation.dart';
// lib/services/expiration_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

/// Serviço responsável por gerenciar a expiração de vagas e perfis profissionais
/// Período de expiração: 2 dias
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

  /// ✅ OTIMIZADO: Usa query server-side com filtro por status em vez de baixar tudo.
  /// Antes: baixava TODAS as vagas (~full table scan)
  /// Agora: busca apenas vagas com status 'Aberta'
  Future<List<String>> checkAndExpireVacancies() async {
    try {
      debugPrint('🕐 Verificando vagas expiradas...');
      
      // ✅ OTIMIZAÇÃO: Filtra por status no servidor
      final snapshot = await _database
          .child('vacancy')
          .orderByChild('status')
          .equalTo('Aberta')
          .get();
      
      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('ℹ️ Nenhuma vaga aberta encontrada');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<String> expiredVacancies = [];
      final Map<String, dynamic> batchUpdates = {};

      for (final entry in data.entries) {
        final vacancyId = entry.key.toString();
        final vacancyData = Map<String, dynamic>.from(entry.value as Map);
        
        final expiresAt = vacancyData['expires_at'];
        
        if (expiresAt != null && isExpired(expiresAt)) {
          // ✅ Apenas registra que está velha para fins de ordenação/aviso ao dono.
          // NÃO altera status — vaga permanece visível no feed/search.
          batchUpdates['vacancy/$vacancyId/expired_at'] = _now.toIso8601String();
          
          expiredVacancies.add(vacancyId);
        }
      }

      // ✅ OTIMIZAÇÃO: Uma única escrita batch em vez de N escritas individuais
      if (batchUpdates.isNotEmpty) {
        await _database.update(batchUpdates);
      }

      debugPrint('✅ Verificação concluída: ${expiredVacancies.length} vagas expiradas de ${data.length} abertas');
      return expiredVacancies;
    } catch (e) {
      debugPrint('❌ Erro ao verificar vagas expiradas: $e');
      return [];
    }
  }

  /// Renova uma vaga específica.
  /// Apenas extende expires_at e atualiza updated_at para subir no topo do feed.
  /// NÃO altera o status — vagas nunca saem do feed por expiração.
  Future<bool> renewVacancy(String vacancyId) async {
    try {
      final newExpirationDate = renewExpirationISO();
      final newExpirationTimestamp = renewExpirationTimestamp();
      
      await _database.child('vacancy/$vacancyId').update({
        'expires_at': newExpirationDate,
        'expiration_timestamp': newExpirationTimestamp,
        'renewed_at': _now.toIso8601String(),
        'updated_at': _now.toIso8601String(),
        // ✅ status NUNCA é alterado aqui — vaga permanece no feed independente
      });

      debugPrint('✅ Vaga $vacancyId renovada até $newExpirationDate (bump no feed)');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao renovar vaga: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // PERFIS PROFISSIONAIS - EXPIRAÇÃO
  // ════════════════════════════════════════════════

  /// ✅ OTIMIZADO: Usa query server-side com filtro por status em vez de baixar tudo.
  /// Antes: baixava TODOS os profissionais (~full table scan)
  /// Agora: busca apenas profissionais com status 'active'
  Future<List<String>> checkAndExpireProfessionals() async {
    try {
      debugPrint('🕐 Verificando perfis profissionais expirados...');
      
      // ✅ OTIMIZAÇÃO: Filtra por status no servidor
      final snapshot = await _database
          .child('professionals')
          .orderByChild('status')
          .equalTo('active')
          .get();
      
      if (!snapshot.exists || snapshot.value == null) {
        debugPrint('ℹ️ Nenhum perfil profissional ativo encontrado');
        return [];
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final List<String> expiredProfessionals = [];
      final Map<String, dynamic> batchUpdates = {};

      for (final entry in data.entries) {
        final professionalId = entry.key.toString();
        final professionalData = Map<String, dynamic>.from(entry.value as Map);
        
        final expiresAt = professionalData['expires_at'];
        
        if (expiresAt != null && isExpired(expiresAt)) {
          // ✅ Apenas registra que está velho para fins de aviso ao dono.
          // NÃO altera status — perfil permanece visível no feed/search.
          batchUpdates['professionals/$professionalId/expired_at'] = _now.toIso8601String();
          
          expiredProfessionals.add(professionalId);
        }
      }

      // ✅ OTIMIZAÇÃO: Uma única escrita batch em vez de N escritas individuais
      if (batchUpdates.isNotEmpty) {
        await _database.update(batchUpdates);
      }

      debugPrint('✅ Verificação concluída: ${expiredProfessionals.length} perfis expirados de ${data.length} ativos');
      return expiredProfessionals;
    } catch (e) {
      debugPrint('❌ Erro ao verificar perfis expirados: $e');
      return [];
    }
  }

  /// Renova um perfil profissional específico.
  /// Apenas extende expires_at e atualiza updated_at para subir no topo do feed.
  /// NÃO altera o status — perfis nunca saem do feed por expiração.
  Future<bool> renewProfessional(String professionalId) async {
    try {
      final newExpirationDate = renewExpirationISO();
      final newExpirationTimestamp = renewExpirationTimestamp();
      
      await _database.child('professionals/$professionalId').update({
        'expires_at': newExpirationDate,
        'expiration_timestamp': newExpirationTimestamp,
        'renewed_at': _now.toIso8601String(),
        'updated_at': _now.toIso8601String(),
        // ✅ status NUNCA é alterado aqui — perfil permanece no feed independente
      });

      debugPrint('✅ Perfil $professionalId renovado até $newExpirationDate (bump no feed)');
      return true;
    } catch (e) {
      debugPrint('❌ Erro ao renovar perfil profissional: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // VERIFICAÇÃO PERIÓDICA
  // ════════════════════════════════════════════════

  /// Inicia verificação periódica automática (executa a cada 6 horas)
  Timer startPeriodicCheck() {
    debugPrint('🔄 Iniciando verificação periódica de expiração...');
    
    // Executa imediatamente
    _runPeriodicCheck();
    
    // Depois executa a cada 6 horas
    return Timer.periodic(const Duration(hours: 6), (_) {
      _runPeriodicCheck();
    });
  }

  Future<void> _runPeriodicCheck() async {
    debugPrint('🔍 Executando verificação periódica...');
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
      debugPrint('❌ Erro ao obter info de expiração: $e');
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
      debugPrint('❌ Erro ao obter info de expiração: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════
  // 🧪 HELPER DE DEBUG (remover em produção)
  // ════════════════════════════════════════════════

  /// Imprime o estado atual do testDate para debug
  void debugTestDate() {
    if (testDate != null) {
      debugPrint('🧪 testDate ativo: $testDate');
      debugPrint('   _now = $_now');
      debugPrint('   expiração gerada = ${getExpirationDate()}');
      debugPrint('   renovação gerada = ${renewExpiration()}');
    } else {
      debugPrint('🧪 testDate null — usando DateTime.now() real');
    }
  }
}