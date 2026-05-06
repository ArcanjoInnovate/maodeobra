import 'package:dartobra_new/core/controllers/user_relationship_controller.dart';
import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/services/cache/cache_service.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:dartobra_new/services/search/firebase_search_service.dart';
import 'package:dartobra_new/services/search/ibge_service.dart';
import 'package:dartobra_new/services/search/professionals_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/search/vacancy_model.dart';

enum SearchType { professionals, vacancies }

class SearchController extends ChangeNotifier {
  final FirebaseSearchServiceServerPaginated _firebaseService =
      FirebaseSearchServiceServerPaginated();
  final ExpirationService _expirationService = ExpirationService();
  final IBGEService _ibgeService = IBGEService();
  final CacheService _cacheService = CacheService();
  final UserRelationShipController _userController =
      UserRelationShipController();

  String? _currentUserId;

  // ✅ CORREÇÃO PRINCIPAL: campo que persiste os bloqueados
  // Antes não existia — o set era criado localmente e descartado logo depois
  Set<String> _blockedUserIds = {};

  List<ProfessionalModel> _allProfessionals = [];
  List<VacancyModel> _allVacancies = [];
  List<ProfessionalModel> _filteredProfessionals = [];
  List<VacancyModel> _filteredVacancies = [];

  Set<String> _requestedVacancyIds = {};
  Set<String> _requestedProfessionalIds = {};
  bool _requestsLoaded = false;

  static const int ITEMS_PER_PAGE = 20;

  String? _lastVacancyKey;
  dynamic _lastVacancyValue;
  String? _lastProfessionalKey;
  dynamic _lastProfessionalValue;

  bool _hasMoreVacancies = true;
  bool _hasMoreProfessionals = true;
  bool _isLoadingMore = false;

  List<String> _professions = [];
  String _searchQuery = '';
  String? _selectedCity;
  String? _selectedState;
  String? _selectedProfession;
  String? _selectedCompany;
  SearchType _searchType = SearchType.professionals;

  bool _isLoading = false;
  String? _errorMessage;
  List<Estado> _estados = [];
  List<Cidade> _cidades = [];
  bool _loadingCidades = false;

  // ── Getters ───────────────────────────────────────────────────────────────

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

  List<ProfessionalModel> get availableProfessionals => _filteredProfessionals;
  List<String> getAvailableProfessions() => _professions;

