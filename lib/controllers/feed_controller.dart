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
  late final UserRelationShipController _userController = UserRelationShipController();
  final ExpirationService _expirationService = ExpirationService();
  

  // ===============================
  // STATE
  // ===============================
  FeedMode _feedMode = FeedMode.unified;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _loadingCities = false;

  // DADOS CARREGADOS - ambos sempre presentes
  List<VacancyModel> _allVacancies = [];
  List<ProfessionalModel> _allProfessionals = [];

  // Lista filtrada de vagas
  List<VacancyModel> _filteredVacancies = [];

  // EXCLUSOES (apenas requests, chat NAO exclui mais)
  Set<String> _requestedVacancyIds = {};
  Set<String> _requestedProfessionalIds = {};
  Set<String> _chatUserIds = {};
  bool _requestsLoaded = false;
  bool _chatsLoaded = false;

  // FILTROS
  String? _filterState;
  String? _filterCity;
  String? _preferredProfession;
  String _searchQuery = '';

  // PAGINACAO - separada por tipo
  bool _hasMoreVacancies = true;
  bool _hasMoreProfessionals = true;
  String? _lastCreatedAt;
  String? _lastUpdatedAt;
  String? _lastVacancyKey;
  String? _lastProfessionalKey;

  // ESTADOS/CIDADES DISPONIVEIS
  List<Estado> _availableStates = [];
  List<Cidade> _availableCities = [];

  // ===============================
  // GETTERS
  // ===============================
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

  // CORRIGIDO: Removido bypass por chat - profissionais com chat sao tratados normalmente
  List<ProfessionalModel> get filteredProfessionals =>
      _allProfessionals.where((p) {
        if (_currentUserId != null && p.localId == _currentUserId) return true;
        if (_requestsLoaded && _requestedProfessionalIds.contains(p.localId))
          return false;
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

  bool get hasActiveFilters {
    return _filterState != null ||
        _filterCity != null ||
        _preferredProfession != null ||
        _searchQuery.isNotEmpty;
  }

  // ===============================
  // VERIFICADORES DE REQUEST
  // ===============================
  bool hasRequestedVacancy(String vacancyId) =>
      _requestedVacancyIds.contains(vacancyId);

  bool hasRequestedProfessional(String professionalLocalId) =>
      _requestedProfessionalIds.contains(professionalLocalId);

  // ===============================
  // INICIALIZACAO
  // ===============================
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
      if (_currentUserId != null) {
        await _userController.fetchAllBlockedUsers(_currentUserId!);
      }

      await _loadChats();
      await _loadInitialFeed();
      await _applyFilters();
      print('Feed unificado inicializado!');
      print('   Filtros ativos:');
      print('      - Estado: ${_filterState ?? "Todos"}');
      print('      - Cidade: ${_filterCity ?? "Todas"}');
      print('      - Profissao: ${_preferredProfession ?? "Todas"}');
    } catch (e, stack) {
      print('Erro ao inicializar feed: $e\nStack: $stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===============================
  // ESTADOS/CIDADES
  // ===============================
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

  // ===============================
  // CHATS
  // ===============================
  Future<void> _loadChats() async {
    if (_chatsLoaded) return;
    try {
      _chatUserIds = await _feedService.fetchChatUserIds();
      _chatsLoaded = true;
    } catch (e) {
      _chatUserIds = {};
    }
  }

  // ===============================
  // REQUESTS (lazy)
  // ===============================
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

  // ===============================
  // FEED INICIAL
  // ===============================
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

  // ===============================
  // PAGINACAO - carrega os DOIS tipos
  // ===============================
  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !hasMore) return;
    await _loadMoreItems();
  }

  Future<void> _loadMoreItems() async {
    _isLoadingMore = true;
    notifyListeners();

    try {
      print('\nCarregando mais itens...');
      print('   Filtros aplicados:');
      print('   - Estado: ${_filterState ?? "Todos"}');
      print('   - Cidade: ${_filterCity ?? "Todas"}');
      print('   - Profissao: ${_preferredProfession ?? "Todas"}');

      // Busca vagas
      if (_hasMoreVacancies) {
        final blockedList = await _userController.fetchAllBlockedUsers(_currentUserId!);
        final blockedUserIds = blockedList.toSet();

        final resultV = await _feedService.fetchVacanciesForFeed(
          blockedUserIds: blockedUserIds,
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

      // Busca profissionais
      if (_hasMoreProfessionals) {
        final blockedList = await _userController.fetchAllBlockedUsers(_currentUserId!); // ✅
        final blockedUserIds = blockedList.toSet();
        final resultP = await _feedService.fetchProfessionalsForFeed(
          filterState: _filterState,
          blockedUserIds: blockedUserIds,
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
          '   Total no feed: ${_allVacancies.length} vagas, ${_allProfessionals.length} profissionais');

      // Reaplica filtros apos carregar mais dados
      await _applyFilters();
    } catch (e) {
      print('Erro ao carregar mais itens: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ===============================
  // UTILITARIOS DE FILTRO
  // ===============================
  bool _matchesVacancy(VacancyModel vacancy, String query) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return vacancy.title.toLowerCase().contains(lowerQuery) ||
        vacancy.profession.toLowerCase().contains(lowerQuery) ||
        vacancy.description.toLowerCase().contains(lowerQuery);
  }

  // ===============================
  // FILTROS
  // ===============================
  Future<void> _applyFilters() async {
    print('DEBUG - Antes dos filtros: ${_allVacancies.length} vagas totais');

    // GARANTE DADOS CARREGADOS
    await ensureRequestsLoaded();
    await _loadChats();

    _filteredVacancies = _allVacancies.where((vac) {
      // CORRIGIDO: Removido bypass por chat
      // Vagas com chat existente agora passam pelos filtros normais

      // 1 - NAO MOSTRA: request pendente
      if (_requestsLoaded && _requestedVacancyIds.contains(vac.id)) {
        return false;
      }

      // 2 - Status invalido
      final statusLower = (vac.status ?? '').toLowerCase();
      if (statusLower == 'expirada' || statusLower == 'pausada') {
        return false;
      }

      // 3 - Expirado por data
      if (vac.expiresAt.isNotEmpty &&
          _expirationService.isExpired(vac.expiresAt)) {
        return false;
      }

      // 4 - Filtros de busca
      if (!_matchesVacancy(vac, _searchQuery)) {
        return false;
      }

      // 5 - Filtros adicionais: estado, cidade, profissao
      if (_filterState != null &&
          _filterState!.isNotEmpty &&
          vac.state != _filterState) {
        return false;
      }
      if (_filterCity != null &&
          _filterCity!.isNotEmpty &&
          vac.city != _filterCity) {
        return false;
      }
      if (_preferredProfession != null &&
          _preferredProfession!.isNotEmpty &&
          vac.profession != _preferredProfession) {
        return false;
      }

      return true;
    }).toList();

    print(
        'FINAL: ${_filteredVacancies.length}/${_allVacancies.length} vagas visiveis');
    notifyListeners();
  }

  Future<void> applyFilters({
    String? state,
    String? city,
    String? profession,
  }) async {
    print('\n========================================');
    print('   APLICANDO FILTROS');
    print('========================================');
    print('   Estado: ${state ?? "Todos"}');
    print('   Cidade: ${city ?? "Todas"}');
    print('   Profissao: ${profession ?? "Todas"}');

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

    // Recarrega feed e aplica filtros
    await _loadInitialFeed();

    _isLoading = false;
    notifyListeners();

    print('Filtros aplicados com sucesso!');
    print('========================================\n');
  }

  Future<void> setSearchQuery(String query) async {
    _searchQuery = query;
    await _applyFilters();
  }

  Future<void> clearFilters() async {
    print('\nLimpando filtros...');
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
    print('Filtros limpos!\n');
  }

  // ===============================
  // REFRESH
  // ===============================
  Future<void> forceRefresh() async {
    _requestsLoaded = false;
    _chatsLoaded = false;
    _requestedVacancyIds.clear();
    _requestedProfessionalIds.clear();
    _chatUserIds.clear();
    _isLoading = true;
    notifyListeners();

    // ✅ Recarrega bloqueados antes de tudo
    if (_currentUserId != null) {
      await _userController.fetchAllBlockedUsers(_currentUserId!);
    }

    await _loadChats();
    await _loadInitialFeed();
    await _applyFilters();
    _isLoading = false;
    notifyListeners();
  }
}
