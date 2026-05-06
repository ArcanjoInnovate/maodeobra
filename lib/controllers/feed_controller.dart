import 'package:dartobra_new/core/controllers/user_relationship_controller.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:dartobra_new/services/feed/feed_service.dart';
import 'package:dartobra_new/services/search/ibge_service.dart';

enum FeedMode { worker, contractor, unified }

class FeedController with ChangeNotifier {
  final FirebaseFeedService _feedService = FirebaseFeedService();
  String? _currentUserId;
  final IBGEService _ibgeService = IBGEService();
  final UserRelationShipController _userController =
      UserRelationShipController();
  final ExpirationService _expirationService = ExpirationService();

  // ✅ CORREÇÃO PRINCIPAL: campo que persiste os bloqueados
  // Antes não existia — o set era criado localmente e descartado logo depois
  Set<String> _blockedUserIds = {};

  FeedMode _feedMode = FeedMode.unified;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _loadingCities = false;

  List<VacancyModel> _allVacancies = [];
  List<ProfessionalModel> _allProfessionals = [];
  List<VacancyModel> _filteredVacancies = [];

  Set<String> _requestedVacancyIds = {};
  Set<String> _requestedProfessionalIds = {};
  Set<String> _chatUserIds = {};
  bool _requestsLoaded = false;
  bool _chatsLoaded = false;

  String? _filterState;
  String? _filterCity;
  String? _preferredProfession;
  String _searchQuery = '';

  bool _hasMoreVacancies = true;
  bool _hasMoreProfessionals = true;
  String? _lastCreatedAt;
  String? _lastUpdatedAt;
  String? _lastVacancyKey;
  String? _lastProfessionalKey;

  List<Estado> _availableStates = [];
  List<Cidade> _availableCities = [];

  // ── Getters ──────────────────────────────────────────────────────────────

  FeedMode get feedMode => _feedMode;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get loadingCities => _loadingCities;
  bool get hasMore => _hasMoreVacancies || _hasMoreProfessionals;
  String? get filterState => _filterState;
  String? get filterCity => _filterCity;
  String? get preferredProfession => _preferredProfession;
  String get searchQuery => _searchQuery;
  List<Estado> get availableStates => _availableStates;
  List<Cidade> get availableCities => _availableCities;
  List<VacancyModel> get filteredVacancies => _filteredVacancies;

  // ✅ CORREÇÃO: getter agora filtra bloqueados da memória também
  // Antes: filtrava só requests — bloqueados passavam direto
  List<ProfessionalModel> get filteredProfessionals =>
      _allProfessionals.where((p) {
        // ← NOVO: remove da memória quem está bloqueado
        if (_blockedUserIds.isNotEmpty &&
            p.localId.isNotEmpty &&
            _blockedUserIds.contains(p.localId)) return false;

        if (_currentUserId != null && p.localId == _currentUserId) return true;
        if (_requestsLoaded && _requestedProfessionalIds.contains(p.localId)) {
          return false;
        }
        return true;
      }).toList();

  List<dynamic> get unifiedFeed {
    final List<dynamic> combined = [];
    final vacancies = filteredVacancies;
    final professionals = filteredProfessionals;
    int vi = 0, pi = 0;
    while (vi < vacancies.length || pi < professionals.length) {
      if (vi < vacancies.length) combined.add(vacancies[vi++]);
      if (pi < professionals.length) combined.add(professionals[pi++]);
    }
    return combined;
  }

  String get feedStats {
    final total = _allVacancies.length + _allProfessionals.length;
    return '$total itens disponiveis';
  }

  bool get hasActiveFilters =>
      _filterState != null ||
      _filterCity != null ||
      _preferredProfession != null ||
      _searchQuery.isNotEmpty;

  bool hasRequestedVacancy(String vacancyId) =>
      _requestedVacancyIds.contains(vacancyId);

