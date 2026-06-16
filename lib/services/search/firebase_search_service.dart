import 'package:flutter/foundation.dart';
import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/search/vacancy_model.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';

class FirebaseSearchServiceServerPaginated {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final ExpirationService _expirationService = ExpirationService();

  // ===============================
  // BUSCAR VAGAS COM PAGINACAO
  // ===============================
  Future<PaginatedResult<VacancyModel>> fetchVacanciesPaginated({
    required Set<String> blockedUserIds,
    int limit = 20,
    String? endAtKey,
    dynamic endAtValue,
  }) async {
    try {
      final startTime = DateTime.now();

      // ✅ Busca por updated_at para trazer as mais recentes primeiro
      // Sem .equalTo('Aberta') — vagas renovadas voltam ao topo independente do status gravado
      Query query = _database
          .child('vacancy')
          .orderByChild('updated_at');

      if (endAtValue != null) {
        query = query.endBefore(endAtValue);
      }

      // Busca com margem para absorver filtros client-side
      query = query.limitToLast((limit * 2).ceil());

      final snapshot = await query.get();
      final readsEstimated = snapshot.exists ? snapshot.children.length : 0;

      if (!snapshot.exists) {
        debugPrint('Nenhuma vaga encontrada');
        _printReadStats(startTime, readsEstimated);
        return PaginatedResult(items: [], hasMore: false, lastKey: null, lastValue: null);
      }

      final data = snapshot.value as Map<dynamic, dynamic>;

      // Ordena por updated_at desc (mais recente primeiro)
      final sortedEntries = data.entries.toList()
        ..sort((a, b) {
          final aVal = a.value['updated_at'] ?? a.value['created_at'] ?? '';
          final bVal = b.value['updated_at'] ?? b.value['created_at'] ?? '';
          return bVal.compareTo(aVal);
        });

      final vacancies = <VacancyModel>[];
      String? newLastKey;
      dynamic newLastValue;

      for (var entry in sortedEntries) {
        if (vacancies.length >= limit) break;

        final key = entry.key.toString();
        final value = entry.value;

        if (value is! Map) continue;

        try {
          final vacancy = VacancyModel.fromJson(key, value);

          // FILTRO 1: Status deve ser "aberta" (exclui pausadas, encerradas)
          final status = vacancy.status.toLowerCase();
          if (status != 'aberta' && status != 'open') {
            debugPrint('  Vaga $key excluída — status: $status');
            continue;
          }

          // FILTRO 2: Não expirada pelo campo expires_at
          final expiresAt = vacancy.expiresAt;
          if (expiresAt.isNotEmpty && _expirationService.isExpired(expiresAt)) {
            debugPrint('  Vaga $key excluída — expirada: $expiresAt');
            continue;
          }

          // FILTRO 3: Dono não bloqueado
          if (blockedUserIds.isNotEmpty &&
              vacancy.localId.isNotEmpty &&
              blockedUserIds.contains(vacancy.localId)) {
            debugPrint('  Vaga $key excluída — dono bloqueado: ${vacancy.localId}');
            continue;
          }

          vacancies.add(vacancy);
          newLastKey = key;
          newLastValue = value['updated_at'] ?? value['created_at'];
        } catch (e) {
          debugPrint('Erro ao parsear vaga $key: $e');
        }
      }

      final hasMore = sortedEntries.length >= (limit * 2) && vacancies.length >= limit;

      _printReadStats(startTime, readsEstimated);
      debugPrint('${vacancies.length} vagas válidas retornadas (de $readsEstimated lidas)');

      return PaginatedResult(
        items: vacancies,
        hasMore: hasMore,
        lastKey: newLastKey,
        lastValue: newLastValue,
      );
    } catch (e, stack) {
      debugPrint('Erro ao buscar vagas: $e');
      debugPrint('Stack: $stack');
      return PaginatedResult(items: [], hasMore: false, lastKey: null, lastValue: null);
    }
  }

