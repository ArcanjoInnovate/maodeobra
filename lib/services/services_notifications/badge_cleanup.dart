// lib/helpers/badge_cleanup_helper.dart
// SCRIPT OTIMIZADO PARA VERIFICAR E CORRIGIR BADGES
// Minimiza leituras do Firebase usando queries eficientes

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';

class BadgeCleanupHelper {
  static final DatabaseReference _database = FirebaseDatabase.instance.ref();

  // ========================================
  // MODELO DE RESULTADO DA VERIFICAÇÃO
  // ========================================
  
  static Future<BadgeVerificationResult> verifyAndFixBadge(
    String userId,
    String userRole, // 'worker' ou 'contractor'
  ) async {
    final result = BadgeVerificationResult(userId: userId);
    
    try {
      debugPrint('═══════════════════════════════════════');
      debugPrint('🔍 VERIFICANDO BADGE: $userId');
      debugPrint('═══════════════════════════════════════');
      debugPrint('Role: $userRole');
      
      // ========================================
      // 1. LÊ BADGE ATUAL (1 leitura)
      // ========================================
      
      final badgeSnapshot = await _database.child('badges/$userId').get();
      
      if (badgeSnapshot.exists) {
        final badgeData = badgeSnapshot.value as Map<dynamic, dynamic>;
        result.currentBadge = BadgeData(
          unreadChats: (badgeData['unread_chats'] as int?) ?? 0,
          unreadRequests: (badgeData['unread_requests'] as int?) ?? 0,
        );
        debugPrint('📊 Badge atual: ${result.currentBadge}');
      } else {
        result.currentBadge = BadgeData(unreadChats: 0, unreadRequests: 0);
        debugPrint('⚠️ Badge não existe, será criado');
        result.badgeCreated = true;
      }
      
      // ========================================
      // 2. CONTA CHATS NÃO LIDOS (2 leituras)
      // ========================================
      
      debugPrint('\n🔍 Verificando chats não lidos...');
      int unreadChats = 0;
      List<String> unreadChatsList = [];
      
      // Query chats como EMPLOYEE (1 leitura)
      final employeeChatsSnap = await _database
          .child('Chats')
          .orderByChild('employee')
          .equalTo(userId)
          .get();
      
      if (employeeChatsSnap.exists) {
        final chats = employeeChatsSnap.value as Map<dynamic, dynamic>;
        for (var entry in chats.entries) {
          final chatId = entry.key.toString();
          final chatData = entry.value as Map<dynamic, dynamic>;
          final unreadCount = chatData['unreadCount'] as Map<dynamic, dynamic>?;
          
          if (unreadCount != null) {
            final count = (unreadCount['employee'] as int?) ?? 0;
            if (count == 1) {
              unreadChats++;
              unreadChatsList.add('$chatId (employee)');
            }
          }
        }
        debugPrint('  📬 Chats como employee: ${chats.length}');
      }
      
      // Query chats como CONTRACTOR (1 leitura)
      final contractorChatsSnap = await _database
          .child('Chats')
          .orderByChild('contractor')
          .equalTo(userId)
          .get();
      
      if (contractorChatsSnap.exists) {
        final chats = contractorChatsSnap.value as Map<dynamic, dynamic>;
        for (var entry in chats.entries) {
          final chatId = entry.key.toString();
          final chatData = entry.value as Map<dynamic, dynamic>;
          final unreadCount = chatData['unreadCount'] as Map<dynamic, dynamic>?;
          
          if (unreadCount != null) {
            final count = (unreadCount['contractor'] as int?) ?? 0;
            if (count == 1) {
              unreadChats++;
              unreadChatsList.add('$chatId (contractor)');
            }
          }
        }
        debugPrint('  📬 Chats como contractor: ${chats.length}');
      }
      
      // Limita a 9
      unreadChats = unreadChats.clamp(0, 9);
      
      debugPrint('  ✅ Total de chats não lidos: $unreadChats');
      if (unreadChatsList.isNotEmpty) {
        debugPrint('  📋 Lista: ${unreadChatsList.join(', ')}');
      }
      
      // ========================================
      // 3. CONTA REQUESTS NÃO LIDOS (1-2 leituras)
      // ========================================
      
      debugPrint('\n🔍 Verificando requests não lidos...');
      int unreadRequests = 0;
      List<String> unreadRequestsList = [];
      
      if (userRole == 'worker') {
        // Query perfis profissionais (1 leitura)
        final profilesSnap = await _database
            .child('professionals')
            .orderByChild('local_id')
            .equalTo(userId)
            .get();
        
        if (profilesSnap.exists) {
          final profiles = profilesSnap.value as Map<dynamic, dynamic>;
          
          for (var profileEntry in profiles.entries) {
            final profileId = profileEntry.key.toString();
            final profileData = profileEntry.value as Map<dynamic, dynamic>;
            final views = profileData['views'] as Map<dynamic, dynamic>?;
            final requestViews = views?['request_views'] as Map<dynamic, dynamic>?;
            
            if (requestViews != null) {
              for (var reqEntry in requestViews.entries) {
                final reqId = reqEntry.key.toString();
                final reqData = reqEntry.value as Map<dynamic, dynamic>;
                
                if (reqData['viewed_by_owner'] == false) {
                  unreadRequests++;
                  unreadRequestsList.add('$profileId/$reqId');
                }
              }
            }
          }
          
          debugPrint('  📋 Perfis profissionais: ${profiles.length}');
        }
      } else {
        // Query vagas (1 leitura)
        final vacanciesSnap = await _database
            .child('vacancy')
            .orderByChild('local_id')
            .equalTo(userId)
            .get();
        
        if (vacanciesSnap.exists) {
          final vacancies = vacanciesSnap.value as Map<dynamic, dynamic>;
          
          for (var vacancyEntry in vacancies.entries) {
            final vacancyId = vacancyEntry.key.toString();
            final vacancyData = vacancyEntry.value as Map<dynamic, dynamic>;
            final views = vacancyData['views'] as Map<dynamic, dynamic>?;
            final requestViews = views?['request_views'] as Map<dynamic, dynamic>?;
            
            if (requestViews != null) {
              for (var reqEntry in requestViews.entries) {
                final reqId = reqEntry.key.toString();
                final reqData = reqEntry.value as Map<dynamic, dynamic>;
                
                if (reqData['viewed_by_owner'] == false) {
                  unreadRequests++;
                  unreadRequestsList.add('$vacancyId/$reqId');
                }
              }
            }
          }
          
          debugPrint('  💼 Vagas: ${vacancies.length}');
        }
      }
      
      // Limita a 9
      unreadRequests = unreadRequests.clamp(0, 9);
      
      debugPrint('  ✅ Total de requests não lidos: $unreadRequests');
      if (unreadRequestsList.isNotEmpty) {
        debugPrint('  📋 Lista: ${unreadRequestsList.join(', ')}');
      }
      
      // ========================================
      // 4. CALCULA BADGE CORRETO
      // ========================================
      
      result.calculatedBadge = BadgeData(
        unreadChats: unreadChats,
        unreadRequests: unreadRequests,
      );
      
      debugPrint('\n📊 COMPARAÇÃO:');
      debugPrint('  Atual:     ${result.currentBadge}');
      debugPrint('  Calculado: ${result.calculatedBadge}');
      
      // ========================================
      // 5. VERIFICA SE PRECISA CORRIGIR
      // ========================================
      
      final needsCorrection = 
          result.currentBadge.unreadChats != result.calculatedBadge.unreadChats ||
          result.currentBadge.unreadRequests != result.calculatedBadge.unreadRequests ||
          result.badgeCreated;
      
      if (needsCorrection) {
        debugPrint('\n⚠️ BADGE INCORRETO! Corrigindo...');
        
        // Atualiza badge (1 escrita)
        await _database.child('badges/$userId').set({
          'unread_chats': result.calculatedBadge.unreadChats,
          'unread_requests': result.calculatedBadge.unreadRequests,
          'updated_at': ServerValue.timestamp,
        });
        
        result.wasCorrected = true;
        result.readsUsed = userRole == 'worker' ? 4 : 4; // employee + contractor + badge + (profiles ou vacancies)
        result.writesUsed = 1;
        
        debugPrint('✅ Badge corrigido!');
        debugPrint('  Chats: ${result.currentBadge.unreadChats} → ${result.calculatedBadge.unreadChats}');
        debugPrint('  Requests: ${result.currentBadge.unreadRequests} → ${result.calculatedBadge.unreadRequests}');
      } else {
        debugPrint('\n✅ Badge está correto!');
        result.wasCorrected = false;
        result.readsUsed = userRole == 'worker' ? 4 : 4;
        result.writesUsed = 0;
      }
      
      debugPrint('\n📊 Operações Firebase:');
      debugPrint('  Leituras: ${result.readsUsed}');
      debugPrint('  Escritas: ${result.writesUsed}');
      
      result.success = true;
      
    } catch (e, stack) {
      debugPrint('\n❌ ERRO ao verificar badge:');
      debugPrint('Erro: $e');
      debugPrint('Stack: $stack');
      
      result.success = false;
      result.error = e.toString();
    }
    
    debugPrint('═══════════════════════════════════════\n');
    
    return result;
  }

