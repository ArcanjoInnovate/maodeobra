import 'package:dartobra_new/core/controllers/user_relationship_controller.dart';
import 'package:dartobra_new/core/providers/block_provider.dart';
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

  BlockProvider? _blockProvider;
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
  bool _requestsLoaded = false;

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

  List<ProfessionalModel> get filteredProfessionals =>
      _allProfessionals.where((p) {
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

  // ── BlockProvider ─────────────────────────────────────────────────────────

  void registerWithBlockProvider(BlockProvider blockProvider) {
    if (_blockProvider == blockProvider) return;
    _blockProvider?.unregisterOnBlock(_handleUserBlocked);
    _blockProvider?.unregisterOnUnblock(_handleUserUnblocked);
    _blockProvider = blockProvider;
    blockProvider.registerOnBlock(_handleUserBlocked);
    blockProvider.registerOnUnblock(_handleUserUnblocked);
    _blockedUserIds = {..._blockedUserIds, ...blockProvider.blockedSet};
    debugPrint('🔗 FeedController: ${_blockedUserIds.length} bloqueados sincronizados');
  }

  void _handleUserBlocked(String userId) {
    _blockedUserIds = {..._blockedUserIds, userId};
    _applyFilters();
  }

  void _handleUserUnblocked(String userId) {
    _blockedUserIds = _blockedUserIds.difference({userId});
    _applyFilters();
  }

  // ── Inicialização ─────────────────────────────────────────────────────────

  Future<void> initialize({
    required FeedMode mode,
    String? initialState,
    String? initialCity,
    String? preferredProfession,
  }) async {
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

      if (_blockProvider != null) {
        _blockedUserIds = Set.from(_blockProvider!.blockedSet);
      } else {
        await _loadBlockedUsers();
      }

      await _loadInitialFeed();
      await _applyFilters();
    } catch (e, stack) {
      debugPrint('Erro ao inicializar feed: $e\nStack: $stack');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadBlockedUsers() async {
    if (_currentUserId == null) return;
    try {
      final list =
          await _userController.fetchAllBlockedUsers(_currentUserId!);
      _blockedUserIds = {..._blockedUserIds, ...list};
    } catch (e) {
      debugPrint('❌ Erro ao carregar bloqueados: $e');
    }
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
      debugPrint('Erro ao carregar requests: $e');
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
      if (_hasMoreVacancies) {
        final resultV = await _feedService.fetchVacanciesForFeed(
          blockedUserIds: _blockedUserIds,
          filterState: _filterState,
          filterCity: _filterCity,
          preferredProfession: _preferredProfession,
          requestedVacancyIds: _requestedVacancyIds,
          limit: 15,
          lastCreatedAt: _lastCreatedAt,
          lastKey: _lastVacancyKey,
        );
        _allVacancies.addAll(resultV.items);
        _lastCreatedAt = resultV.lastCreatedAt;
        _lastVacancyKey = resultV.lastKey;
        _hasMoreVacancies = resultV.hasMore;
      }

      if (_hasMoreProfessionals) {
        final resultP = await _feedService.fetchProfessionalsForFeed(
          filterState: _filterState,
          blockedUserIds: _blockedUserIds,
          filterCity: _filterCity,
          preferredProfession: _preferredProfession,
          requestedProfessionalIds: _requestedProfessionalIds,
          limit: 15,
          lastUpdatedAt: _lastUpdatedAt,
          lastKey: _lastProfessionalKey,
        );
        _allProfessionals.addAll(resultP.items);
        _lastUpdatedAt = resultP.lastUpdatedAt;
        _lastProfessionalKey = resultP.lastKey;
        _hasMoreProfessionals = resultP.hasMore;
      }

      await _applyFilters();
    } catch (e) {
      debugPrint('Erro ao carregar mais itens: $e');
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
    await ensureRequestsLoaded();

    _filteredVacancies = _allVacancies.where((vac) {
      if (_blockedUserIds.isNotEmpty &&
          vac.localId.isNotEmpty &&
          _blockedUserIds.contains(vac.localId)) return false;

      if (_requestsLoaded && _requestedVacancyIds.contains(vac.id)) {
        return false;
      }

      // ✅ Vagas pausadas são ocultadas, mas vagas com expires_at vencido
      // permanecem no feed — o dono é avisado para renovar (bump no topo).
      if (vac.status.toLowerCase() == 'pausada') return false;

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
    _requestedVacancyIds.clear();
    _requestedProfessionalIds.clear();
    _isLoading = true;
    notifyListeners();

    if (_blockProvider != null) {
      _blockedUserIds = Set.from(_blockProvider!.blockedSet);
    } else {
      await _loadBlockedUsers();
    }

    await _loadInitialFeed();
    await _applyFilters();
    _isLoading = false;
    notifyListeners();
  }

  // ── Dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _blockProvider?.unregisterOnBlock(_handleUserBlocked);
    _blockProvider?.unregisterOnUnblock(_handleUserUnblocked);
    super.dispose();
  }

  void addBlockedUser(String ownerLocalId) {}
}