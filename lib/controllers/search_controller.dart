// lib/controllers/search_controller.dart

// ignore_for_file: unused_field


import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/services/cache/cache_service.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:dartobra_new/services/search/firebase_search_service.dart';
import 'package:dartobra_new/services/search/professionals_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/search/vacancy_model.dart';
import '../services/search/ibge_service.dart';

enum SearchType { professionals, vacancies }

class SearchController extends ChangeNotifier {
  final FirebaseSearchServiceServerPaginated _firebaseService = 
      FirebaseSearchServiceServerPaginated();
  final ExpirationService _expirationService = ExpirationService();
  final IBGEService _ibgeService = IBGEService();
  final CacheService _cacheService = CacheService();

  String? _currentUserId;

  // DADOS CARREGADOS
  List<ProfessionalModel> _allProfessionals = [];
  List<VacancyModel> _allVacancies = [];

  // DADOS FILTRADOS
  List<ProfessionalModel> _filteredProfessionals = [];
  List<VacancyModel> _filteredVacancies = [];

  // EXCLUSOES (apenas requests)
  Set<String> _requestedVacancyIds = {};
  Set<String> _requestedProfessionalIds = {};
  bool _requestsLoaded = false;

  // PAGINACAO
  static const int ITEMS_PER_PAGE = 20;
  static const int CACHE_DURATION_MINUTES = 30;
  static const int CACHE_DURATION_REQUESTS = 15;
  
  String? _lastVacancyKey;
  dynamic _lastVacancyValue;
  String? _lastProfessionalKey;
  dynamic _lastProfessionalValue;
  
  bool _hasMoreVacancies = true;
  bool _hasMoreProfessionals = true;
  bool _isLoadingMore = false;
  
  DateTime? _lastVacanciesLoad;
  DateTime? _lastProfessionalsLoad;
  DateTime? _lastRequestsLoad;

  // FILTROS
  List<String> _professions = [];
  String _searchQuery = '';
  String? _selectedCity;
  String? _selectedState;
  String? _selectedProfession;
  String? _selectedCompany;
  SearchType _searchType = SearchType.professionals;

  // ESTADOS
  bool _isLoading = false;
  String? _errorMessage;
  List<Estado> _estados = [];
  List<Cidade> _cidades = [];
  bool _loadingCidades = false;

  // ===============================
  // GETTERS
  // ===============================
  List<ProfessionalModel> get filteredProfessionals => _filteredProfessionals;
  List<VacancyModel> get filteredVacancies => _filteredVacancies;
  List<String> get professions => _professions;
  String get searchQuery => _searchQuery;
  String? get selectedCity => _selectedCity;
  String? get selectedState => _selectedState;
  String? get selectedProfession => _selectedProfession;
  String? get selectedCompany => _selectedCompany;
  SearchType get searchType => _searchType;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get loadingCidades => _loadingCidades;
  String? get errorMessage => _errorMessage;
  List<Estado> get estados => _estados;
  List<Cidade> get cidades => _cidades;
  bool get hasMore => _searchType == SearchType.professionals 
      ? _hasMoreProfessionals 
      : _hasMoreVacancies;
      
        

  bool hasRequestedVacancy(String vacancyId) =>
      _requestedVacancyIds.contains(vacancyId);
  bool hasRequestedProfessional(String professionalId) =>
      _requestedProfessionalIds.contains(professionalId);

