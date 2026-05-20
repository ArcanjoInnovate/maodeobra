import 'dart:async';

import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';

class FirebaseFeedService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR VAGAS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<PaginatedFeedResult<VacancyModel>> fetchVacanciesForFeed({
    required String? filterState,
    required String? filterCity,
    required String? preferredProfession,
    required Set<String> chatUserIds,
    required Set<String> requestedVacancyIds,
    required Set<String> blockedUserIds,
    int limit = 20,
    String? lastCreatedAt,
    String? lastKey,
  }) async {
    try {
      print('\n========================================');
      print('   BUSCANDO VAGAS');
      print('========================================');
      print('Filtros: ${filterState ?? "Todos"} / ${filterCity ?? "Todas"}');
      print('Profissao: ${preferredProfession ?? "Todas"}');
      print('Bloqueados: ${blockedUserIds.length}');

      final startTime = DateTime.now();
      int readsEstimated = 0;

      Query query = _database.child('vacancy').orderByChild('updated_at');

      if (lastCreatedAt != null && lastKey != null) {
        query = query.endBefore(lastCreatedAt, key: lastKey);
      }

      final multiplier = _calculateMultiplier(
        hasStateFilter: filterState != null,
        hasCityFilter: filterCity != null,
        hasProfessionFilter: preferredProfession != null,
      );
      final fetchLimit = limit * multiplier;
      query = query.limitToLast(fetchLimit);

      final snapshot = await query.get();
      readsEstimated = snapshot.exists ? snapshot.children.length : 0;

      if (!snapshot.exists) {
        print('Nenhuma vaga encontrada');
        _printReadStats(startTime, readsEstimated);
        return PaginatedFeedResult(items: [], hasMore: false);
      }

      final vacancies = <VacancyModel>[];
      String? newLastCreatedAt;
      String? newLastKey;

      for (var child in snapshot.children) {
        try {
          final key = child.key!;
          final data = Map<String, dynamic>.from(child.value as Map);
          final vacancy = _parseVacancy(key, data);

          // Status deve ser aberta
          final status = vacancy.status.toLowerCase();
          if (status != 'aberta' && status != 'open') continue;
          if (status == 'expirada' || status == 'expired') continue;

          // Já candidatado
          if (requestedVacancyIds.contains(vacancy.id)) continue;

          // ✅ Dono bloqueado — usa o set que vem do FeedController
          // que por sua vez buscou via fetchBlockedUserIds (corrigido)
          if (blockedUserIds.isNotEmpty &&
              vacancy.localId.isNotEmpty &&
              blockedUserIds.contains(vacancy.localId)) {
            print(
                '  Excluindo vaga ${vacancy.id} - dono bloqueado: ${vacancy.localId}');
            continue;
          }

          // Filtros de localização e profissão
          if (filterState != null &&
              filterState.isNotEmpty &&
              vacancy.state.toUpperCase() != filterState.toUpperCase())
            continue;

          if (filterCity != null &&
              filterCity.isNotEmpty &&
              vacancy.city.toLowerCase() != filterCity.toLowerCase()) continue;

          if (preferredProfession != null &&
              preferredProfession.isNotEmpty &&
              vacancy.profession.toLowerCase() !=
                  preferredProfession.toLowerCase()) continue;

          vacancies.add(vacancy);
          newLastCreatedAt = vacancy.createdAt;
          newLastKey = key;

          if (vacancies.length >= limit) break;
        } catch (e) {
          print('Erro ao parsear vaga: $e');
        }
      }

      vacancies.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final hasMore =
          snapshot.children.length >= fetchLimit && vacancies.length >= limit;

      _printReadStats(startTime, readsEstimated);
      print('${vacancies.length} vagas retornadas (de $readsEstimated lidas)');
      print('========================================\n');

      return PaginatedFeedResult(
        items: vacancies,
        hasMore: hasMore,
        lastCreatedAt: newLastCreatedAt,
        lastKey: newLastKey,
      );
    } catch (e, stack) {
      print('Erro ao buscar vagas: $e\n$stack');
      return PaginatedFeedResult(items: [], hasMore: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR PROFISSIONAIS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<PaginatedFeedResult<ProfessionalModel>> fetchProfessionalsForFeed({
    required String? filterState,
    required String? filterCity,
    required String? preferredProfession,
    required Set<String> chatUserIds,
    required Set<String> requestedProfessionalIds,
    required Set<String> blockedUserIds,
    int limit = 20,
    String? lastUpdatedAt,
    String? lastKey,
  }) async {
    try {
      print('\n========================================');
      print('   BUSCANDO PROFISSIONAIS');
      print('========================================');
      print('Filtros: ${filterState ?? "Todos"} / ${filterCity ?? "Todas"}');
      print('Bloqueados: ${blockedUserIds.length}');

      final startTime = DateTime.now();
      int readsEstimated = 0;

      Query query = _database.child('professionals').orderByChild('updated_at');

      if (lastUpdatedAt != null && lastKey != null) {
        query = query.endBefore(lastUpdatedAt, key: lastKey);
      }

      final multiplier = _calculateMultiplier(
        hasStateFilter: filterState != null,
        hasCityFilter: filterCity != null,
        hasProfessionFilter: preferredProfession != null,
      );
      final fetchLimit = limit * multiplier;
      query = query.limitToLast(fetchLimit);

      final snapshot = await query.get();
      readsEstimated = snapshot.exists ? snapshot.children.length : 0;

      if (!snapshot.exists) {
        print('Nenhum profissional encontrado');
        _printReadStats(startTime, readsEstimated);
        return PaginatedFeedResult(items: [], hasMore: false);
      }

      final professionals = <ProfessionalModel>[];
      String? newLastUpdatedAt;
      String? newLastKey;

      for (var child in snapshot.children) {
        try {
          final key = child.key!;
          final data = Map<String, dynamic>.from(child.value as Map);
          final prof = _parseProfessional(key, data);

          // Status ativo
          final status = prof.status.toLowerCase();
          if (status != 'active' && status != 'ativo') continue;
          if (status == 'expired') continue;

          // Já solicitado
          if (requestedProfessionalIds.contains(prof.id)) continue;

          // ✅ Profissional bloqueado
          if (blockedUserIds.isNotEmpty &&
              prof.localId.isNotEmpty &&
              blockedUserIds.contains(prof.localId)) {
            print(
                '  Excluindo profissional ${prof.id} - bloqueado: ${prof.localId}');
            continue;
          }

          // Filtros
          if (filterState != null &&
              filterState.isNotEmpty &&
              prof.state.toUpperCase() != filterState.toUpperCase()) continue;

          if (filterCity != null &&
              filterCity.isNotEmpty &&
              prof.city.toLowerCase() != filterCity.toLowerCase()) continue;

          if (preferredProfession != null &&
              preferredProfession.isNotEmpty &&
              prof.profession.toLowerCase() !=
                  preferredProfession.toLowerCase()) continue;

          professionals.add(prof);
          newLastUpdatedAt = prof.updatedAt;
          newLastKey = key;

          if (professionals.length >= limit) break;
        } catch (e) {
          print('Erro ao parsear profissional: $e');
        }
      }

      professionals.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

      final hasMore = snapshot.children.length >= fetchLimit &&
          professionals.length >= limit;

      _printReadStats(startTime, readsEstimated);
      print(
          '${professionals.length} profissionais retornados (de $readsEstimated lidos)');
      print('========================================\n');

      return PaginatedFeedResult(
        items: professionals,
        hasMore: hasMore,
        lastUpdatedAt: newLastUpdatedAt,
        lastKey: newLastKey,
      );
    } catch (e, stack) {
      print('Erro ao buscar profissionais: $e\n$stack');
      return PaginatedFeedResult(items: [], hasMore: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR IDs BLOQUEADOS
  //
  // CORREÇÃO CRÍTICA para o iOS:
  //
  // Estrutura no Firebase:
  //   Users/MEU_ID/blocked_users = { ID_BLOQUEADO_1: true, ID_BLOQUEADO_2: true }
  //
  // Bug anterior: pegava os VALUES ("true" ou 1 no iOS)
  //   blockedIds = {"true"} ou {"1"} — nunca batia com um userId real
  //
  // Correção: pegar as KEYS que são os IDs dos usuários bloqueados
  //   blockedIds = {"ID_BLOQUEADO_1", "ID_BLOQUEADO_2"} — correto
  // ═══════════════════════════════════════════════════════════════════════════
  Future<Set<String>> fetchBlockedUserIds() async {
    if (_currentUserId == null) return {};
    try {
      final ref = FirebaseDatabase.instance.ref();

      // Lê ambos os nós via onValue (evita cache iOS)
      Future<Set<String>> readViaListener(String path) async {
        final completer = Completer<Set<String>>();
        late StreamSubscription<DatabaseEvent> sub;
        sub = ref.child(path).onValue.listen(
          (event) {
            if (completer.isCompleted) return;
            final value = event.snapshot.value;
            if (value is! Map) {
              completer.complete({});
              sub.cancel();
              return;
            }
            final ids = value.entries
                .where((e) {
                  final v = e.value;
                  return v == true || v == 1 || v == 'true' || v == '1';
                })
                .map((e) => e.key.toString())
                .toSet();
            completer.complete(ids);
            sub.cancel();
          },
          onError: (_) {
            if (!completer.isCompleted) {
              completer.complete({});
              sub.cancel();
            }
          },
        );
        return completer.future.timeout(const Duration(seconds: 10),
            onTimeout: () {
          sub.cancel();
          return {};
        });
      }

      final results = await Future.wait([
        readViaListener('Users/$_currentUserId/blocked_users'),
        readViaListener('blocked_by/$_currentUserId'),
      ]);

      final all = {...results[0], ...results[1]};
      print(
          '✅ fetchBlockedUserIds: ${all.length} bloqueados (iBlockedThem: ${results[0].length}, blockedMe: ${results[1].length})');
      return all;
    } catch (e) {
      print('❌ fetchBlockedUserIds: $e');
      return {};
    }
  }
  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR VAGAS CANDIDATADAS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Set<String>> fetchRequestedVacancyIds() async {
    if (_currentUserId == null) return {};

    try {
      print('Buscando vagas candidatadas...');
      final startTime = DateTime.now();

      // Tenta o caminho otimizado primeiro
      final userRequestsSnapshot = await _database
          .child('user_requests/$_currentUserId/vacancies')
          .get();

      if (userRequestsSnapshot.exists && userRequestsSnapshot.value != null) {
        final data = userRequestsSnapshot.value;
        final requestedIds = <String>{};

        if (data is Map) {
          requestedIds.addAll(data.keys.map((k) => k.toString()));
        } else if (data is List) {
          for (var item in data) {
            if (item != null) requestedIds.add(item.toString());
          }
        }

        final duration = DateTime.now().difference(startTime);
        print(
            '${requestedIds.length} candidaturas (otimizado) em ${duration.inMilliseconds}ms');
        return requestedIds;
      }

      // Fallback: varre todas as vagas
      final snapshot = await _database
          .child('vacancy')
          .orderByChild('status')
          .equalTo('Aberta')
          .get();

      final requestedIds = <String>{};

      if (snapshot.exists) {
        for (var child in snapshot.children) {
          final requests = child.child('requests').value;
          if (requests is List && requests.contains(_currentUserId)) {
            requestedIds.add(child.key!);
          } else if (requests is Map && requests.containsKey(_currentUserId)) {
            requestedIds.add(child.key!);
          }
        }
      }

      final duration = DateTime.now().difference(startTime);
      print(
          '${requestedIds.length} candidaturas (fallback) em ${duration.inMilliseconds}ms');
      return requestedIds;
    } catch (e) {
      print('Erro ao buscar candidaturas: $e');
      return {};
    }
  }

  Future<Set<String>> fetchRequestedProfessionalIds() async {
    if (_currentUserId == null) return {};

    try {
      print('Buscando requests de profissionais...');
      final startTime = DateTime.now();

      final userRequestsSnapshot = await _database
          .child('user_requests/$_currentUserId/professionals')
          .get();

      if (userRequestsSnapshot.exists && userRequestsSnapshot.value != null) {
        final data = userRequestsSnapshot.value;
        final requestedIds = <String>{};

        if (data is Map) {
          requestedIds.addAll(data.keys.map((k) => k.toString()));
        } else if (data is List) {
          for (var item in data) {
            if (item != null) requestedIds.add(item.toString());
          }
        }

        final duration = DateTime.now().difference(startTime);
        print(
            '${requestedIds.length} requests profissionais (otimizado) em ${duration.inMilliseconds}ms');
        return requestedIds;
      }

      // Fallback
      final snapshot = await _database
          .child('professionals')
          .orderByChild('status')
          .equalTo('active')
          .get();

      final requestedIds = <String>{};

      if (snapshot.exists) {
        for (var child in snapshot.children) {
          final requests = child.child('requests').value;
          final localId = child.child('local_id').value?.toString();
          if (localId == null) continue;

          if (requests is List && requests.contains(_currentUserId)) {
            requestedIds.add(localId);
          } else if (requests is Map && requests.containsKey(_currentUserId)) {
            requestedIds.add(localId);
          }
        }
      }

      final duration = DateTime.now().difference(startTime);
      print(
          '${requestedIds.length} requests profissionais (fallback) em ${duration.inMilliseconds}ms');
      return requestedIds;
    } catch (e) {
      print('Erro ao buscar requests de profissionais: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR CHATS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Set<String>> fetchChatUserIds() async {
    if (_currentUserId == null) return {};

    try {
      print('Buscando chats...');
      final startTime = DateTime.now();
      final chatUserIds = <String>{};

      final contractorSnapshot = await _database
          .child('Chats')
          .orderByChild('contractor')
          .equalTo(_currentUserId)
          .get();

      if (contractorSnapshot.exists) {
        for (var child in contractorSnapshot.children) {
          final employee = child.child('employee').value?.toString();
          if (employee != null && employee.isNotEmpty) {
            chatUserIds.add(employee);
          }
        }
      }

      final employeeSnapshot = await _database
          .child('Chats')
          .orderByChild('employee')
          .equalTo(_currentUserId)
          .get();

      if (employeeSnapshot.exists) {
        for (var child in employeeSnapshot.children) {
          final contractor = child.child('contractor').value?.toString();
          if (contractor != null && contractor.isNotEmpty) {
            chatUserIds.add(contractor);
          }
        }
      }

      final duration = DateTime.now().difference(startTime);
      print('${chatUserIds.length} chats em ${duration.inMilliseconds}ms');
      return chatUserIds;
    } catch (e) {
      print('Erro ao buscar chats: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════════

  int _calculateMultiplier({
    bool hasStateFilter = false,
    bool hasCityFilter = false,
    bool hasProfessionFilter = false,
  }) {
    int multiplier = 1;
    if (hasStateFilter) multiplier += 1;
    if (hasCityFilter) multiplier += 1;
    if (hasProfessionFilter) multiplier += 1;
    return multiplier.clamp(2, 6);
  }

  VacancyModel _parseVacancy(String key, Map<String, dynamic> data) {
    return VacancyModel(
      id: key,
      city: data['city'] ?? '',
      company: data['company'] ?? data['company_name'] ?? '',
      createdAt: data['created_at'] ?? '',
      description: data['description'] ?? '',
      emailContact: data['email_contact'] ?? '',
      images: _extractImages(data),
      legalType: data['legal_type'] ?? '',
      localId: data['local_id'] ?? '',
      phoneContact: data['phone_contact'] ?? '',
      profession: data['profession'] ?? '',
      salary: data['salary'] ?? '',
      salaryType: data['salary_type'] ?? '',
      state: data['state'] ?? '',
      status: data['status'] ?? '',
      title: data['title'] ?? '',
      type: data['type'] ?? '',
      updatedAt: data['updated_at'] ?? data['created_at'] ?? '',
      expiresAt: data['expires_at']?.toString() ?? '',
    );
  }

  ProfessionalModel _parseProfessional(String key, Map<String, dynamic> data) {
    return ProfessionalModel(
      id: key,
      avatar: data['avatar'] ?? '',
      city: data['city'] ?? '',
      company: data['company'] ?? '',
      createdAt: data['created_at'] ?? '',
      legalType: data['legal_type'] ?? '',
      localId: data['local_id'] ?? '',
      name: data['name'] ?? '',
      profession: data['profession'] ?? '',
      skills: _extractSkills(data),
      state: data['state'] ?? '',
      status: data['status'] ?? '',
      summary: data['summary'] ?? '',
      email: data['email']?.toString() ?? '',
      telefone: data['telefone']?.toString() ?? '',
      type: data['type'] ?? '',
      updatedAt: data['updated_at'] ?? data['created_at'] ?? '',
      expiresAt: data['expires_at']?.toString() ?? '',
    );
  }

  List<String> _extractImages(Map<String, dynamic> data) {
    if (data.containsKey('midia') && data['midia'] is Map) {
      final midia = data['midia'] as Map;
      if (midia.containsKey('images') && midia['images'] is List) {
        return List<String>.from(midia['images']);
      }
    }
    if (data.containsKey('images') && data['images'] is List) {
      return List<String>.from(data['images']);
    }
    return [];
  }

  List<String> _extractSkills(Map<String, dynamic> data) {
    if (data.containsKey('skills') && data['skills'] is List) {
      return List<String>.from(data['skills']);
    }
    return [];
  }

  void _printReadStats(DateTime startTime, int reads) {
    final duration = DateTime.now().difference(startTime);
    final cost = reads * 0.00036;
    print(
        'Stats: ${duration.inMilliseconds}ms | $reads reads | \$${cost.toStringAsFixed(6)}');
    if (reads > 50)
      print('⚠️ Muitos reads — considere mais filtros server-side');
    if (duration.inMilliseconds > 2000)
      print('⚠️ Query lenta — verifique índices');
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// RESULTADO PAGINADO
// ═══════════════════════════════════════════════════════════════════════════
class PaginatedFeedResult<T> {
  final List<T> items;
  final bool hasMore;
  final String? lastCreatedAt;
  final String? lastUpdatedAt;
  final String? lastKey;

  PaginatedFeedResult({
    required this.items,
    required this.hasMore,
    this.lastCreatedAt,
    this.lastUpdatedAt,
    this.lastKey,
  });
}
