// lib/services/vacancy/vacancy_service.dart

import 'dart:async';
import 'package:firebase_database/firebase_database.dart';

class VacancyService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  final Map<String, Map<String, dynamic>> _vacancyCache = {};
  final Map<String, List<Map<String, dynamic>>> _userVacanciesCache = {};
  final Map<String, Map<String, dynamic>> _candidateCache = {};
  final Map<String, StreamSubscription<DatabaseEvent>> _activeListeners = {};

  static final VacancyService _instance = VacancyService._internal();
  factory VacancyService() => _instance;
  VacancyService._internal();

  // ════════════════════════════════════════════════
  // 1. VAGAS DO USUÁRIO
  // ════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getUserVacancies(String localId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _userVacanciesCache.containsKey(localId)) {
      return _userVacanciesCache[localId]!;
    }

    try {
      final snapshot = await _database
          .child('vacancy')
          .orderByChild('local_id')
          .equalTo(localId)
          .get();

      List<Map<String, dynamic>> vacancies = [];

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final vacancy = Map<String, dynamic>.from(value as Map);
          vacancy['id'] = key;
          vacancies.add(vacancy);
          _vacancyCache[key] = vacancy;
        });

        vacancies.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
          final dateB =
              DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
      }

      _userVacanciesCache[localId] = vacancies;
      return vacancies;
    } catch (e) {
      print('❌ getUserVacancies erro: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════
  // 2. STREAM EM TEMPO REAL
  // ════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> getUserVacanciesStream(String localId) {
    final controller = StreamController<List<Map<String, dynamic>>>();

    final query = _database
        .child('vacancy')
        .orderByChild('local_id')
        .equalTo(localId);

    final subscription = query.onValue.listen((event) {
      final snapshot = event.snapshot;
      List<Map<String, dynamic>> vacancies = [];

      if (snapshot.exists && snapshot.value != null) {
        final data = snapshot.value as Map<dynamic, dynamic>;
        data.forEach((key, value) {
          final vacancy = Map<String, dynamic>.from(value as Map);
          vacancy['id'] = key;
          vacancies.add(vacancy);
          _vacancyCache[key] = vacancy;
        });

        vacancies.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(2000);
          final dateB =
              DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });
      }

      _userVacanciesCache[localId] = vacancies;
      controller.add(vacancies);
    });

    _activeListeners['user_vacancies_$localId'] = subscription;
    controller.onCancel = () {
      subscription.cancel();
      _activeListeners.remove('user_vacancies_$localId');
    };

    return controller.stream;
  }

  // ════════════════════════════════════════════════
  // 3. VAGA ÚNICA
  // ════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getVacancy(String vacancyId,
      {bool forceRefresh = false}) async {
    if (!forceRefresh && _vacancyCache.containsKey(vacancyId)) {
      return _vacancyCache[vacancyId];
    }

    try {
      final snapshot = await _database.child('vacancy/$vacancyId').get();
      if (snapshot.exists && snapshot.value != null) {
        final vacancy =
            Map<String, dynamic>.from(snapshot.value as Map);
        vacancy['id'] = vacancyId;
        _vacancyCache[vacancyId] = vacancy;
        return vacancy;
      }
      return null;
    } catch (e) {
      print('❌ getVacancy erro: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════
  // 4. CANDIDATOS
  // ════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getCandidates(
    String vacancyId,
    List<dynamic> requestIds,
  ) async {
    if (requestIds.isEmpty) return [];

    try {
      final vacancySnapshot = await _database
          .child('vacancy/$vacancyId/views/request_views')
          .get();
      Map<String, dynamic> viewsData = {};

      if (vacancySnapshot.exists && vacancySnapshot.value != null) {
        viewsData =
            Map<String, dynamic>.from(vacancySnapshot.value as Map);
      }

      final futures = requestIds.map((uid) async {
        if (_candidateCache.containsKey(uid)) {
          final cached =
              Map<String, dynamic>.from(_candidateCache[uid]!);
          cached['viewed_by_owner'] =
              viewsData[uid]?['viewed_by_owner'] ?? false;
          return cached;
        }

        final snapshot = await _database.child('Users/$uid').get();
        if (snapshot.exists && snapshot.value != null) {
          final userData =
              Map<String, dynamic>.from(snapshot.value as Map);
          final candidate = {
            'uid': uid,
            'name': userData['Name'] ?? 'Sem nome',
            'phone': userData['telefone'] ?? 'Sem telefone',
            'avatar': userData['avatar'],
            'city': userData['city'] ?? '',
            'state': userData['state'] ?? '',
            'viewed_by_owner':
                viewsData[uid]?['viewed_by_owner'] ?? false,
          };
          _candidateCache[uid] = Map<String, dynamic>.from(candidate)
            ..remove('viewed_by_owner');
          return candidate;
        }
        return null;
      }).toList();

      final results = await Future.wait(futures);
      final candidates =
          results.whereType<Map<String, dynamic>>().toList();

      candidates.sort((a, b) {
        if (a['viewed_by_owner'] == b['viewed_by_owner']) return 0;
        return a['viewed_by_owner'] ? 1 : -1;
      });

      return candidates;
    } catch (e) {
      print('❌ getCandidates erro: $e');
      return [];
    }
  }

  // ════════════════════════════════════════════════
  // 5. CRIAR VAGA
  // ════════════════════════════════════════════════

  Future<String?> createVacancy(Map<String, dynamic> vacancyData) async {
    try {
      final newRef = _database.child('vacancy').push();
      await newRef.set(vacancyData);
      final vacancyId = newRef.key!;
      vacancyData['id'] = vacancyId;
      _vacancyCache[vacancyId] = vacancyData;
      _userVacanciesCache.remove(vacancyData['local_id']);
      return vacancyId;
    } catch (e) {
      print('❌ createVacancy erro: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════
  // 6. ATUALIZAR VAGA
  // ════════════════════════════════════════════════

  Future<bool> updateVacancy(
      String vacancyId, Map<String, dynamic> updates) async {
    try {
      await _database.child('vacancy/$vacancyId').update(updates);
      if (_vacancyCache.containsKey(vacancyId)) {
        _vacancyCache[vacancyId]!.addAll(updates);
      }
      final localId = _vacancyCache[vacancyId]?['local_id'];
      if (localId != null) _userVacanciesCache.remove(localId);
      return true;
    } catch (e) {
      print('❌ updateVacancy erro: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // 7. EXCLUIR VAGA ← AQUI ESTÁ O FIX DO BADGE
  // ════════════════════════════════════════════════

  Future<bool> deleteVacancy(String vacancyId, String ownerLocalId) async {
    print('🗑️ deleteVacancy chamado — vaga: $vacancyId  dono: $ownerLocalId');

    try {
      // PASSO 1: lê candidaturas não visualizadas ANTES de deletar
      final viewsSnap = await _database
          .child('vacancy/$vacancyId/views/request_views')
          .get();

      int unviewedCount = 0;

      if (viewsSnap.exists && viewsSnap.value != null) {
        final raw = viewsSnap.value;
        print('📋 request_views raw: $raw');

        // Firebase pode retornar Map<Object?, Object?> — trata os dois casos
        Map<dynamic, dynamic> views = {};
        if (raw is Map) {
          views = raw as Map<dynamic, dynamic>;
        }

        for (final entry in views.entries) {
          if (entry.value is Map) {
            final v = Map<String, dynamic>.from(entry.value as Map);
            final viewedByOwner = v['viewed_by_owner'];
            print(
                '   candidato ${entry.key}: viewed_by_owner = $viewedByOwner');
            // Conta como não visto se for false, null ou ausente
            if (viewedByOwner == false || viewedByOwner == null) {
              unviewedCount++;
            }
          }
        }
      } else {
        print('📋 request_views: nó vazio ou inexistente');
      }

      print('📊 Candidaturas não vistas: $unviewedCount');

      // PASSO 2: deleta a vaga
      await _database.child('vacancy/$vacancyId').remove();
      print('✅ Vaga $vacancyId deletada do Firebase');

      // PASSO 3: limpa cache
      _vacancyCache.remove(vacancyId);
      _userVacanciesCache.remove(ownerLocalId);

      // PASSO 4: decrementa badge
      if (unviewedCount > 0) {
        await _decrementOwnerBadge(ownerLocalId, unviewedCount);
      } else {
        print('ℹ️ Nenhuma candidatura não vista — badge não alterado');
      }

      return true;
    } catch (e, stack) {
      print('❌ deleteVacancy erro: $e');
      print('$stack');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // 8. ALTERNAR STATUS DA VAGA
  // ════════════════════════════════════════════════

  Future<String?> toggleVacancyStatus(
      String vacancyId, String currentStatus) async {
    final newStatus =
        currentStatus.toLowerCase() == 'aberta' ? 'Pausada' : 'Aberta';
    try {
      final now = DateTime.now().toIso8601String();
      await _database.child('vacancy/$vacancyId').update({
        'status': newStatus,
        'updated_at': now,
      });

      if (_vacancyCache.containsKey(vacancyId)) {
        _vacancyCache[vacancyId]!['status'] = newStatus;
        _vacancyCache[vacancyId]!['updated_at'] = now;
      }

      final ownerLocalId =
          _vacancyCache[vacancyId]?['local_id'] as String?;
      if (ownerLocalId != null &&
          _userVacanciesCache.containsKey(ownerLocalId)) {
        final list = _userVacanciesCache[ownerLocalId]!;
        final idx = list.indexWhere((v) => v['id'] == vacancyId);
        if (idx != -1) {
          list[idx]['status'] = newStatus;
          list[idx]['updated_at'] = now;
        }
      }

      print('✅ toggleVacancyStatus: $currentStatus → $newStatus');
      return newStatus;
    } catch (e) {
      print('❌ toggleVacancyStatus erro: $e');
      return null;
    }
  }

  // ════════════════════════════════════════════════
  // PRIVADO: DECREMENTA BADGE
  // ════════════════════════════════════════════════

  Future<void> _decrementOwnerBadge(
      String ownerLocalId, int count) async {
    print(
        '🔔 _decrementOwnerBadge — userId: $ownerLocalId  decremento: $count');

    try {
      final badgeRef =
          _database.child('badges/$ownerLocalId/unread_requests');

      // Lê valor atual
      final snap = await badgeRef.get();
      print('📊 Badge snapshot exists: ${snap.exists}  value: ${snap.value}');

      int current = 0;
      if (snap.exists && snap.value != null) {
        current = (snap.value as num).toInt();
      }

      final newValue = (current - count).clamp(0, 9999);
      print('🔔 Badge: $current → $newValue');

      await badgeRef.set(newValue);
      print('✅ Badge gravado: $newValue');
    } catch (e, stack) {
      print('❌ _decrementOwnerBadge erro: $e');
      print('$stack');
    }
  }

  // ════════════════════════════════════════════════
  // 9. MARCAR CANDIDATOS COMO VISUALIZADOS
  // ════════════════════════════════════════════════

  Future<bool> markCandidatesAsViewed(
      String vacancyId, List<String> candidateIds) async {
    if (candidateIds.isEmpty) return true;

    try {
      final updates = <String, dynamic>{};
      for (var uid in candidateIds) {
        updates[
                'vacancy/$vacancyId/views/request_views/$uid/viewed_by_owner'] =
            true;
      }
      await _database.update(updates);
      return true;
    } catch (e) {
      print('❌ markCandidatesAsViewed erro: $e');
      return false;
    }
  }

  // ════════════════════════════════════════════════
  // 10. CACHE
  // ════════════════════════════════════════════════

  void clearCache({String? vacancyId, String? localId}) {
    if (vacancyId != null) {
      _vacancyCache.remove(vacancyId);
    } else if (localId != null) {
      _userVacanciesCache.remove(localId);
    } else {
      _vacancyCache.clear();
      _userVacanciesCache.clear();
      _candidateCache.clear();
    }
  }

  void dispose() {
    for (var s in _activeListeners.values) {
      s.cancel();
    }
    _activeListeners.clear();
    clearCache();
  }

  Map<String, int> getCacheStats() => {
        'vacancies_cached': _vacancyCache.length,
        'user_lists_cached': _userVacanciesCache.length,
        'candidates_cached': _candidateCache.length,
        'active_listeners': _activeListeners.length,
      };
}