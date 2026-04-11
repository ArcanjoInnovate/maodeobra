// lib/services/profile_validation_service.dart

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileValidationService {
  static final DatabaseReference _db = FirebaseDatabase.instance.ref();

  // ==========================================
  // 🔹 VALIDAÇÃO PARA PRESTADOR DE SERVIÇO (WORKER)
  // ==========================================
  static Future<ProfileValidationResult> validateWorkerProfile() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) {
      return ProfileValidationResult(
        isValid: false,
        message: 'Você precisa estar logado',
      );
    }

    try {
      // Buscar dados do usuário
      final userSnapshot = await _db.child('Users').child(currentUserId).get();
      
      if (!userSnapshot.exists) {
        return ProfileValidationResult(
          isValid: false,
          message: 'Usuário não encontrado',
        );
      }

      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);

      // Verificar active_mode
      final activeMode = userData['activeMode'] ?? '';
      if (activeMode != 'worker') {
        return ProfileValidationResult(
          isValid: false,
          message: 'Apenas prestadores de serviço podem se candidatar a vagas.\n\nAlterne para o modo "Prestador de Serviço" nas configurações.',
        );
      }

      // Verificar finished_contact e finished_basic
      final finishedContact = userData['finished_contact'] ?? false;
      final finishedBasic = userData['finished_basic'] ?? false;

      if (!finishedContact || !finishedBasic) {
        return ProfileValidationResult(
          isValid: false,
          message: 'Complete seu cadastro básico e de contato antes de se candidatar a vagas.',
        );
      }

      // Verificar data_worker
      final dataWorker = userData['data_worker'];
      if (dataWorker == null) {
        return ProfileValidationResult(
          isValid: false,
          message: 'Complete seu perfil profissional antes de se candidatar a vagas.',
        );
      }

      final workerData = Map<String, dynamic>.from(dataWorker);

      // Lista de campos faltando
      final missingFields = <String>[];

      // Verificar profissão
      final profession = workerData['profession'] ?? '';
      if (profession.isEmpty || 
          profession == 'Não definida' || 
          profession == 'Não definido') {
        missingFields.add('Profissão');
      }

      // Verificar legalType (do usuário principal)
      final legalType = userData['legalType'] ?? '';
      if (legalType.isEmpty || 
          legalType == 'Não definido') {
        missingFields.add('Tipo de contrato');
      }

      // Verificar city (do usuário principal)
      final city = userData['city'] ?? '';
      if (city.isEmpty || city == 'Não definido') {
        missingFields.add('Cidade');
      }

      // Verificar state (do usuário principal)
      final state = userData['state'] ?? '';
      if (state.isEmpty || state == 'Não definido') {
        missingFields.add('Estado');
      }

      // Se for PJ, empresa é obrigatória
      if (legalType.toLowerCase().contains('pj') || 
          legalType.toLowerCase().contains('jurídica')) {
        final company = workerData['company'] ?? '';
        if (company.isEmpty || company == 'Não definido') {
          missingFields.add('Empresa (obrigatório para PJ)');
        }
      }

      if (missingFields.isNotEmpty) {
        return ProfileValidationResult(
          isValid: false,
          message: 'Complete os seguintes campos no seu perfil:\n\n${missingFields.join('\n')}',
        );
      }

      return ProfileValidationResult(isValid: true);

    } catch (e) {
      return ProfileValidationResult(
        isValid: false,
        message: 'Erro ao validar perfil: $e',
      );
    }
  }

  // ==========================================
  // 🔹 VALIDAÇÃO PARA CONTRATANTE (CONTRACTOR)
  // ==========================================
  static Future<ProfileValidationResult> validateContractorProfile() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) {
      return ProfileValidationResult(
        isValid: false,
        message: 'Você precisa estar logado',
      );
    }

    try {
      // Buscar dados do usuário
      final userSnapshot = await _db.child('Users').child(currentUserId).get();
      
      if (!userSnapshot.exists) {
        return ProfileValidationResult(
          isValid: false,
          message: 'Usuário não encontrado',
        );
      }

      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);

      // Verificar activeMode
      final activeMode = userData['activeMode'] ?? '';
      if (activeMode != 'contractor') {
        return ProfileValidationResult(
          isValid: false,
          message: 'Apenas contratantes podem solicitar chat com profissionais.\n\nAlterne para o modo "Contratante" nas configurações.',
        );
      }

      // Verificar finished_contact e finished_basic
      final finishedContact = userData['finished_contact'] ?? false;
      final finishedBasic = userData['finished_basic'] ?? false;

      if (!finishedContact || !finishedBasic) {
        return ProfileValidationResult(
          isValid: false,
          message: 'Complete seu cadastro básico e de contato antes de solicitar chat.',
        );
      }

      // Verificar data_contractor
      final dataContractor = userData['data_contractor'];
      if (dataContractor == null) {
        return ProfileValidationResult(
          isValid: false,
          message: 'Complete seu perfil de contratante antes de solicitar chat.',
        );
      }

      final contractorData = Map<String, dynamic>.from(dataContractor);

      // Lista de campos faltando
      final missingFields = <String>[];

      // Validar profession (não pode ser "Não definida" ou vazio)
      final profession = contractorData['profession'] ?? '';
      if (profession.isEmpty || 
          profession == 'Não definida' || 
          profession == 'Não definido') {
        missingFields.add('Profissão');
      }

      // Validar legalType (do usuário principal)
      final legalType = userData['legalType'] ?? '';
      if (legalType.isEmpty || legalType == 'Não definido') {
        missingFields.add('Tipo de contrato');
      }

      // Validar city (do usuário principal)
      final city = userData['city'] ?? '';
      if (city.isEmpty || city == 'Não definido') {
        missingFields.add('Cidade');
      }

      // Validar state (do usuário principal)
      final state = userData['state'] ?? '';
      if (state.isEmpty || state == 'Não definido') {
        missingFields.add('Estado');
      }

      // Se for PJ, empresa é obrigatória
      if (legalType.toLowerCase().contains('pj') || 
          legalType.toLowerCase().contains('jurídica')) {
        final company = contractorData['company'] ?? '';
        if (company.isEmpty || company == 'Não definido') {
          missingFields.add('Empresa (obrigatório para PJ)');
        }
      }

      if (missingFields.isNotEmpty) {
        return ProfileValidationResult(
          isValid: false,
          message: 'Complete os seguintes campos no seu perfil:\n\n${missingFields.join('\n')}',
        );
      }

      return ProfileValidationResult(isValid: true);

    } catch (e) {
      return ProfileValidationResult(
        isValid: false,
        message: 'Erro ao validar perfil: $e',
      );
    }
  }
}

// ==========================================
// 🔹 RESULTADO DA VALIDAÇÃO
// ==========================================
class ProfileValidationResult {
  final bool isValid;
  final String? message;

  ProfileValidationResult({
    required this.isValid,
    this.message,
  });

  // Exibir diálogo com erro
  void showErrorDialog(BuildContext context) {
    if (!isValid && message != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
              const SizedBox(width: 12),
              const Text('Perfil Incompleto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            message!,
            style: const TextStyle(fontSize: 16, height: 1.5),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    }
  }

  // Exibir snackbar com erro
  void showErrorSnackBar(BuildContext context) {
    if (!isValid && message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message!),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
