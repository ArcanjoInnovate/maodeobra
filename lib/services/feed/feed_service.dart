import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseFeedService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR VAGAS — server-side filter por status
  // ═══════════════════════════════════════════════════════════════════════════

  Future<PaginatedFeedResult<VacancyModel>> fetchVacanciesForFeed({
    required String? filterState,
    required String? filterCity,
    required String? preferredProfession,
    required Set<String> requestedVacancyIds,
    required Set<String> blockedUserIds,
    int limit = 20,
    String? lastCreatedAt,
    String? lastKey,
  }) async {
    try {
      // ✅ Server-side: busca apenas vagas 'Aberta' via índice
      Query query = _database
          .child('vacancy')
          .orderByChild('status')
          .equalTo('Aberta');

      // ✅ Busca exatamente o necessário — sem multiplicador
      query = query.limitToLast(limit * 2); // 2x mínimo para folga de bloqueados

      final snapshot = await query.get();

      if (!snapshot.exists) {
        return PaginatedFeedResult(items: [], hasMore: false);
      }

      final vacancies = <VacancyModel>[];
      String? newLastCreatedAt;
      String? newLastKey;

      // Ordenar por updated_at desc client-side (só nos itens já filtrados pelo server)
      final children = snapshot.children.toList();
      children.sort((a, b) {
        final aVal = (a.value as Map?)?['updated_at'] ?? '';
        final bVal = (b.value as Map?)?['updated_at'] ?? '';
        return bVal.compareTo(aVal);
      });

      // Paginação cursor
      bool pastCursor = lastKey == null;

      for (var child in children) {
        final key = child.key!;

        if (!pastCursor) {
          if (key == lastKey) pastCursor = true;
          continue;
        }

        try {
          final data = Map<String, dynamic>.from(child.value as Map);
          final vacancy = _parseVacancy(key, data);

          // Já candidatado
          if (requestedVacancyIds.contains(vacancy.id)) continue;

          // Dono bloqueado
          if (blockedUserIds.isNotEmpty &&
              vacancy.localId.isNotEmpty &&
              blockedUserIds.contains(vacancy.localId)) continue;

          // Filtros client-side apenas para localização/profissão
          if (filterState != null &&
              filterState.isNotEmpty &&
              vacancy.state.toUpperCase() != filterState.toUpperCase()) continue;

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
          debugPrint('Erro ao parsear vaga: $e');
        }
      }

      final hasMore = vacancies.length >= limit;

      return PaginatedFeedResult(
        items: vacancies,
        hasMore: hasMore,
        lastCreatedAt: newLastCreatedAt,
        lastKey: newLastKey,
      );
    } catch (e, stack) {
      debugPrint('Erro ao buscar vagas: $e\n$stack');
      return PaginatedFeedResult(items: [], hasMore: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR PROFISSIONAIS — server-side filter por status
  // ═══════════════════════════════════════════════════════════════════════════

  Future<PaginatedFeedResult<ProfessionalModel>> fetchProfessionalsForFeed({
    required String? filterState,
    required String? filterCity,
    required String? preferredProfession,
    required Set<String> requestedProfessionalIds,
    required Set<String> blockedUserIds,
    int limit = 20,
    String? lastUpdatedAt,
    String? lastKey,
  }) async {
    try {
      // ✅ Server-side: busca apenas profissionais 'active' via índice
      Query query = _database
          .child('professionals')
          .orderByChild('status')
          .equalTo('active');

      query = query.limitToLast(limit * 2);

      final snapshot = await query.get();

      if (!snapshot.exists) {
        return PaginatedFeedResult(items: [], hasMore: false);
      }

      final professionals = <ProfessionalModel>[];
      String? newLastUpdatedAt;
      String? newLastKey;

      final children = snapshot.children.toList();
      children.sort((a, b) {
        final aVal = (a.value as Map?)?['updated_at'] ?? '';
        final bVal = (b.value as Map?)?['updated_at'] ?? '';
        return bVal.compareTo(aVal);
      });

      bool pastCursor = lastKey == null;

      for (var child in children) {
        final key = child.key!;

        if (!pastCursor) {
          if (key == lastKey) pastCursor = true;
          continue;
        }

        try {
          final data = Map<String, dynamic>.from(child.value as Map);
          final prof = _parseProfessional(key, data);

          // Já solicitado
          if (requestedProfessionalIds.contains(prof.id)) continue;

          // Bloqueado
          if (blockedUserIds.isNotEmpty &&
              prof.localId.isNotEmpty &&
              blockedUserIds.contains(prof.localId)) continue;

          // Filtros localização/profissão
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
          debugPrint('Erro ao parsear profissional: $e');
        }
      }

      final hasMore = professionals.length >= limit;

      return PaginatedFeedResult(
        items: professionals,
        hasMore: hasMore,
        lastUpdatedAt: newLastUpdatedAt,
        lastKey: newLastKey,
      );
    } catch (e, stack) {
      debugPrint('Erro ao buscar profissionais: $e\n$stack');
      return PaginatedFeedResult(items: [], hasMore: false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR IDs BLOQUEADOS
  // ═══════════════════════════════════════════════════════════════════════════
  Future<Set<String>> fetchBlockedUserIds() async {
    if (_currentUserId == null) return {};
    try {
      final ref = FirebaseDatabase.instance.ref();

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
      debugPrint(
          '✅ fetchBlockedUserIds: ${all.length} bloqueados');
      return all;
    } catch (e) {
      debugPrint('❌ fetchBlockedUserIds: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // BUSCAR VAGAS CANDIDATADAS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Set<String>> fetchRequestedVacancyIds() async {
    if (_currentUserId == null) return {};

    try {
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
        return requestedIds;
      }

      // Fallback
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

      return requestedIds;
    } catch (e) {
      debugPrint('Erro ao buscar candidaturas: $e');
      return {};
    }
  }

  Future<Set<String>> fetchRequestedProfessionalIds() async {
    if (_currentUserId == null) return {};

    try {
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

      return requestedIds;
    } catch (e) {
      debugPrint('Erro ao buscar requests de profissionais: $e');
      return {};
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPERS PRIVADOS
  // ═══════════════════════════════════════════════════════════════════════════

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