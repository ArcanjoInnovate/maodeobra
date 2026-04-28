import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/search/vacancy_model.dart';


import 'package:dartobra_new/services/expiration/expiration_service.dart';

class FirebaseSearchServiceServerPaginated {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final ExpirationService _expirationService = ExpirationService();

  Future<PaginatedResult<VacancyModel>> fetchVacanciesPaginated({
    int limit = 20,
    String? endAtKey,
    dynamic endAtValue,
  }) async {
    try {
      final startTime = DateTime.now();
      int readsEstimated = 0;

      Query query = _database
          .child('vacancy')
          .orderByChild('created_at');

      if (endAtValue != null) {
        query = query.endBefore(endAtValue);
      }

      final fetchLimit = limit * 2;
      
      query = query.limitToLast(fetchLimit);

      final snapshot = await query.get();
      readsEstimated = snapshot.exists ? snapshot.children.length : 0;

      if (!snapshot.exists) {
        print('Nenhuma vaga encontrada');
        _printReadStats(startTime, readsEstimated);
        return PaginatedResult(items: [], hasMore: false, lastKey: null, lastValue: null);
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      final sortedEntries = data.entries.toList()
        ..sort((a, b) {
          final aCreated = a.value['created_at'] ?? '';
          final bCreated = b.value['created_at'] ?? '';
          return bCreated.compareTo(aCreated);
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
          
          // FILTRO 1: Status deve ser "aberta"
          final status = vacancy.status.toLowerCase();
          if (status != 'aberta' && status != 'open') {
            continue;
          }
          
          // FILTRO 2: NAO EXPIRADA
          final expiresAt = vacancy.expiresAt;
          if (expiresAt.isNotEmpty && _expirationService.isExpired(expiresAt)) {
            print('  Vaga $key EXCLUIDA NO SERVIDOR - expirada: $expiresAt');
            continue;
          }
          
          // REMOVIDO: Filtro de chat - vagas com chat existente NAO sao mais bloqueadas

          // PASSOU EM TODOS OS FILTROS!
          vacancies.add(vacancy);
          newLastKey = key;
          newLastValue = value['created_at'];
          
        } catch (e) {
          print('Erro ao parsear vaga $key: $e');
        }
      }

      final hasMore = sortedEntries.length >= fetchLimit && vacancies.length >= limit;

      _printReadStats(startTime, readsEstimated);
      print('${vacancies.length} vagas validas retornadas (de $readsEstimated lidas)');

      return PaginatedResult(
        items: vacancies,
        hasMore: hasMore,
        lastKey: newLastKey,
        lastValue: newLastValue,
      );

    } catch (e, stack) {
      print('Erro ao buscar vagas: $e');
      print('Stack: $stack');
      return PaginatedResult(items: [], hasMore: false, lastKey: null, lastValue: null);
    }
  }

  // ===============================
  // BUSCAR PROFISSIONAIS COM PAGINACAO
  // ===============================
  Future<PaginatedResult<ProfessionalModel>> fetchProfessionalsPaginated({
    int limit = 20,
    String? endAtKey,
    dynamic endAtValue,
  }) async {
    try {
      
      final startTime = DateTime.now();
      int readsEstimated = 0;

      Query query = _database
          .child('professionals')
          .orderByChild('updated_at');

      if (endAtValue != null) {
        query = query.endBefore(endAtValue);
      }

      final fetchLimit = limit * 2;
      
      query = query.limitToLast(fetchLimit);

      final snapshot = await query.get();
      readsEstimated = snapshot.exists ? snapshot.children.length : 0;

      if (!snapshot.exists) {
        print('Nenhum profissional encontrado');
        _printReadStats(startTime, readsEstimated);
        return PaginatedResult(
          items: [],
          hasMore: false,
          lastKey: null,
          lastValue: null,
        );
      }

      final data = snapshot.value as Map<dynamic, dynamic>;
      
      final sortedEntries = data.entries.toList()
        ..sort((a, b) {
          final aUpdated = a.value['updated_at'] ?? '';
          final bUpdated = b.value['updated_at'] ?? '';
          return bUpdated.compareTo(aUpdated);
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
          
          // FILTRO 1: Apenas profissionais "ativos" (exclui 'paused')
          final status = prof.status.toLowerCase();
          if (status != 'active' && status != 'ativo') {
            print('  Excluindo profissional ${prof.id} - status: $status');
            continue;
          }
          
          // REMOVIDO: Filtro de chat - profissionais com chat existente NAO sao mais bloqueados

          // PASSOU!
          professionals.add(prof);
          newLastKey = key;
          newLastValue = value['updated_at'];
          
        } catch (e) {
          print('Erro ao parsear profissional $key: $e');
        }
      }

      final hasMore = sortedEntries.length >= fetchLimit && professionals.length >= limit;

      _printReadStats(startTime, readsEstimated);
      print('${professionals.length} profissionais retornados (de $readsEstimated lidos)');
      print('Taxa aprovacao: ${(professionals.length / readsEstimated * 100).toStringAsFixed(1)}%');
      print('Tem mais: $hasMore');
      print('========================================\n');

      return PaginatedResult(
        items: professionals,
        hasMore: hasMore,
        lastKey: newLastKey,
        lastValue: newLastValue,
      );

    } catch (e, stack) {
      print('Erro ao buscar profissionais: $e');
      return PaginatedResult(
        items: [],
        hasMore: false,
        lastKey: null,
        lastValue: null,
      );
    }
  }

  // ===============================
  // BUSCAR REQUESTS - OTIMIZADO
  // ===============================
  Future<Set<String>> fetchRequestedVacancyIds() async {
    try {
      if (_currentUserId == null) {
        print('Usuario nao autenticado');
        return {};
      }

      print('Buscando vagas ja solicitadas');
      final startTime = DateTime.now();

      final snapshot = await _database
          .child('vacancy')
          .orderByChild('status')
          .equalTo('Aberta')
          .get();

      if (!snapshot.exists) {
        return {};
      }

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

      final duration = DateTime.now().difference(startTime);
      print('${requestedVacancies.length} vagas ja solicitadas em ${duration.inMilliseconds}ms');

      return requestedVacancies;

    } catch (e) {
      print('Erro ao buscar requests de vagas: $e');
      return {};
    }
  }

  Future<Set<String>> fetchRequestedProfessionalIds() async {
    try {
      if (_currentUserId == null) {
        return {};
      }

      print('Buscando profissionais ja solicitados');
      final startTime = DateTime.now();

      final snapshot = await _database
          .child('professionals')
          .orderByChild('status')
          .equalTo('active')
          .get();

      if (!snapshot.exists) {
        return {};
      }

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

      final duration = DateTime.now().difference(startTime);
      print('${requestedProfessionals.length} profissionais ja solicitados em ${duration.inMilliseconds}ms');

      return requestedProfessionals;

    } catch (e) {
      print('Erro ao buscar requests de profissionais: $e');
      return {};
    }
  }

  // ===============================
  // SOLICITAR CHAT (COM TRANSACAO)
  // ===============================
  Future<bool> requestProfessionalChat(String professionalId) async {
    try {
      if (_currentUserId == null) {
        print('Usuario nao autenticado');
        return false;
      }

      print('Solicitando chat com profissional: $professionalId');

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
        print('Solicitacao enviada com sucesso');
        return true;
      } else {
        print('Solicitacao ja existe');
        return false;
      }

    } catch (e) {
      print('Erro ao solicitar chat: $e');
      return false;
    }
  }