  // ===============================
  // INICIALIZAR
  // ===============================
  Future<void> initialize() async {
    if (_isLoading) return;
    
    print('\n========================================');
    print('   INICIALIZANDO SEARCH CONTROLLER');
    print('========================================');
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    final startTime = DateTime.now();

    try {
      _currentUserId = FirebaseAuth.instance.currentUser?.uid;
      print('User ID: $_currentUserId');

      _professions = CivilProfessions.getAll();

      // PASSO 1: Carrega estados
      if (_estados.isEmpty) {
        _estados = await _ibgeService.getEstados();
        print('${_estados.length} estados carregados');
      }

      // PASSO 2: Tenta cache Hive primeiro
      final cachedProfs = await _cacheService.loadProfessionals(
        maxAgeMinutes: CACHE_DURATION_MINUTES,
      );
      final cachedVacs = await _cacheService.loadVacancies(
        maxAgeMinutes: CACHE_DURATION_MINUTES,
      );

      bool loadedFromCache = false;

      if (cachedProfs != null && cachedProfs.isNotEmpty) {
        print('CACHE HIT! ${cachedProfs.length} profissionais do Hive');
        _allProfessionals = cachedProfs.map((map) => 
          ProfessionalModel.fromMap(map)
        ).toList();
        _lastProfessionalsLoad = DateTime.now();
        loadedFromCache = true;
      }

      if (cachedVacs != null && cachedVacs.isNotEmpty) {
        print('CACHE HIT! ${cachedVacs.length} vagas do Hive');
        _allVacancies = cachedVacs.map((map) => 
          VacancyModel.fromMap(map)
        ).toList();
        _lastVacanciesLoad = DateTime.now();
        loadedFromCache = true;
      }

      // PASSO 3: Se nao tem cache, busca primeira pagina do servidor
      if (!loadedFromCache) {
        print('CACHE MISS - Buscando primeira pagina do servidor...');
        await _loadFirstPage();
      }

      print('Requests serao carregados sob demanda (lazy load)');

      // PASSO 4: Aplica filtros
      _applyFilters();

      final totalDuration = DateTime.now().difference(startTime);
      print('Inicializacao em ${totalDuration.inMilliseconds}ms');
      print('========================================\n');
      
    } catch (e, stack) {
      _errorMessage = 'Erro ao carregar dados: $e';
      print('$_errorMessage');
      print('Stack: $stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===============================
  // CARREGAR PRIMEIRA PAGINA
  // ===============================
  Future<void> _loadFirstPage() async {
    // Reset paginacao
    _lastProfessionalKey = null;
    _lastProfessionalValue = null;
    _lastVacancyKey = null;
    _lastVacancyValue = null;

    // BUSCA PROFISSIONAIS
    final profResult = await _firebaseService.fetchProfessionalsPaginated(
      limit: ITEMS_PER_PAGE,
    );
    
    _allProfessionals = profResult.items;
    _hasMoreProfessionals = profResult.hasMore;
    _lastProfessionalKey = profResult.lastKey;
    _lastProfessionalValue = profResult.lastValue;
    _lastProfessionalsLoad = DateTime.now();

    // Salva no cache
    await _cacheService.saveProfessionals(
      _allProfessionals.map((p) => p.toMap()).toList(),
    );

    print('${_allProfessionals.length} profissionais (primeira pagina)');
    print('   Tem mais: $_hasMoreProfessionals');

    // BUSCA VAGAS
    final vacResult = await _firebaseService.fetchVacanciesPaginated(
      limit: ITEMS_PER_PAGE,
    );
    
    _allVacancies = vacResult.items;
    _hasMoreVacancies = vacResult.hasMore;
    _lastVacancyKey = vacResult.lastKey;
    _lastVacancyValue = vacResult.lastValue;
    _lastVacanciesLoad = DateTime.now();

    await _cacheService.saveVacancies(
      _allVacancies.map((v) => v.toMap()).toList(),
    );

    print('${_allVacancies.length} vagas (primeira pagina)');
    print('   Tem mais: $_hasMoreVacancies');
  }

  // ===============================
  // LAZY LOAD DE REQUESTS
  // ===============================
  Future<void> ensureRequestsLoaded() async {
    if (_requestsLoaded && !_shouldReloadRequests()) {
      print('Requests ja carregados, reusando cache');
      return;
    }

    print('Carregando requests (lazy load)...');
    final startTime = DateTime.now();

    try {
      _requestedVacancyIds = await _firebaseService.fetchRequestedVacancyIds();
      _requestedProfessionalIds = await _firebaseService.fetchRequestedProfessionalIds();
      
      _requestsLoaded = true;
      _lastRequestsLoad = DateTime.now();
      
      final duration = DateTime.now().difference(startTime);
      print('Requests carregados em ${duration.inMilliseconds}ms');

      _applyFilters();
      
    } catch (e) {
      print('Erro ao carregar requests: $e');
    }
  }

  bool _shouldReloadRequests() {
    if (_lastRequestsLoad == null) return true;
    final diff = DateTime.now().difference(_lastRequestsLoad!);
    return diff.inMinutes >= CACHE_DURATION_REQUESTS;
  }

  // ===============================
  // CARREGAR MAIS ITENS (PAGINACAO)
  // ===============================
  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !hasMore) {
      print('Ignorando loadMore: loading=$_isLoadingMore, hasMore=$hasMore');
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      if (_searchType == SearchType.professionals) {
        // BUSCA MAIS PROFISSIONAIS
        final result = await _firebaseService.fetchProfessionalsPaginated(
          limit: ITEMS_PER_PAGE,
          endAtKey: _lastProfessionalKey,
          endAtValue: _lastProfessionalValue,
        );

        _allProfessionals.addAll(result.items);
        _hasMoreProfessionals = result.hasMore;
        _lastProfessionalKey = result.lastKey;
        _lastProfessionalValue = result.lastValue;

        print('+${result.items.length} profissionais carregados');
        print('   Total agora: ${_allProfessionals.length}');
        print('   Tem mais: $_hasMoreProfessionals');
      } else {
        // BUSCA MAIS VAGAS
        final result = await _firebaseService.fetchVacanciesPaginated(
          limit: ITEMS_PER_PAGE,
          endAtKey: _lastVacancyKey,
          endAtValue: _lastVacancyValue,
        );

        _allVacancies.addAll(result.items);
        _hasMoreVacancies = result.hasMore;
        _lastVacancyKey = result.lastKey;
        _lastVacancyValue = result.lastValue;

        print('+${result.items.length} vagas carregadas');
        print('   Total agora: ${_allVacancies.length}');
        print('   Tem mais: $_hasMoreVacancies');
      }

      _applyFilters();

    } catch (e) {
      print('Erro ao carregar mais itens: $e');
      _errorMessage = 'Erro ao carregar mais itens';
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ===============================
  // FORCE REFRESH
  // ===============================
  Future<void> forceRefresh() async {
    print('FORCE REFRESH');
    
    // Invalida tudo
    _lastProfessionalsLoad = null;
    _lastVacanciesLoad = null;
    _lastRequestsLoad = null;
    _requestsLoaded = false;
    
    _allProfessionals.clear();
    _allVacancies.clear();
    
    await _cacheService.clearAll();
    
    await initialize();
    await ensureRequestsLoaded();
  }

  // ===============================
  // FILTROS
  // ===============================
  
  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  Future<void> selectState(String? state) async {
    if (_selectedState == state) return;
    
    _selectedState = state;
    _selectedCity = null;
    _cidades = [];
    
    if (state != null) {
      _loadingCidades = true;
      notifyListeners();
      
      try {
        final sigla = _estados
            .firstWhere((e) => e.nome == state)
            .sigla;
        _cidades = await _ibgeService.getCidadesPorEstado(sigla);
      } catch (e) {
        print('Erro ao carregar cidades: $e');
      }
      
      _loadingCidades = false;
    }
    
    _applyFilters();
  }

  void selectCity(String? city) {
    _selectedCity = city;
    _applyFilters();
  }

  void selectProfession(String? profession) {
    _selectedProfession = profession;
    _applyFilters();
  }

  void selectCompany(String? company) {
    _selectedCompany = company;
    _applyFilters();
  }

  Future<void> changeSearchType(SearchType type) async {
    if (_searchType == type) return;
    
    _searchType = type;
    _selectedProfession = null;
    _selectedCompany = null;
    
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCity = null;
    _selectedState = null;
    _selectedProfession = null;
    _selectedCompany = null;
    _cidades = [];
    _applyFilters();
  }

  // ===============================
  // APLICAR FILTROS
  // ===============================
  /// REGRA PRINCIPAL (CORRIGIDA):
  /// - Mostra proprio card (usuario pode ver suas proprias vagas/perfil)
  /// - NAO mostra se ja solicitou
  /// - NAO mostra se expirado
  /// - MOSTRA NORMALMENTE mesmo se ja tem chat (CORRIGIDO)
  
  bool _matchesProfessional(ProfessionalModel prof, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    final searchableFields = [
      prof.name.toLowerCase(),
      prof.profession.toLowerCase(),
      prof.city.toLowerCase(),
      prof.state.toLowerCase(),
      prof.summary.toLowerCase(),
      ...prof.skills.map((s) => s.toLowerCase()),
    ];
    return searchableFields.any((field) => field.contains(q));
  }

  bool _matchesVacancy(VacancyModel vac, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    final searchableFields = [
      vac.title.toLowerCase(),
      vac.description.toLowerCase(),
      vac.profession.toLowerCase(),
      vac.city.toLowerCase(),
      vac.state.toLowerCase(),
    ];
    return searchableFields.any((field) => field.contains(q));
  }

  void _applyFilters() {
  // PROFISSIONAIS - CORRIGIDO: removido bypass por chat
  _filteredProfessionals = _allProfessionals.where((prof) {
    // NAO MOSTRA: requests pendentes
    if (_requestsLoaded && _requestedProfessionalIds.contains(prof.localId)) return false;
    
    // Filtros basicos
    if (prof.status.toLowerCase() == 'expired') return false;
    if (!_matchesProfessional(prof, _searchQuery)) return false;
    // ... resto dos filtros ...
    
    return true;
  }).toList();

  // VAGAS - CORRIGIDO: removido bypass por chat
  _filteredVacancies = _allVacancies.where((vac) {
    // NAO MOSTRA: requests pendentes
    if (_requestsLoaded && _requestedVacancyIds.contains(vac.id)) return false;
    
    // Filtros basicos
    final statusLower = vac.status.toLowerCase();
    if (statusLower == 'expirada' || statusLower == 'pausada') return false;
    if (vac.expiresAt.isNotEmpty && _expirationService.isExpired(vac.expiresAt)) return false;
    if (!_matchesVacancy(vac, _searchQuery)) return false;
    // ... resto dos filtros ...
    
    return true;
  }).toList();

  notifyListeners();
}

  // ===============================
  // LISTAS AUXILIARES
  // ===============================
  
  List<String> getAvailableProfessions() {
    final professions = <String>{};
    if (_searchType == SearchType.professionals) {
      for (var prof in _allProfessionals) {
        if (prof.profession.isNotEmpty && prof.profession != 'Nao definida') {
          professions.add(prof.profession);
        }
      }
    } else {
      for (var vac in _allVacancies) {
        if (vac.profession.isNotEmpty && vac.profession != 'Nao definida') {
          professions.add(vac.profession);
        }
      }
    }
    return professions.toList()..sort();
  }

  List<String> getAvailableCompanies() {
    final companies = <String>{};
    if (_searchType == SearchType.professionals) {
      for (var prof in _allProfessionals) {
        if (prof.company.isNotEmpty) companies.add(prof.company);
      }
    } else {
      for (var vac in _allVacancies) {
        if (vac.company.isNotEmpty) companies.add(vac.company);
      }
    }
    return companies.toList()..sort();
  }

  List<String> getAvailableCities() {
    final cities = <String>{};
    if (_searchType == SearchType.professionals) {
      for (var prof in _allProfessionals) {
        if (prof.city.isNotEmpty) cities.add(prof.city);
      }
    } else {
      for (var vac in _allVacancies) {
        if (vac.city.isNotEmpty) cities.add(vac.city);
      }
    }
    return cities.toList()..sort();
  }

  List<String> getAvailableStates() {
    final states = <String>{};
    if (_searchType == SearchType.professionals) {
      for (var prof in _allProfessionals) {
        if (prof.state.isNotEmpty) states.add(prof.state);
      }
    } else {
      for (var vac in _allVacancies) {
        if (vac.state.isNotEmpty) states.add(vac.state);
      }
    }
    return states.toList()..sort();
  }
}