  bool hasRequestedVacancy(String vacancyId) =>
      _requestedVacancyIds.contains(vacancyId);
  bool hasRequestedProfessional(String professionalId) =>
      _requestedProfessionalIds.contains(professionalId);

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_isLoading) return;

    print('\n========================================');
    print('   INICIALIZANDO SEARCH CONTROLLER');
    print('========================================');

    _currentUserId = FirebaseAuth.instance.currentUser?.uid;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // ✅ CORREÇÃO: carrega e SALVA bloqueados no campo
      if (_currentUserId != null) {
      // tenta até 3x com intervalo — iOS pode demorar mais
      for (int i = 0; i < 3; i++) {
        final list = await _userController.fetchAllBlockedUsers(_currentUserId!);
        if (list.isNotEmpty || i == 2) {
          _blockedUserIds = list.toSet();
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
      await _loadBlockedUsers();

      await _cacheService.clearAll();

      if (_professions.isEmpty) {
        _professions = CivilProfessions.getAll();
      }
      if (_estados.isEmpty) {
        _estados = await _ibgeService.getEstados();
      }

      await _loadFirstPage();
      _applyFilters();
    } catch (e, stack) {
      _errorMessage = 'Erro ao carregar: $e';
      print('Erro: $e\nStack: $stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Adicione este método no SearchController
  void addBlockedUser(String userId) {
    if (userId.isEmpty) return;
    _blockedUserIds = {..._blockedUserIds, userId};
    _applyFilters(); // já chama notifyListeners() internamente
  }
  // ✅ NOVO: método dedicado para carregar e persistir bloqueados
  Future<void> _loadBlockedUsers() async {
    if (_currentUserId == null) return;
    try {
      final list = await _userController.fetchAllBlockedUsers(_currentUserId!);
      _blockedUserIds = list.toSet();
      print('✅ Search _blockedUserIds: ${_blockedUserIds.length}');
    } catch (e) {
      print('❌ Erro ao carregar bloqueados no Search: $e');
      _blockedUserIds = {};
    }
  }

  // ── Primeira página ───────────────────────────────────────────────────────

  Future<void> _loadFirstPage() async {
    print('_loadFirstPage — bloqueados: ${_blockedUserIds.length}');

    _lastProfessionalKey = null;
    _lastProfessionalValue = null;
    _lastVacancyKey = null;
    _lastVacancyValue = null;
    _hasMoreProfessionals = true;
    _hasMoreVacancies = true;

    // ✅ usa _blockedUserIds do campo — não busca de novo
    final profResult = await _firebaseService.fetchProfessionalsPaginated(
      blockedUserIds: _blockedUserIds,
      limit: ITEMS_PER_PAGE,
    );
    _allProfessionals = profResult.items;
    _hasMoreProfessionals = profResult.hasMore;
    _lastProfessionalKey = profResult.lastKey;
    _lastProfessionalValue = profResult.lastValue;

    final vacResult = await _firebaseService.fetchVacanciesPaginated(
      blockedUserIds: _blockedUserIds,
      limit: ITEMS_PER_PAGE,
    );
    _allVacancies = vacResult.items;
    _hasMoreVacancies = vacResult.hasMore;
    _lastVacancyKey = vacResult.lastKey;
    _lastVacancyValue = vacResult.lastValue;

    print('${_allProfessionals.length} profs + ${_allVacancies.length} vagas');
  }

  // ── Paginação ─────────────────────────────────────────────────────────────

  Future<void> loadMoreItems() async {
    if (_isLoadingMore || !hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      // ✅ usa _blockedUserIds do campo — não busca de novo
      if (_searchType == SearchType.professionals) {
        final result = await _firebaseService.fetchProfessionalsPaginated(
          blockedUserIds: _blockedUserIds,
          limit: ITEMS_PER_PAGE,
          endAtKey: _lastProfessionalKey,
          endAtValue: _lastProfessionalValue,
        );
        _allProfessionals.addAll(result.items);
        _hasMoreProfessionals = result.hasMore;
        _lastProfessionalKey = result.lastKey;
        _lastProfessionalValue = result.lastValue;
      } else {
        final result = await _firebaseService.fetchVacanciesPaginated(
          blockedUserIds: _blockedUserIds,
          limit: ITEMS_PER_PAGE,
          endAtKey: _lastVacancyKey,
          endAtValue: _lastVacancyValue,
        );
        _allVacancies.addAll(result.items);
        _hasMoreVacancies = result.hasMore;
        _lastVacancyKey = result.lastKey;
        _lastVacancyValue = result.lastValue;
      }

      _applyFilters();
    } catch (e) {
      print('Erro loadMore: $e');
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  // ── Requests (lazy) ───────────────────────────────────────────────────────

  Future<void> ensureRequestsLoaded() async {
    if (_requestsLoaded) return;
    try {
      _requestedVacancyIds = await _firebaseService.fetchRequestedVacancyIds();
      _requestedProfessionalIds =
          await _firebaseService.fetchRequestedProfessionalIds();
      _requestsLoaded = true;
      _applyFilters();
    } catch (e) {
      print('Erro requests: $e');
    }
  }

  // ── Filtros ───────────────────────────────────────────────────────────────

  bool _matchesProfessional(ProfessionalModel prof, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    final fields = [
      prof.name.toLowerCase(),
      prof.profession.toLowerCase(),
      prof.city.toLowerCase(),
      prof.state.toLowerCase(),
      prof.summary.toLowerCase(),
      ...prof.skills.map((s) => s.toLowerCase()),
    ];
    return fields.any((f) => f.contains(q));
  }

  bool _matchesVacancy(VacancyModel vac, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase().trim();
    final fields = [
      vac.title.toLowerCase(),
      vac.description.toLowerCase(),
      vac.profession.toLowerCase(),
      vac.city.toLowerCase(),
      vac.state.toLowerCase(),
    ];
    return fields.any((f) => f.contains(q));
  }

  void _applyFilters() {
    ensureRequestsLoaded();

    print('_applyFilters — bloqueados: ${_blockedUserIds.length}');

    _filteredProfessionals = _allProfessionals.where((prof) {
      // ✅ CORREÇÃO: filtra bloqueados da memória
      // Antes: este bloco não existia — server filtrava mas memória não
      if (_blockedUserIds.isNotEmpty &&
          prof.localId.isNotEmpty &&
          _blockedUserIds.contains(prof.localId)) return false;

      if (_requestsLoaded && _requestedProfessionalIds.contains(prof.localId)) {
        return false;
      }
      if (prof.status.toLowerCase() == 'expired') return false;
      if (!_matchesProfessional(prof, _searchQuery)) return false;
      if (_selectedState != null &&
          _selectedState!.isNotEmpty &&
          prof.state != _selectedState) return false;
      if (_selectedCity != null &&
          _selectedCity!.isNotEmpty &&
          prof.city != _selectedCity) return false;
      if (_selectedProfession != null &&
          _selectedProfession!.isNotEmpty &&
          prof.profession != _selectedProfession) return false;
      if (_selectedCompany != null &&
          _selectedCompany!.isNotEmpty &&
          prof.company != _selectedCompany) return false;
      return true;
    }).toList();

    _filteredVacancies = _allVacancies.where((vac) {
      // ✅ CORREÇÃO: filtra bloqueados da memória
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
      if (_selectedState != null &&
          _selectedState!.isNotEmpty &&
          vac.state != _selectedState) return false;
      if (_selectedCity != null &&
          _selectedCity!.isNotEmpty &&
          vac.city != _selectedCity) return false;
      if (_selectedProfession != null &&
          _selectedProfession!.isNotEmpty &&
          vac.profession != _selectedProfession) return false;
      if (_selectedCompany != null &&
          _selectedCompany!.isNotEmpty &&
          vac.company != _selectedCompany) return false;
      return true;
    }).toList();

    notifyListeners();
  }

  // ── Filtros UI ────────────────────────────────────────────────────────────

  void updateSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  Future<void> selectState(String? state) async {
    if (_selectedState == state) return;
    _selectedState = state;
    _selectedCity = null;
    _cidades = [];

    if (state != null && state.isNotEmpty) {
      _loadingCidades = true;
      notifyListeners();
      try {
        final sigla = _estados.firstWhere((e) => e.nome == state).sigla;
        _cidades = await _ibgeService.getCidadesPorEstado(sigla);
      } catch (e) {}
      _loadingCidades = false;
    }
    _applyFilters();
    notifyListeners();
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

  // ── Refresh ───────────────────────────────────────────────────────────────

  Future<void> forceRefresh() async {
    _requestsLoaded = false;
    _allProfessionals.clear();
    _allVacancies.clear();
    await _cacheService.clearAll();

    // ✅ CORREÇÃO: recarrega e SALVA bloqueados antes de tudo
    await _loadBlockedUsers();

    await initialize();
  }
}