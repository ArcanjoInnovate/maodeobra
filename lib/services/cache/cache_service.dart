// lib/services/cache/cache_service.dart

import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';

class CacheService {
  static const String PROFESSIONALS_BOX = 'professionals_cache';
  static const String VACANCIES_BOX = 'vacancies_cache';
  static const String METADATA_BOX = 'cache_metadata';
  
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(PROFESSIONALS_BOX);
    await Hive.openBox(VACANCIES_BOX);
    await Hive.openBox(METADATA_BOX);
  }

  // ===============================
  // 💾 SALVAR PROFISSIONAIS
  // ===============================
  Future<void> saveProfessionals(List<Map<String, dynamic>> professionals) async {
    try {
      final box = Hive.box(PROFESSIONALS_BOX);
      final metadataBox = Hive.box(METADATA_BOX);
      
      await box.clear();
      await box.put('data', jsonEncode(professionals));
      await metadataBox.put('professionals_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('💾 ${professionals.length} profissionais salvos no cache');
    } catch (e) {
      print('❌ Erro ao salvar cache de profissionais: $e');
    }
  }

  // ===============================
  // 📖 CARREGAR PROFISSIONAIS
  // ===============================
  Future<List<Map<String, dynamic>>?> loadProfessionals({
    int maxAgeMinutes = 30,
  }) async {
    try {
      final box = Hive.box(PROFESSIONALS_BOX);
      final metadataBox = Hive.box(METADATA_BOX);
      
      final timestamp = metadataBox.get('professionals_timestamp');
      
      if (timestamp == null) {
        print('ℹ️ Cache de profissionais vazio');
        return null;
      }
      
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      final ageMinutes = age ~/ (1000 * 60);
      
      if (ageMinutes > maxAgeMinutes) {
        print('⏰ Cache de profissionais expirado ($ageMinutes min)');
        return null;
      }
      
      final data = box.get('data');
      if (data == null) return null;
      
      final List<dynamic> decoded = jsonDecode(data);
      final professionals = decoded.cast<Map<String, dynamic>>();
      
      print('📖 ${professionals.length} profissionais carregados do cache ($ageMinutes min)');
      return professionals;
      
    } catch (e) {
      print('❌ Erro ao carregar cache de profissionais: $e');
      return null;
    }
  }

  // ===============================
  // 💾 SALVAR VAGAS
  // ===============================
  Future<void> saveVacancies(List<Map<String, dynamic>> vacancies) async {
    try {
      final box = Hive.box(VACANCIES_BOX);
      final metadataBox = Hive.box(METADATA_BOX);
      
      await box.clear();
      await box.put('data', jsonEncode(vacancies));
      await metadataBox.put('vacancies_timestamp', DateTime.now().millisecondsSinceEpoch);
      
      print('💾 ${vacancies.length} vagas salvas no cache');
    } catch (e) {
      print('❌ Erro ao salvar cache de vagas: $e');
    }
  }

  // ===============================
  // 📖 CARREGAR VAGAS
  // ===============================
  Future<List<Map<String, dynamic>>?> loadVacancies({
    int maxAgeMinutes = 30,
  }) async {
    try {
      final box = Hive.box(VACANCIES_BOX);
      final metadataBox = Hive.box(METADATA_BOX);
      
      final timestamp = metadataBox.get('vacancies_timestamp');
      
      if (timestamp == null) {
        print('ℹ️ Cache de vagas vazio');
        return null;
      }
      
      final age = DateTime.now().millisecondsSinceEpoch - timestamp;
      final ageMinutes = age ~/ (1000 * 60);
      
      if (ageMinutes > maxAgeMinutes) {
        print('⏰ Cache de vagas expirado ($ageMinutes min)');
        return null;
      }
      
      final data = box.get('data');
      if (data == null) return null;
      
      final List<dynamic> decoded = jsonDecode(data);
      final vacancies = decoded.cast<Map<String, dynamic>>();
      
      print('📖 ${vacancies.length} vagas carregadas do cache ($ageMinutes min)');
      return vacancies;
      
    } catch (e) {
      print('❌ Erro ao carregar cache de vagas: $e');
      return null;
    }
  }

  // ===============================
  // 🗑️ LIMPAR CACHE
  // ===============================
  Future<void> clearAll() async {
    try {
      await Hive.box(PROFESSIONALS_BOX).clear();
      await Hive.box(VACANCIES_BOX).clear();
      await Hive.box(METADATA_BOX).clear();
      print('🗑️ Cache limpo');
    } catch (e) {
      print('❌ Erro ao limpar cache: $e');
    }
  }

  Future<void> clearProfessionals() async {
    try {
      await Hive.box(PROFESSIONALS_BOX).clear();
      await Hive.box(METADATA_BOX).delete('professionals_timestamp');
      print('🗑️ Cache de profissionais limpo');
    } catch (e) {
      print('❌ Erro ao limpar cache de profissionais: $e');
    }
  }

  Future<void> clearVacancies() async {
    try {
      await Hive.box(VACANCIES_BOX).clear();
      await Hive.box(METADATA_BOX).delete('vacancies_timestamp');
      print('🗑️ Cache de vagas limpo');
    } catch (e) {
      print('❌ Erro ao limpar cache de vagas: $e');
    }
  }
}