  bool hasRequestedProfessional(String professionalLocalId) =>
      _requestedProfessionalIds.contains(professionalLocalId);

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> initialize({
    required FeedMode mode,
    String? initialState,
    String? initialCity,
    String? preferredProfession,
  }) async {
    print('\n========================================');
    print('   INICIALIZANDO FEED CONTROLLER UNIFICADO');
    print('========================================');
    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _feedMode = FeedMode.unified;
    _filterState = initialState;
    _filterCity = initialCity;
    _preferredProfession = preferredProfession;
    _isLoading = true;
    notifyListeners();

    try {
      await _loadStates();
      if (initialState != null) await _loadCities(initialState);

      // ✅ carrega e SALVA no campo _blockedUserIds
      if (_currentUserId != null) {
        // tenta até 3x com intervalo — iOS pode demorar mais
        for (int i = 0; i < 3; i++) {
          final list =
              await _userController.fetchAllBlockedUsers(_currentUserId!);
          if (list.isNotEmpty || i == 2) {
            _blockedUserIds = list.toSet();
            break;
          }
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      await _loadBlockedUsers();

      await _loadChats();
      await _loadInitialFeed();
      await _applyFilters();

      print('Feed inicializado! Bloqueados: ${_blockedUserIds.length}');
    } catch (e, stack) {
      print('Erro ao inicializar feed: $e\nStack: $stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ✅ NOVO: método dedicado para carregar e persistir bloqueados
  // Centraliza num lugar só — não esquece de salvar nunca mais
  // ✅ CORREÇÃO: não sobrescreve, apenas adiciona novos bloqueados
  Future<void> _loadBlockedUsers() async {
    if (_currentUserId == null) return;
    try {
      final list = await _userController.fetchAllBlockedUsers(_currentUserId!);
      // ✅ Mescla com o set existente em vez de sobrescrever
      _blockedUserIds = {..._blockedUserIds, ...list};
      print('✅ _blockedUserIds atualizado: ${_blockedUserIds.length}');
    } catch (e) {
      print('❌ Erro ao carregar bloqueados: $e');
      // ✅ NÃO zera se der erro — mantém o estado atual
    }
  }

  void addBlockedUser(String userId) {
    if (userId.isEmpty) return;
    _blockedUserIds = {..._blockedUserIds, userId};
    _applyFilters(); // já chama notifyListeners() internamente
  }
  // ── Estados / Cidades ─────────────────────────────────────────────────────

  Future<void> _loadStates() async {
    try {
      _availableStates = await _ibgeService.getEstados();
    } catch (e) {
      _availableStates = [];
    }
  }

  Future<void> _loadCities(String uf) async {
    if (uf.isEmpty) {
      _availableCities = [];
      return;
    }
    _loadingCities = true;
    notifyListeners();
    try {
      _availableCities = await _ibgeService.getCidadesPorEstado(uf);
    } catch (e) {
      _availableCities = [];
    } finally {
      _loadingCities = false;
      notifyListeners();
    }
  }

  // ── Chats ─────────────────────────────────────────────────────────────────

  Future<void> _loadChats() async {
    if (_chatsLoaded) return;
    try {
      _chatUserIds = await _feedService.fetchChatUserIds();
      _chatsLoaded = true;
    } catch (e) {
      _chatUserIds = {};
    }
  }

  // ── Requests (lazy) ───────────────────────────────────────────────────────

  Future<void> ensureRequestsLoaded() async {
    if (_requestsLoaded) return;
    try {
      _requestedVacancyIds = await _feedService.fetchRequestedVacancyIds();
      _requestedProfessionalIds =
          await _feedService.fetchRequestedProfessionalIds();
      _requestsLoaded = true;
      notifyListeners();
    } catch (e) {
      print('Erro ao carregar requests: $e');
    }
  }

  // ── Feed inicial ──────────────────────────────────────────────────────────

  Future<void> _loadInitialFeed() async {
    _allVacancies = [];
    _allProfessionals = [];
    _lastCreatedAt = null;
    _lastUpdatedAt = null;
    _lastVacancyKey = null;
    _lastProfessionalKey = null;
    _hasMoreVacancies = true;
    _hasMoreProfessionals = true;
    await _loadMoreItems();
  }

  // ── Paginação ─────────────────────────────────────────────────────────────

  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !hasMore) return;
    await _loadMoreItems();
  }

  Future<void> _loadMoreItems() async {
    _isLoadingMore = true;
    notifyListeners();

    try {
      print('\nCarregando mais itens...');
      print('   Bloqueados: ${_blockedUserIds.length}');

      // ✅ CORREÇÃO: usa _blockedUserIds do campo, não busca do Firebase de novo
      // Antes: chamava fetchAllBlockedUsers() duas vezes, jogava fora o resultado
      // e _applyFilters nunca sabia quem estava bloqueado
      if (_hasMoreVacancies) {
        final resultV = await _feedService.fetchVacanciesForFeed(
          blockedUserIds: _blockedUserIds,
          filterState: _filterState,
          filterCity: _filterCity,
          preferredProfession: _preferredProfession,
          chatUserIds: _chatUserIds,
          requestedVacancyIds: _requestedVacancyIds,
          limit: 15,
          lastCreatedAt: _lastCreatedAt,
          lastKey: _lastVacancyKey,
        );
        _allVacancies.addAll(resultV.items);
        _lastCreatedAt = resultV.lastCreatedAt;
        _lastVacancyKey = resultV.lastKey;
        _hasMoreVacancies = resultV.hasMore;
        print('   ${resultV.items.length} vagas carregadas');
      }

      if (_hasMoreProfessionals) {
        final resultP = await _feedService.fetchProfessionalsForFeed(
          filterState: _filterState,
          blockedUserIds: _blockedUserIds,
          filterCity: _filterCity,
          preferredProfession: _preferredProfession,
          chatUserIds: _chatUserIds,
          requestedProfessionalIds: _requestedProfessionalIds,
          limit: 15,
          lastUpdatedAt: _lastUpdatedAt,
          lastKey: _lastProfessionalKey,
        );
        _allProfessionals.addAll(resultP.items);
        _lastUpdatedAt = resultP.lastUpdatedAt;
        _lastProfessionalKey = resultP.lastKey;
        _hasMoreProfessionals = resultP.hasMore;
        print('   ${resultP.items.length} profissionais carregados');
      }

      print(
          '   Total: ${_allVacancies.length} vagas, ${_allProfessionals.length} profissionais');

      await _applyFilters();
    } catch (e) {
      print('Erro ao carregar mais itens: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  bool _matchesVacancy(VacancyModel vacancy, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return vacancy.title.toLowerCase().contains(q) ||
        vacancy.profession.toLowerCase().contains(q) ||
        vacancy.description.toLowerCase().contains(q);
  }

  Future<void> _applyFilters() async {
    print('DEBUG - Vagas na memória: ${_allVacancies.length}');
    print('DEBUG - Bloqueados no filtro: ${_blockedUserIds.length}');

    await ensureRequestsLoaded();
    await _loadChats();

    _filteredVacancies = _allVacancies.where((vac) {
      // ✅ CORREÇÃO: filtra bloqueados que já estão na memória
      // Antes: este bloco não existia — server-side filtrava mas memória não
      if (_blockedUserIds.isNotEmpty &&
          vac.localId.isNotEmpty &&
          _blockedUserIds.contains(vac.localId)) return false;

      if (_requestsLoaded && _requestedVacancyIds.contains(vac.id)) {
        return false;
      }

      final statusLower = vac.status.toLowerCase();
      if (statusLower == 'expirada' || statusLower == 'pausada') return false;

      if (vac.expiresAt.isNotEmpty &&
          _expirationService.isExpired(vac.expiresAt)) return false;

      if (!_matchesVacancy(vac, _searchQuery)) return false;

      if (_filterState != null &&
          _filterState!.isNotEmpty &&
          vac.state != _filterState) return false;

      if (_filterCity != null &&
          _filterCity!.isNotEmpty &&
          vac.city != _filterCity) return false;

      if (_preferredProfession != null &&
          _preferredProfession!.isNotEmpty &&
          vac.profession != _preferredProfession) return false;

      return true;
    }).toList();

    print(
        'FINAL: ${_filteredVacancies.length}/${_allVacancies.length} vagas visíveis');
    notifyListeners();
  }

  Future<void> applyFilters({
    String? state,
    String? city,
    String? profession,
  }) async {
    _filterState = state;
    _filterCity = city;
    _preferredProfession = profession;

    if (state != null && state.isNotEmpty) {
      await _loadCities(state);
    } else {
      _availableCities = [];
    }

    _isLoading = true;
    notifyListeners();
    await _loadInitialFeed();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setSearchQuery(String query) async {
    _searchQuery = query;
    await _applyFilters();
  }

  Future<void> clearFilters() async {
    _filterState = null;
    _filterCity = null;
    _preferredProfession = null;
    _searchQuery = '';
    _availableCities = [];
    _isLoading = true;
    notifyListeners();
    await _loadInitialFeed();
    _isLoading = false;
    notifyListeners();
  }

  // ── Refresh ───────────────────────────────────────────────────────────────

  Future<void> forceRefresh() async {
    _requestsLoaded = false;
    _chatsLoaded = false;
    _requestedVacancyIds.clear();
    _requestedProfessionalIds.clear();
    _chatUserIds.clear();
    _isLoading = true;
    notifyListeners();

    // ✅ CORREÇÃO: recarrega e SALVA bloqueados antes de tudo
    // Antes: buscava mas resultado sumia — _applyFilters continuava vazio
    await _loadBlockedUsers();

    await _loadChats();
    await _loadInitialFeed();
    await _applyFilters();
    _isLoading = false;
    notifyListeners();
  }
}
