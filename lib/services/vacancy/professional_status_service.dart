// lib/services/professional_status_service.dart
// 🔄 SERVIÇO DE STATUS DE PERFIS PROFISSIONAIS

import 'package:flutter/foundation.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfessionalStatusService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // UID sempre lido no momento da chamada — evita captura estática
  // que resultava em null quando o usuário ainda não estava logado
  static String? get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid;

  // ==========================================
  // 🔹 ATIVAR PERFIL PROFISSIONAL
  // ==========================================
  /// [localId] e [professionalId] são passados pelo chamador,
  /// eliminando a query desnecessária de busca e o risco de
  /// pegar o perfil errado em caso de duplicatas.
  static Future<bool> activateProfessionalProfile({
    required String localId,
    required String professionalId,
  }) async {
    if (_currentUserId == null) {
      debugPrint('❌ Usuário não autenticado');
      return false;
    }

    try {
      // Batch update: 1 write em vez de 3
      await _db.update({
        'professionals/$professionalId/status': 'active',
        'professionals/$professionalId/updated_at': DateTime.now().toIso8601String(),
        'Users/$localId/isActive': true,
        'Users/$localId/data_worker/activated': true,
      });

      return true;
    } catch (e) {
      debugPrint('Erro ao ativar perfil profissional: $e');
      return false;
    }
  }

  // ==========================================
  // 🔹 PAUSAR PERFIL PROFISSIONAL
  // ==========================================
  static Future<bool> pauseProfessionalProfile({
    required String localId,
    required String professionalId,
  }) async {
    if (_currentUserId == null) {
      debugPrint('❌ Usuário não autenticado');
      return false;
    }

    try {
      // Batch update: 1 write em vez de 3
      await _db.update({
        'professionals/$professionalId/status': 'paused',
        'professionals/$professionalId/updated_at': DateTime.now().toIso8601String(),
        'Users/$localId/isActive': false,
        'Users/$localId/data_worker/activated': false,
      });

      return true;
    } catch (e) {
      debugPrint('Erro ao pausar perfil profissional: $e');
      return false;
    }
  }

  // ==========================================
  // 🔹 VERIFICAR STATUS DO PERFIL
  // ==========================================
  /// Consulta o banco para obter o status atual.
  /// Prioriza perfil com status 'active' se houver múltiplos.
  static Future<ProfessionalStatus> getProfessionalStatus({
    required String localId,
  }) async {
    if (_currentUserId == null) {
      return ProfessionalStatus(
        isActive: false,
        professionalId: null,
        message: 'Usuário não autenticado',
      );
    }

    try {
      final profSnapshot = await _db
          .child('professionals')
          .orderByChild('local_id')
          .equalTo(localId)
          .once();

      if (profSnapshot.snapshot.value == null) {
        return ProfessionalStatus(
          isActive: false,
          professionalId: null,
          message: 'Perfil profissional não encontrado',
        );
      }

      final profData =
          profSnapshot.snapshot.value as Map<dynamic, dynamic>;

      // Prioriza perfil 'active'; senão usa o primeiro encontrado
      String? activeKey;
      String? fallbackKey;
      profData.forEach((key, value) {
        final status =
            (value as Map?)?['status']?.toString().toLowerCase() ?? '';
        fallbackKey ??= key.toString();
        if (status == 'active') activeKey = key.toString();
      });

      final professionalId = activeKey ?? fallbackKey!;
      final data =
          Map<String, dynamic>.from(profData[professionalId] as Map);
      final status = data['status']?.toString().toLowerCase() ?? '';
      final isActive = status == 'active';

      return ProfessionalStatus(
        isActive: isActive,
        professionalId: professionalId,
        status: status,
        message: isActive
            ? 'Perfil profissional ativo'
            : 'Perfil profissional pausado',
      );
    } catch (e) {
      debugPrint('❌ Erro ao verificar status: $e');
      return ProfessionalStatus(
        isActive: false,
        professionalId: null,
        message: 'Erro ao verificar status',
      );
    }
  }

  // ==========================================
  // 🔹 ALTERNAR STATUS (TOGGLE)
  // ==========================================
  static Future<bool> toggleProfessionalStatus({
    required String localId,
    required String professionalId,
    required bool currentlyActive,
  }) async {
    if (currentlyActive) {
      return pauseProfessionalProfile(
          localId: localId, professionalId: professionalId);
    } else {
      return activateProfessionalProfile(
          localId: localId, professionalId: professionalId);
    }
  }
}

// ==========================================
// 🔹 CLASSE DE STATUS
// ==========================================
class ProfessionalStatus {
  final bool isActive;
  final String? professionalId;
  final String? status;
  final String message;

  ProfessionalStatus({
    required this.isActive,
    required this.professionalId,
    this.status,
    required this.message,
  });

  @override
  String toString() =>
      'ProfessionalStatus(isActive: $isActive, professionalId: $professionalId, status: $status)';
}