  // ========================================
  // VERIFICAÇÃO EM BATCH (MÚLTIPLOS USUÁRIOS)
  // ========================================
  
  static Future<BatchVerificationResult> verifyMultipleUsers(
    Map<String, String> userRoles, // userId -> role
  ) async {
    final batchResult = BatchVerificationResult();
    
    debugPrint('\n╔═══════════════════════════════════════╗');
    debugPrint('║  VERIFICAÇÃO EM BATCH - ${userRoles.length} USUÁRIOS  ║');
    debugPrint('╚═══════════════════════════════════════╝\n');
    
    for (var entry in userRoles.entries) {
      final userId = entry.key;
      final role = entry.value;
      
      final result = await verifyAndFixBadge(userId, role);
      
      batchResult.results.add(result);
      batchResult.totalReads += result.readsUsed;
      batchResult.totalWrites += result.writesUsed;
      
      if (result.success) {
        if (result.wasCorrected) {
          batchResult.correctedCount++;
        } else {
          batchResult.correctCount++;
        }
      } else {
        batchResult.errorCount++;
      }
    }
    
    // Relatório final
    debugPrint('\n╔═══════════════════════════════════════╗');
    debugPrint('║       RELATÓRIO FINAL - BATCH        ║');
    debugPrint('╚═══════════════════════════════════════╝');
    debugPrint('📊 Total processado: ${userRoles.length}');
    debugPrint('✅ Corretos: ${batchResult.correctCount}');
    debugPrint('🔧 Corrigidos: ${batchResult.correctedCount}');
    debugPrint('❌ Erros: ${batchResult.errorCount}');
    debugPrint('\n📈 Operações Firebase:');
    debugPrint('   Leituras: ${batchResult.totalReads}');
    debugPrint('   Escritas: ${batchResult.totalWrites}');
    debugPrint('   Média de leituras/usuário: ${(batchResult.totalReads / userRoles.length).toStringAsFixed(1)}');
    debugPrint('═══════════════════════════════════════\n');
    
    return batchResult;
  }

