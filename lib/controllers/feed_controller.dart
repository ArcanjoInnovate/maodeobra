import 'package:flutter/foundation.dart';
import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:dartobra_new/services/feed/feed_service.dart';
import 'package:dartobra_new/services/search/ibge_service.dart';

// ✅ Mantido para compatibilidade – mas agora o feed sempre carrega OS DOIS
enum FeedMode { worker, contractor, unified }

class FeedController with ChangeNotifier {
  final FirebaseFeedService _feedService = FirebaseFeedService();
  final IBGEService _ibgeService = IBGEService();

  // ===============================
  // STATE
  // ===============================
  FeedMode _feedMode = FeedMode.unified;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _loadingCities = false;

  // ✅ DADOS CARREGADOS – ambos sempre presentes
  List<VacancyModel> _allVacancies = [];
  List<ProfessionalModel> _allProfessionals = [];

  // ✅ EXCLUSÕES (requests e chats)
  Set<String> _requestedVacancyIds = {};
  Set<String> _requestedProfessionalIds = {};
  Set<String> _chatUserIds = {};
  bool _requestsLoaded = false;
  bool _chatsLoaded = false;

  // ✅ FILTROS
  String? _filterState;
  String? _filterCity;
  String? _preferredProfession;

  // ✅ PAGINAÇÃO – separada por tipo
  bool _hasMoreVacancies = true;
  bool _hasMoreProfessionals = true;
  String? _lastCreatedAt;
  String? _lastUpdatedAt;
  String? _lastVacancyKey;
  String? _lastProfessionalKey;

  // ✅ ESTADOS/CIDADES DISPONÍVEIS
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

  List<Estado> get availableStates => _availableStates;
  List<Cidade> get availableCities => _availableCities;

  List<VacancyModel> get filteredVacancies => _allVacancies;
  List<ProfessionalModel> get filteredProfessionals => _allProfessionals;

  // ✅ FEED UNIFICADO: intercala vagas e profissionais
  List<dynamic> get unifiedFeed {
    final List<dynamic> combined = [];
    final vacancies = List<VacancyModel>.from(_allVacancies);
    final professionals = List<ProfessionalModel>.from(_allProfessionals);

    // Intercala: 1 vaga, 1 profissional, alternando
    int vi = 0, pi = 0;
    while (vi < vacancies.length || pi < professionals.length) {
      if (vi < vacancies.length) combined.add(vacancies[vi++]);
      if (pi < professionals.length) combined.add(professionals[pi++]);
    }
    return combined;
  }

  String get feedStats {
    final total = _allVacancies.length + _allProfessionals.length;
    return '$total itens disponíveis';
  }

  // ✅ VERIFICA SE HÁ FILTROS ATIVOS
  bool get hasActiveFilters {
    return _filterState != null || 
           _filterCity != null || 
           _preferredProfession != null;
  }

  // ===============================
  // VERIFICADORES DE REQUEST
  // ===============================
  bool hasRequestedVacancy(String vacancyId) =>
      _requestedVacancyIds.contains(vacancyId);

  bool hasRequestedProfessional(String professionalLocalId) =>
      _requestedProfessionalIds.contains(professionalLocalId);

  // ===============================
  // INICIALIZAÇÃO
  // ===============================
  Future<void> initialize({
    required FeedMode mode,
    String? initialState,
    String? initialCity,
    String? preferredProfession,
  }) async {
    print('\n🚀 ========================================');
    print('   INICIALIZANDO FEED CONTROLLER UNIFICADO');
    print('========================================');

    _feedMode = FeedMode.unified;
    _filterState = initialState;
    _filterCity = initialCity;
    _preferredProfession = preferredProfession;
    _isLoading = true;
    notifyListeners();

    try {
      await _loadStates();
      if (initialState != null) await _loadCities(initialState);
      await _loadChats();
      await _loadInitialFeed();
      print('✅ Feed unificado inicializado!');
      print('   📍 Filtros ativos:');
      print('      - Estado: ${_filterState ?? "Todos"}');
      print('      - Cidade: ${_filterCity ?? "Todas"}');
      print('      - Profissão: ${_preferredProfession ?? "Todas"}');
    } catch (e, stack) {
      print('❌ Erro ao inicializar feed: $e\nStack: $stack');
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
    if (uf.isEmpty) { _availableCities = []; return; }
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
      _requestedProfessionalIds = await _feedService.fetchRequestedProfessionalIds();
      _requestsLoaded = true;
      notifyListeners();
    } catch (e) {
      print('❌ Erro ao carregar requests: $e');
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
  // PAGINAÇÃO – carrega os DOIS tipos
  // ===============================
  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !hasMore) return;
    await _loadMoreItems();
  }

  Future<void> _loadMoreItems() async {
    _isLoadingMore = true;
    notifyListeners();

    try {
      print('\n📥 Carregando mais itens...');
      print('   Filtros aplicados:');
      print('   - Estado: ${_filterState ?? "Todos"}');
      print('   - Cidade: ${_filterCity ?? "Todas"}');
      print('   - Profissão: ${_preferredProfession ?? "Todas"}');

      // ✅ Busca vagas
      if (_hasMoreVacancies) {
        final resultV = await _feedService.fetchVacanciesForFeed(
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
        print('   ✅ ${resultV.items.length} vagas carregadas');
      }

      // ✅ Busca profissionais
      if (_hasMoreProfessionals) {
        final resultP = await _feedService.fetchProfessionalsForFeed(
          filterState: _filterState,
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
        print('   ✅ ${resultP.items.length} profissionais carregados');
      }

      print('   📊 Total no feed: ${_allVacancies.length} vagas, ${_allProfessionals.length} profissionais');
      notifyListeners();
    } catch (e) {
      print('❌ Erro ao carregar mais itens: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ===============================
  // FILTROS
  // ===============================
  Future<void> applyFilters({
    String? state,
    String? city,
    String? profession,
  }) async {
    print('\n🔍 ========================================');
    print('   APLICANDO FILTROS');
    print('========================================');
    print('   Estado: ${state ?? "Todos"}');
    print('   Cidade: ${city ?? "Todas"}');
    print('   Profissão: ${profession ?? "Todas"}');

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
    
    print('✅ Filtros aplicados com sucesso!');
    print('========================================\n');
  }

  Future<void> clearFilters() async {
    print('\n🗑️ Limpando filtros...');
    _filterState = null;
    _filterCity = null;
    _preferredProfession = null;
    _availableCities = [];
    _isLoading = true;
    notifyListeners();
    await _loadInitialFeed();
    _isLoading = false;
    notifyListeners();
    print('✅ Filtros limpos!\n');
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
    await _loadChats();
    await _loadInitialFeed();
    _isLoading = false;
    notifyListeners();
  }
}