  // ===============================
  // BUSCAR PROFISSIONAIS COM PAGINACAO
  // ===============================
  Future<PaginatedResult<ProfessionalModel>> fetchProfessionalsPaginated({
    required Set<String> blockedUserIds,
    int limit = 20,
    String? endAtKey,
    dynamic endAtValue,
  }) async {
    try {
      final startTime = DateTime.now();

      // ✅ Busca por updated_at — sem .equalTo('active')
      // Profissionais renovados (bump no updated_at) voltam ao topo independente do status gravado
      Query query = _database
          .child('professionals')
          .orderByChild('updated_at');

      if (endAtValue != null) {
        query = query.endBefore(endAtValue);
      }

      query = query.limitToLast((limit * 2).ceil());

      final snapshot = await query.get();
      final readsEstimated = snapshot.exists ? snapshot.children.length : 0;

      if (!snapshot.exists) {
        debugPrint('Nenhum profissional encontrado');
        _printReadStats(startTime, readsEstimated);
        return PaginatedResult(items: [], hasMore: false, lastKey: null, lastValue: null);
      }

      final data = snapshot.value as Map<dynamic, dynamic>;

      final sortedEntries = data.entries.toList()
        ..sort((a, b) {
          final aVal = a.value['updated_at'] ?? a.value['created_at'] ?? '';
          final bVal = b.value['updated_at'] ?? b.value['created_at'] ?? '';
          return bVal.compareTo(aVal);
        });

      final professionals = <ProfessionalModel>[];
      String? newLastKey;
      dynamic newLastValue;

      for (var entry in sortedEntries) {
        if (professionals.length >= limit) break;

        final key = entry.key.toString();
        final value = entry.value;

        if (value is! Map) continue;

        try {
          final prof = ProfessionalModel.fromJson(key, value);

          // FILTRO 1: Apenas ativos (exclui 'paused' e outros status indesejados)
          // 'expired' foi migrado para 'active' — não deve mais existir no banco
          final status = prof.status.toLowerCase();
          if (status == 'paused' || status == 'inactive' || status == 'deleted') {
            debugPrint('  Profissional $key excluído — status: $status');
            continue;
          }

          // FILTRO 2: Dono não bloqueado
          if (blockedUserIds.isNotEmpty &&
              prof.localId.isNotEmpty &&
              blockedUserIds.contains(prof.localId)) {
            debugPrint('  Profissional $key excluído — bloqueado: ${prof.localId}');
            continue;
          }

          professionals.add(prof);
          newLastKey = key;
          newLastValue = value['updated_at'];
        } catch (e) {
          debugPrint('Erro ao parsear profissional $key: $e');
        }
      }

      final hasMore = sortedEntries.length >= (limit * 2) && professionals.length >= limit;

      _printReadStats(startTime, readsEstimated);
      debugPrint('${professionals.length} profissionais retornados (de $readsEstimated lidos)');

      return PaginatedResult(
        items: professionals,
        hasMore: hasMore,
        lastKey: newLastKey,
        lastValue: newLastValue,
      );
    } catch (e, stack) {
      debugPrint('Erro ao buscar profissionais: $e');
      debugPrint('Stack: $stack');
      return PaginatedResult(items: [], hasMore: false, lastKey: null, lastValue: null);
    }
  }

  // ===============================
  // BUSCAR REQUESTS — usa índice user_requests (sem full scan)
  // ===============================
  Future<Set<String>> fetchRequestedVacancyIds() async {
    try {
      if (_currentUserId == null) return {};

      // ✅ Lê do índice denormalizado: O(1) em vez de O(N vagas)
      final snap = await _database
          .child('user_requests/$_currentUserId/vacancies')
          .get();

      if (snap.exists && snap.value != null) {
        final data = snap.value;
        final ids = <String>{};
        if (data is Map) {
          ids.addAll(data.keys.map((k) => k.toString()));
        } else if (data is List) {
          for (var item in data) {
            if (item != null) ids.add(item.toString());
          }
        }
        return ids;
      }

      // Fallback: varre vagas abertas (raro — só se user_requests estiver vazio)
      final snapshot = await _database
          .child('vacancy')
          .orderByChild('status')
          .equalTo('Aberta')
          .get();

      if (!snapshot.exists) return {};

      final data = snapshot.value as Map<dynamic, dynamic>;
      final requestedVacancies = <String>{};

      data.forEach((vacancyId, value) {
        if (value is! Map) return;
        if (value.containsKey('requests')) {
          final requests = value['requests'];
          if (requests is List && requests.contains(_currentUserId)) {
            requestedVacancies.add(vacancyId.toString());
          } else if (requests is Map && requests.containsKey(_currentUserId)) {
            requestedVacancies.add(vacancyId.toString());
          }
        }
      });

      return requestedVacancies;
    } catch (e) {
      debugPrint('Erro ao buscar requests de vagas: $e');
      return {};
    }
  }