  // ========================================
  // VERIFICAR TODOS OS USUÁRIOS COM BADGES
  // ========================================
  
  static Future<BatchVerificationResult> verifyAllBadges() async {
    debugPrint('\n🔍 Buscando todos os badges...');
    
    final badgesSnapshot = await _database.child('badges').get();
    
    if (!badgesSnapshot.exists) {
      debugPrint('⚠️ Nenhum badge encontrado no banco');
      return BatchVerificationResult();
    }
    
    final badges = badgesSnapshot.value as Map<dynamic, dynamic>;
    debugPrint('📊 Encontrados ${badges.length} badges\n');
    
    // Precisa determinar o role de cada usuário
    // Busca em Users para pegar o role
    final userRoles = <String, String>{};
    
    for (var userId in badges.keys) {
      final userSnap = await _database.child('Users/$userId').get();
      
      if (userSnap.exists) {
        final userData = userSnap.value as Map<dynamic, dynamic>;
        final role = userData['role'] as String?;
        
        if (role != null) {
          userRoles[userId.toString()] = role;
        } else {
          debugPrint('⚠️ Usuário $userId sem role definido, assumindo worker');
          userRoles[userId.toString()] = 'worker';
        }
      } else {
        debugPrint('⚠️ Usuário $userId não encontrado em Users, pulando');
      }
    }
    
    return await verifyMultipleUsers(userRoles);
  }
}

// ========================================
// MODELOS DE DADOS
// ========================================

class BadgeData {
  final int unreadChats;
  final int unreadRequests;

  BadgeData({
    required this.unreadChats,
    required this.unreadRequests,
  });

  int get total => unreadChats + unreadRequests;

  @override
  String toString() {
    return 'chats=$unreadChats, requests=$unreadRequests, total=$total';
  }
}

class BadgeVerificationResult {
  final String userId;
  bool success = false;
  bool wasCorrected = false;
  bool badgeCreated = false;
  
  BadgeData currentBadge = BadgeData(unreadChats: 0, unreadRequests: 0);
  BadgeData calculatedBadge = BadgeData(unreadChats: 0, unreadRequests: 0);
  
  int readsUsed = 0;
  int writesUsed = 0;
  
  String? error;

  BadgeVerificationResult({required this.userId});

  @override
  String toString() {
    if (!success) {
      return '❌ $userId - ERRO: $error';
    }
    
    if (wasCorrected) {
      return '🔧 $userId - CORRIGIDO: $currentBadge → $calculatedBadge';
    }
    
    return '✅ $userId - OK: $currentBadge';
  }
}

class BatchVerificationResult {
  final List<BadgeVerificationResult> results = [];
  
  int correctCount = 0;
  int correctedCount = 0;
  int errorCount = 0;
  
  int totalReads = 0;
  int totalWrites = 0;

  int get totalProcessed => results.length;
  
  double get successRate => 
      totalProcessed > 0 ? (correctCount + correctedCount) / totalProcessed : 0.0;
}