  Future<bool> requestVacancyChat(String vacancyId) async {
    try {
      if (_currentUserId == null) {
        print('Usuario nao autenticado');
        return false;
      }

      print('Candidatando-se a vaga: $vacancyId');

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
        print('Candidatura enviada com sucesso');
        return true;
      } else {
        print('Candidatura ja existe');
        return false;
      }

    } catch (e) {
      print('Erro ao candidatar: $e');
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

      if (requests is List) {
        return requests.contains(_currentUserId);
      } else if (requests is Map) {
        return requests.containsKey(_currentUserId);
      }

      return false;
    } catch (e) {
      print('Erro ao verificar request: $e');
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

      if (requests is List) {
        return requests.contains(_currentUserId);
      } else if (requests is Map) {
        return requests.containsKey(_currentUserId);
      }

      return false;
    } catch (e) {
      print('Erro ao verificar request: $e');
      return false;
    }
  }

  // ===============================
  // HELPERS PRIVADOS
  // ===============================

  void _printReadStats(DateTime startTime, int reads) {
    final duration = DateTime.now().difference(startTime);
    final cost = reads * 0.00036;
    
    print('Estatisticas:');
    print('   Tempo: ${duration.inMilliseconds}ms');
    print('   Reads: $reads');
    print('   Custo: \$${cost.toStringAsFixed(6)}');
    
    if (reads > 50) {
      print('   ALERTA: Muitos reads! Considere mais filtros server-side');
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