  Future<Set<String>> fetchRequestedProfessionalIds() async {
    try {
      if (_currentUserId == null) return {};

      // ✅ Lê do índice denormalizado
      final snap = await _database
          .child('user_requests/$_currentUserId/professionals')
          .get();

      if (snap.exists && snap.value != null) {
        final data = snap.value;
        final ids = <String>{};
        if (data is Map) {
          ids.addAll(data.keys.map((k) => k.toString()));
        } else if (data is List) {
          for (var item in data) {
            if (item != null) ids.add(item.toString());
          }
        }
        return ids;
      }

      // Fallback
      final snapshot = await _database
          .child('professionals')
          .orderByChild('status')
          .equalTo('active')
          .get();

      if (!snapshot.exists) return {};

      final data = snapshot.value as Map<dynamic, dynamic>;
      final requestedProfessionals = <String>{};

      data.forEach((professionalId, value) {
        if (value is! Map) return;
        final localId = value['local_id']?.toString();
        if (localId == null) return;
        if (value.containsKey('requests')) {
          final requests = value['requests'];
          if (requests is List && requests.contains(_currentUserId)) {
            requestedProfessionals.add(localId);
          } else if (requests is Map && requests.containsKey(_currentUserId)) {
            requestedProfessionals.add(localId);
          }
        }
      });

      return requestedProfessionals;
    } catch (e) {
      debugPrint('Erro ao buscar requests de profissionais: $e');
      return {};
    }
  }

  // ===============================
  // SOLICITAR CHAT (COM TRANSACAO)
  // ===============================
  Future<bool> requestProfessionalChat(String professionalId) async {
    try {
      if (_currentUserId == null) {
        debugPrint('Usuário não autenticado');
        return false;
      }

      final requestsRef = _database
          .child('professionals')
          .child(professionalId)
          .child('requests');

      final result = await requestsRef.runTransaction((currentValue) {
        List<dynamic> requestsList = [];
        if (currentValue is List) {
          requestsList = List.from(currentValue);
        }
        if (requestsList.contains(_currentUserId)) {
          return Transaction.abort();
        }
        requestsList.add(_currentUserId);
        return Transaction.success(requestsList);
      });

      if (result.committed) {
        debugPrint('Solicitação enviada com sucesso');
        return true;
      } else {
        debugPrint('Solicitação já existe');
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao solicitar chat: $e');
      return false;
    }
  }

  Future<bool> requestVacancyChat(String vacancyId) async {
    try {
      if (_currentUserId == null) {
        debugPrint('Usuário não autenticado');
        return false;
      }

      final requestsRef = _database
          .child('vacancy')
          .child(vacancyId)
          .child('requests');

      final result = await requestsRef.runTransaction((currentValue) {
        List<dynamic> requestsList = [];
        if (currentValue is List) {
          requestsList = List.from(currentValue);
        }
        if (requestsList.contains(_currentUserId)) {
          return Transaction.abort();
        }
        requestsList.add(_currentUserId);
        return Transaction.success(requestsList);
      });

      if (result.committed) {
        debugPrint('Candidatura enviada com sucesso');
        return true;
      } else {
        debugPrint('Candidatura já existe');
        return false;
      }
    } catch (e) {
      debugPrint('Erro ao candidatar: $e');
      return false;
    }
  }

  // ===============================
  // VERIFICACAO RAPIDA DE REQUEST
  // ===============================
  Future<bool> hasRequestedProfessional(String professionalId) async {
    try {
      if (_currentUserId == null) return false;

      final snapshot = await _database
          .child('professionals/$professionalId/requests')
          .get();

      if (!snapshot.exists) return false;

      final requests = snapshot.value;
      if (requests is List) return requests.contains(_currentUserId);
      if (requests is Map) return requests.containsKey(_currentUserId);

      return false;
    } catch (e) {
      debugPrint('Erro ao verificar request: $e');
      return false;
    }
  }

  Future<bool> hasRequestedVacancy(String vacancyId) async {
    try {
      if (_currentUserId == null) return false;

      final snapshot = await _database
          .child('vacancy/$vacancyId/requests')
          .get();

      if (!snapshot.exists) return false;

      final requests = snapshot.value;
      if (requests is List) return requests.contains(_currentUserId);
      if (requests is Map) return requests.containsKey(_currentUserId);

      return false;
    } catch (e) {
      debugPrint('Erro ao verificar request: $e');
      return false;
    }
  }

  // ===============================
  // HELPERS PRIVADOS
  // ===============================
  void _printReadStats(DateTime startTime, int reads) {
    final duration = DateTime.now().difference(startTime);
    final cost = reads * 0.00036;

    debugPrint('Estatísticas:');
    debugPrint('   Tempo: ${duration.inMilliseconds}ms');
    debugPrint('   Reads: $reads');
    debugPrint('   Custo: \$${cost.toStringAsFixed(6)}');

    if (reads > 50) {
      debugPrint('   ALERTA: Muitos reads! Considere mais filtros server-side');
    }
  }
}

// ===============================
// CLASSE DE RESULTADO PAGINADO
// ===============================
class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final String? lastKey;
  final dynamic lastValue;

  PaginatedResult({
    required this.items,
    required this.hasMore,
    this.lastKey,
    this.lastValue,
  });

  @override
  String toString() {
    return 'PaginatedResult(items: ${items.length}, hasMore: $hasMore, lastKey: $lastKey)';
  }
}