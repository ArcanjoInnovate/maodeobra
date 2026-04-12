// lib/services/app_lifecycle_service.dart

import 'dart:async';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:flutter/material.dart';

/// Serviço que gerencia o ciclo de vida do app e verificações periódicas
class AppLifecycleService {
  static final AppLifecycleService _instance = AppLifecycleService._internal();
  factory AppLifecycleService() => _instance;
  AppLifecycleService._internal();

  final ExpirationService _expirationService = ExpirationService();
  Timer? _periodicTimer;
  bool _isInitialized = false;

  /// Inicializa o serviço de verificação de expiração
  void initialize() {
    if (_isInitialized) {
      debugPrint('⚠️ AppLifecycleService já foi inicializado');
      return;
    }

    debugPrint('🚀 Inicializando AppLifecycleService...');
    
    // Executa verificação imediata
    _runExpirationCheck();
    
    // Configura verificação periódica (a cada 6 horas)
    _periodicTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => _runExpirationCheck(),
    );
    
    _isInitialized = true;
    debugPrint('✅ AppLifecycleService inicializado com sucesso');
  }

  /// Executa verificação de expiração
  Future<void> _runExpirationCheck() async {
    debugPrint('🔍 Executando verificação de expiração...');
    
    try {
      // Verifica e expira vagas
      final expiredVacancies = await _expirationService.checkAndExpireVacancies();
      debugPrint('📊 Vagas expiradas: ${expiredVacancies.length}');
      
      // Verifica e expira perfis profissionais
      final expiredProfessionals = await _expirationService.checkAndExpireProfessionals();
      debugPrint('📊 Perfis profissionais expirados: ${expiredProfessionals.length}');
      
      debugPrint('✅ Verificação de expiração concluída');
    } catch (e) {
      debugPrint('❌ Erro na verificação de expiração: $e');
    }
  }

  /// Executa verificação manual imediata
  Future<void> checkNow() async {
    debugPrint('🔄 Verificação manual solicitada');
    await _runExpirationCheck();
  }

  /// Finaliza o serviço
  void dispose() {
    debugPrint('🛑 Finalizando AppLifecycleService...');
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _isInitialized = false;
  }

  /// Retorna se o serviço está inicializado
  bool get isInitialized => _isInitialized;
}
