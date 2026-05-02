import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/features/notifications/screens/notification_history_screen.dart';
import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:dartobra_new/screens/feed/professional_profile_screen.dart';
import 'package:dartobra_new/screens/feed/vacancy_detail_screen.dart';
import 'package:dartobra_new/screens/search/my_professional_profile_screen.dart';
import 'package:dartobra_new/core/controllers/user_relationship_controller.dart';
import 'package:dartobra_new/screens/search/my_vacancy_details_screen.dart';
import 'package:dartobra_new/services/expiration/expiration_service.dart';
import 'package:dartobra_new/services/search/ibge_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';



class FeedScreen extends StatefulWidget {
  final String userEmail;
  final String userPhone;
  final String localId;
  final String userName;
  final String legalType;
  final String userCity;
  final String userState;
  final String userAvatar;
  final bool finished_basic;
  final bool finished_professional;
  final bool finished_contact;
  final bool isActive;
  final String activeMode;
  final Map<String, dynamic> dataWorker;
  final Map<String, dynamic> dataContractor;
  final VoidCallback? onNavigateToVacancies;

  const FeedScreen({
    super.key,
    required this.userEmail,
    required this.userPhone,
    required this.localId,
    required this.userName,
    required this.legalType,
    required this.userCity,
    required this.userState,
    required this.userAvatar,
    required this.finished_basic,
    required this.finished_professional,
    required this.finished_contact,
    required this.isActive,
    required this.activeMode,
    required this.dataWorker,
    required this.dataContractor,
    this.onNavigateToVacancies,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> with TickerProviderStateMixin {
  final ScrollController _scrollController = ScrollController();
  LocationFilter _locationFilter = LocationFilter.all;
  late AnimationController _headerAnimController;
  late Animation<double> _headerOpacity;

  // ── Paleta ────────────────────────────────────────────────
  static const _indigo     = Color(0xFF2563EB);
  static const _indigoSoft = Color(0xFFEFF6FF);
  static const _indigoMid  = Color(0xFFDBEAFE);
  static const _green      = Color(0xFF059669);
  static const _greenSoft  = Color(0xFFECFDF5);
  static const _greenMid   = Color(0xFFA7F3D0);
  static const _amber      = Color(0xFFF59E0B);
  static const _ink        = Color(0xFF111827);
  static const _muted      = Color(0xFF6B7280);
  static const _border     = Color(0xFFE5E7EB);
  static const _bg         = Color(0xFFF3F4F6);
  static const _card       = Colors.white;

  // Mapa de cores por profissão (igual ao VacancyCardWithExpiration)
  static const _profColors = {
    'pedreiro':    [Color(0xFF2563EB), Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
    'encanador':   [Color(0xFF2563EB), Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
    'eletricista': [Color(0xFFD97706), Color(0xFFFFFBEB), Color(0xFFFDE68A)],
    'pintor':      [Color(0xFF7C3AED), Color(0xFFF5F3FF), Color(0xFFEDE9FE)],
    'carpinteiro': [Color(0xFF92400E), Color(0xFFFFF7ED), Color(0xFFFED7AA)],
    'asfaltador':  [Color(0xFF374151), Color(0xFFF9FAFB), Color(0xFFE5E7EB)],
    'arquiteto':   [Color(0xFF0E7490), Color(0xFFECFEFF), Color(0xFFA5F3FC)],
    'armador':     [Color(0xFF9D174D), Color(0xFFFDF2F8), Color(0xFFFBCFE8)],
    'soldador':    [Color(0xFFB45309), Color(0xFFFFFBEB), Color(0xFFFCD34D)],
    'mestre':      [Color(0xFF1D4ED8), Color(0xFFEFF6FF), Color(0xFFBFDBFE)],
    'engenheiro':  [Color(0xFF0F766E), Color(0xFFF0FDFA), Color(0xFF99F6E4)],
  };

  Color _profColor(String p, int idx) {
    final lower = p.toLowerCase();
    for (final key in _profColors.keys) {
      if (lower.contains(key)) return _profColors[key]![idx];
    }
    return idx == 0 ? _indigo : idx == 1 ? _indigoSoft : _indigoMid;
  }

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.localId;

  // ── Formatação de salário ──────────────────────────────────
  String _formatSalary(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'A combinar';
    final lower = trimmed.toLowerCase();
    if (lower == 'a combinar') return 'A combinar';
    if (lower == 'por empreitada') return 'Por empreitada';
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^\d.,]'), '').trim();
    if (digitsOnly.isEmpty) return trimmed;
    final normalized = digitsOnly.replaceAll('.', '').replaceAll(',', '.');
    final number = double.tryParse(normalized);
    if (number == null || number == 0) return 'A combinar';
    if (number % 1 == 0) {
      final formatted = number.toInt().toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
      return 'R\$ $formatted';
    }
    final formatted = number.toStringAsFixed(2);
    final parts = formatted.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return 'R\$ $intPart,${parts[1]}';
  }

  String _timeAgo(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60) return 'agora mesmo';
      if (diff.inMinutes < 60) {
        final m = diff.inMinutes;
        return 'há $m ${m == 1 ? 'minuto' : 'minutos'}';
      }
      if (diff.inHours < 24) {
        final h = diff.inHours;
        return 'há $h ${h == 1 ? 'hora' : 'horas'}';
      }
      if (diff.inDays < 7) {
        final d = diff.inDays;
        return 'há $d ${d == 1 ? 'dia' : 'dias'}';
      }
      if (diff.inDays < 30) {
        final w = (diff.inDays / 7).floor();
        return 'há $w ${w == 1 ? 'semana' : 'semanas'}';
      }
      if (diff.inDays < 365) {
        final mo = (diff.inDays / 30).floor();
        return 'há $mo ${mo == 1 ? 'mês' : 'meses'}';
      }
      final y = (diff.inDays / 365).floor();
      return 'há $y ${y == 1 ? 'ano' : 'anos'}';
    } catch (_) {
      return '';
    }
  }

  @override
  void initState() {
    super.initState();
    _headerAnimController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _headerOpacity = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _headerAnimController, curve: Curves.easeOut));
    _headerAnimController.forward();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeFeed());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _headerAnimController.dispose();
    super.dispose();
  }

  Future<void> _initializeFeed() async {
    if (!mounted) return;
    final controller = context.read<FeedController>();
    final mode =
        widget.activeMode == 'worker' ? FeedMode.worker : FeedMode.contractor;
    String? preferredProfession;
    if (widget.dataContractor['preferred_profession'] != null) {
      preferredProfession =
          widget.dataContractor['preferred_profession'] as String?;
    }
    await controller.initialize(
        mode: mode,
        initialState: null,
        initialCity: null,
        preferredProfession: preferredProfession);
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _loadMoreItems();
    }
  }

  Future<void> _loadMoreItems() async {
    if (!mounted) return;
    final c = context.read<FeedController>();
    if (!c.isLoadingMore && c.hasMore) {
      await c.ensureRequestsLoaded();
      await c.loadMoreItems();
    }
  }

  Future<void> _onRefresh() async {
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    await context.read<FeedController>().forceRefresh();
  }

  List<dynamic> _getFilteredUnifiedFeed(FeedController controller) {
    final city = widget.userCity.toLowerCase().trim();
    final state = widget.userState.toLowerCase().trim();

    final vacancies = controller.filteredVacancies.where((v) {
      if (v.status.toLowerCase() == 'expirada') return false;
      if (v.expiresAt.isNotEmpty && ExpirationService().isExpired(v.expiresAt))
        return false;
      switch (_locationFilter) {
        case LocationFilter.sameCity:
          return v.city.toLowerCase().trim() == city;
        case LocationFilter.sameState:
          return v.state.toLowerCase().trim() == state;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) {
        final aDate = b.updatedAt.isNotEmpty ? b.updatedAt : b.createdAt;
        final bDate = a.updatedAt.isNotEmpty ? a.updatedAt : a.createdAt;
        return aDate.compareTo(bDate);
      });
    final professionals = controller.filteredProfessionals.where((p) {
      if (p.status.toLowerCase() == 'expired' ||
          p.status.toLowerCase() == 'expirada') return false;
      if (p.expiresAt.isNotEmpty && ExpirationService().isExpired(p.expiresAt))
        return false;
      switch (_locationFilter) {
        case LocationFilter.sameCity:
          return p.city.toLowerCase().trim() == city;
        case LocationFilter.sameState:
          return p.state.toLowerCase().trim() == state;
        default:
          return true;
      }
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final List<dynamic> combined = [];
    int vi = 0, pi = 0;
    while (vi < vacancies.length || pi < professionals.length) {
      if (vi < vacancies.length) combined.add(vacancies[vi++]);
      if (pi < professionals.length) combined.add(professionals[pi++]);
    }
    return combined;
  }

  // ── BUILD ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Consumer<FeedController>(
        builder: (context, controller, _) {
          final feedItems = _getFilteredUnifiedFeed(controller);
          return SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildTopBar(controller, feedItems.length),
                _buildFilterChips(),
                Container(height: 1, color: _border),
                Expanded(
                  child: controller.isLoading
                      ? _buildShimmerList()
                      : RefreshIndicator(
                          color: _indigo,
                          onRefresh: _onRefresh,
                          child: feedItems.isEmpty
                              ? _buildEmptyState(controller)
                              : _buildFeedList(controller, feedItems),
                        ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton:
          widget.onNavigateToVacancies != null ? _buildFAB() : null,
    );
  }

  // ── TOP BAR ────────────────────────────────────────────────

  Widget _buildTopBar(FeedController controller, int count) {
    final hasFilter = controller.filterState != null ||
        controller.filterCity != null ||
        controller.preferredProfession != null;

    return FadeTransition(
      opacity: _headerOpacity,
      child: Container(
        color: _card,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _indigoSoft,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _indigo.withOpacity(0.2)),
              ),
              child: const Icon(Icons.dynamic_feed_rounded,
                  color: _indigo, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Feed',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 1),
                  Text(
                    hasFilter
                        ? '$count itens · Filtrado'
                        : '$count itens · Vagas & Profissionais',
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: _muted,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            _notificationsButton(),
            const SizedBox(width: 12),
            _buildFilterButton(controller, hasFilter),
          ],
        ),
      ),
    );
  }

  Widget _notificationsButton () {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationHistoryScreen(userId: widget.localId)));
      },
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: _border),
        ),
        child: const Icon(Icons.notifications_none_rounded,
            size: 20, color: _muted),
      ),
    );
  }
  Widget _buildFilterButton(FeedController controller, bool hasFilter) {
    return GestureDetector(
      onTap: () => _showAdvancedFilters(controller),
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: hasFilter ? _indigoSoft : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: hasFilter ? _indigo.withOpacity(0.35) : _border,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(Icons.tune_rounded,
                size: 20, color: hasFilter ? _indigo : _muted),
            if (hasFilter)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                      color: _amber, shape: BoxShape.circle),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── FILTER CHIPS ───────────────────────────────────────────

  Widget _buildFilterChips() {
    return Container(
      color: _card,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _chip('Todas', _locationFilter == LocationFilter.all,
              Icons.public_rounded,
              () => setState(() => _locationFilter = LocationFilter.all)),
          const SizedBox(width: 8),
          _chip('Minha cidade', _locationFilter == LocationFilter.sameCity,
              Icons.location_city_rounded,
              () => setState(() => _locationFilter = LocationFilter.sameCity)),
          const SizedBox(width: 8),
          _chip('Meu estado', _locationFilter == LocationFilter.sameState,
              Icons.map_rounded,
              () => setState(() => _locationFilter = LocationFilter.sameState)),
        ]),
      ),
    );
  }

  Widget _chip(String label, bool selected, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? _indigo : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? _indigo : _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: selected ? Colors.white : _muted),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : _muted)),
        ]),
      ),
    );
  }

  // ── FEED LIST ──────────────────────────────────────────────

  Widget _buildFeedList(FeedController controller, List<dynamic> items) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
      itemCount: items.length + (controller.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: _indigo),
            ),
          );
        }
        final item = items[index];
        if (item is VacancyModel) {
          final isOwn = item.localId == _currentUserId;
          return isOwn ? _buildOwnVacancyCard(item) : _buildVacancyCard(item);
        } else if (item is ProfessionalModel) {
          final isOwn = item.localId == _currentUserId;
          return isOwn
              ? _buildOwnProfessionalCard(item)
              : _buildProfessionalCard(item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── VACANCY CARDS ─────────────────────────────────────────
  // ══════════════════════════════════════════════════════════

  Widget _buildVacancyCard(VacancyModel vacancy) {
    return _FeedCard(
      isOwn: false,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VacancyDetailsScreen(
                    vacancy: vacancy.toMap(),
                    currentUserId: widget.localId,
                    vacancyId: vacancy.id,
                    reportedId: vacancy.localId,
                  ))),
      child: _VacancyCardContent(
        vacancy: vacancy,
        isOwn: false,
        formatSalary: _formatSalary,
        timeAgo: _timeAgo,
        profColor: _profColor,
      ),
    );
  }

  Widget _buildOwnVacancyCard(VacancyModel vacancy) {
    return _FeedCard(
      isOwn: true,
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MyVacancyDetailPage(
                    vacancy: vacancy,
                    onEditVacancy: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text(
                            'Vá para a aba "Vagas" para editar sua vaga'),
                        backgroundColor: _amber,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ));
                    },
                    localId: widget.localId,
                  ))),
      child: _VacancyCardContent(
        vacancy: vacancy,
        isOwn: true,
        formatSalary: _formatSalary,
        timeAgo: _timeAgo,
        profColor: _profColor,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── PROFESSIONAL CARDS ────────────────────────────────────
  // ══════════════════════════════════════════════════════════

  Widget _buildProfessionalCard(ProfessionalModel professional) {
    return _FeedCard(
      isOwn: false,
      onTap: () {
        final data = professional.toMap();
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProfessionalProfileScreen(
              professional: data,
              currentUserId: widget.localId,
              professionalId: professional.id,
              reportedId: professional.localId,
            ),
          ),
        );
      },
      child: _ProfessionalCardContent(
        professional: professional,
        isOwn: false,
        timeAgo: _timeAgo,
      ),
    );
  }

  Widget _buildOwnProfessionalCard(ProfessionalModel professional) {
    return _FeedCard(
      isOwn: true,
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MyProfessionalProfilePage(
            professional: professional,
            onEditProfile: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Acesse a aba "Vagas" para editar seu perfil'),
                  backgroundColor: Color(0xFFF59E0B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ),
      ),
      child: _ProfessionalCardContent(
        professional: professional,
        isOwn: true,
        timeAgo: _timeAgo,
      ),
    );
  }

  // ── SHIMMER ────────────────────────────────────────────────

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      itemCount: 4,
      itemBuilder: (_, i) => _ShimmerCard(withImage: i % 2 == 0),
    );
  }

  // ── EMPTY STATE ────────────────────────────────────────────

  Widget _buildEmptyState(FeedController controller) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height - 240,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                    color: _indigoSoft, shape: BoxShape.circle),
                child: const Icon(Icons.inbox_outlined,
                    size: 52, color: _indigo),
              ),
              const SizedBox(height: 20),
              const Text('Nenhum item encontrado',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _ink)),
              const SizedBox(height: 6),
              const Text('Tente ajustar os filtros ou volte mais tarde',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: _muted)),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () async {
                  await controller.clearFilters();
                  setState(() => _locationFilter = LocationFilter.all);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                  decoration: BoxDecoration(
                    color: _indigoSoft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _indigo.withOpacity(0.3)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, color: _indigo, size: 16),
                    SizedBox(width: 6),
                    Text('Limpar filtros',
                        style: TextStyle(
                            color: _indigo,
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── FAB ────────────────────────────────────────────────────

  Widget _buildFAB() => FloatingActionButton.extended(
        onPressed: widget.onNavigateToVacancies,
        backgroundColor: _indigo,
        elevation: 3,
        label: const Text('Minhas Vagas',
            style: TextStyle(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: Colors.white)),
        icon: const Icon(Icons.work_outline_rounded, color: Colors.white),
      );

  // ── FILTROS AVANÇADOS ──────────────────────────────────────

  void _showAdvancedFilters(FeedController c) {
    String? _selectedState = c.filterState;
    String? _selectedCity = c.filterCity;
    String? _selectedProfession = c.preferredProfession;
    final _ibgeService = IBGEService();
    List<Estado> _estados = [];
    List<Cidade> _cidades = [];
    bool _loadingEstados = true;
    bool _loadingCidades = false;

    final _states = [
      'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
      'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
    ];
    final _professions = [
      'Ajudante Geral','Almoxarife','Apontador de Obras','Aplicador de Revestimento',
      'Armador','Arquiteto','Asfaltador','Auxiliar Administrativo de Obras',
      'Auxiliar de Almoxarifado','Auxiliar de Obras','Azulejista','Bombeiro Hidráulico',
      'Carpinteiro','Carpinteiro de Formas','Ceramista','Comprador','Concreteiro',
      'Coordenador de Projetos','Cortador de Concreto','Demolidor','Desenhista Técnico',
      'Divisorista (Drywall)','Eletricista','Eletricista de Obras','Eletricista Industrial',
      'Encanador','Encarregado de Obras','Engenheiro Ambiental','Engenheiro Civil',
      'Engenheiro de Estruturas','Engenheiro de Fundações','Engenheiro de Segurança do Trabalho',
      'Engenheiro Geotécnico','Ensaiador de Materiais','Estucador','Ferreiro','Fiscal de Obras',
      'Forrador','Fundador','Gasista','Gerente de Obras','Gesseiro','Gessista','Graniteiro',
      'Impermeabilizador','Inspetor de Qualidade','Instalador de Ar Condicionado',
      'Instalador de Calhas','Instalador de CFTV','Instalador de Elevadores',
      'Instalador de Esquadrias','Instalador de Estruturas Metálicas','Instalador de Forro',
      'Instalador de Gás','Instalador de Piscinas','Instalador de Rede de Dados',
      'Instalador de Rufos','Instalador de Sistemas de Segurança','Instalador de Telefonia',
      'Instalador de Telhas','Instalador Hidráulico','Jardineiro de Obras','Laboratorista',
      'Ladrilheiro','Marceneiro','Marmorista','Mestre de Obras','Montador',
      'Montador de Andaimes','Montador de Móveis','Motorista de Caminhão',
      'Motorista de Caminhão Basculante','Operador de Betoneira','Operador de Empilhadeira',
      'Operador de Escavadeira','Operador de Guindaste','Operador de Jato de Areia',
      'Operador de Máquinas','Operador de Motoniveladora','Operador de Munck',
      'Operador de Pá Carregadeira','Operador de Retroescavadeira','Operador de Rolo Compactador',
      'Operador de Trator','Orçamentista','Paisagista','Pavimentador','Pedreiro','Perfurador',
      'Pintor','Pintor de Obras','Planejador de Obras','Poçeiro','Projetista','Rebocador',
      'Recuperador de Estruturas','Reparador','Restaurador','Serralheiro','Servente',
      'Servente de Obras','Servente de Pedreiro','Soldador','Técnico de Manutenção Predial',
      'Técnico em Controle de Qualidade','Técnico em Elevadores','Tecnólogo em Construção Civil',
      'Telhador','Texturizador','Topógrafo','Vidraceiro','Vigia de Obras','Zelador de Obras'
    ]..sort();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          String? safeProfession;
          if (_selectedProfession != null &&
              _professions.contains(_selectedProfession)) {
            safeProfession = _selectedProfession;
          }

          if (_loadingEstados && _estados.isEmpty) {
            _ibgeService.getEstados().then((estados) {
              if (mounted)
                setState(() {
                  _estados = estados;
                  _loadingEstados = false;
                  if (_selectedState != null) {
                    _loadingCidades = true;
                    _ibgeService
                        .getCidadesPorEstado(_selectedState!)
                        .then((cidades) {
                      if (mounted)
                        setState(() {
                          _cidades = cidades;
                          _loadingCidades = false;
                        });
                    });
                  }
                });
            });
          }

          return Container(
            decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                            color: _border,
                            borderRadius: BorderRadius.circular(2))),
                  ),
                  const SizedBox(height: 18),
                  const Text('Filtros',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _ink,
                          letterSpacing: -0.3)),
                  const SizedBox(height: 4),
                  const Text('Refine sua busca',
                      style: TextStyle(fontSize: 13, color: _muted)),
                  const SizedBox(height: 20),

                  _filterLabel('ESTADO'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedState,
                    decoration:
                        _filterDeco('Todos os estados', Icons.map_outlined),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Todos os estados')),
                      ..._states.map((s) => DropdownMenuItem<String>(
                          value: s, child: Text(s))),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _selectedState = v;
                        _selectedCity = null;
                        _cidades = [];
                        if (v != null) {
                          _loadingCidades = true;
                          _ibgeService.getCidadesPorEstado(v).then((cidades) {
                            if (mounted)
                              setState(() {
                                _cidades = cidades;
                                _loadingCidades = false;
                              });
                          });
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  _filterLabel('CIDADE'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedCity,
                    isExpanded: true,
                    decoration: _filterDeco(
                      _loadingCidades
                          ? 'Carregando cidades...'
                          : (_selectedState == null
                              ? 'Selecione um estado primeiro'
                              : 'Todas as cidades'),
                      Icons.location_city_outlined,
                    ),
                    selectedItemBuilder: (context) => [
                      const Text('Todas as cidades'),
                      if (_selectedState != null)
                        ..._cidades.map((c) => Text(c.nome,
                            overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    items: _selectedState == null
                        ? [
                            const DropdownMenuItem<String>(
                                value: null,
                                child:
                                    Text('Selecione um estado primeiro'))
                          ]
                        : [
                            const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Todas as cidades')),
                            ..._cidades.map((c) => DropdownMenuItem<String>(
                                value: c.nome, child: Text(c.nome))),
                          ],
                    onChanged:
                        _selectedState == null || _loadingCidades
                            ? null
                            : (v) => setState(() => _selectedCity = v),
                  ),
                  const SizedBox(height: 14),

                  _filterLabel('PROFISSÃO'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: safeProfession,
                    isExpanded: true,
                    decoration: _filterDeco(
                        'Todas as profissões', Icons.work_outline_rounded),
                    selectedItemBuilder: (context) => [
                      const Text('Todas as profissões'),
                      ..._professions.map((p) => Text(p,
                          overflow: TextOverflow.ellipsis, maxLines: 1)),
                    ],
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('Todas as profissões')),
                      ..._professions.map((p) => DropdownMenuItem<String>(
                          value: p, child: Text(p))),
                    ],
                    onChanged: (v) => setState(() => _selectedProfession = v),
                  ),
                  const SizedBox(height: 22),

                  Row(children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          setState(() {
                            _selectedState = null;
                            _selectedCity = null;
                            _selectedProfession = null;
                          });
                          await c.clearFilters();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _border),
                          ),
                          child: const Center(
                            child: Text('Limpar',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _muted,
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: GestureDetector(
                        onTap: () async {
                          await c.applyFilters(
                              state: _selectedState,
                              city: _selectedCity,
                              profession: _selectedProfession);
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: _indigo,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Text('Aplicar filtros',
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    fontSize: 14)),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filterLabel(String t) => Text(t,
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 0.6));

  InputDecoration _filterDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 13, color: _muted),
        prefixIcon: Icon(icon, size: 18, color: _muted),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _indigo, width: 1.5)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ── VACANCY CARD CONTENT ──────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

class _VacancyCardContent extends StatelessWidget {
  final VacancyModel vacancy;
  final bool isOwn;
  final String Function(String) formatSalary;
  final String Function(String) timeAgo;
  final Color Function(String, int) profColor;

  const _VacancyCardContent({
    required this.vacancy,
    required this.isOwn,
    required this.formatSalary,
    required this.timeAgo,
    required this.profColor,
  });

  static const _ink   = Color(0xFF111827);
  static const _muted = Color(0xFF6B7280);
  static const _border = Color(0xFFE5E7EB);
  static const _green = Color(0xFF059669);
  static const _greenSoft = Color(0xFFECFDF5);
  static const _greenMid  = Color(0xFFA7F3D0);

  Color get _primary => isOwn ? _green : profColor(vacancy.profession, 0);
  Color get _soft    => isOwn ? _greenSoft : profColor(vacancy.profession, 1);
  Color get _mid     => isOwn ? _greenMid  : profColor(vacancy.profession, 2);

  List<String> get _validImages =>
      vacancy.images.where((img) => img.isNotEmpty).toList();

  bool get _salaryIsText {
    final s = formatSalary(vacancy.salary);
    return s == 'A combinar' || s == 'Por empreitada';
  }

  @override
  Widget build(BuildContext context) {
    final ago = timeAgo(vacancy.createdAt);
    final salary = formatSalary(vacancy.salary);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header ──────────────────────────────────────────────
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _soft,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(Icons.work_rounded, color: _primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Profissão em destaque
            if (vacancy.profession.isNotEmpty)
              Text(
                vacancy.profession.toUpperCase(),
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: _primary,
                    letterSpacing: 0.6),
              ),
            const SizedBox(height: 3),
            Text(
              vacancy.company.isNotEmpty ? vacancy.company : vacancy.profession,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: _ink,
                  height: 1.2,
                  letterSpacing: -0.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (ago.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 11, color: _muted),
                const SizedBox(width: 3),
                Text(ago,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: _muted,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
          ]),
        ),
        const SizedBox(width: 8),
        isOwn ? _ownBadge() : _newBadge(),
      ]),

      // ── Imagens ────────────────────────────────────────────
      if (_validImages.isNotEmpty) ...[
        const SizedBox(height: 14),
        _buildImageStrip(_validImages),
      ],

      const SizedBox(height: 14),
      Divider(height: 1, color: _border.withOpacity(0.7)),
      const SizedBox(height: 14),

      // ── Bloco salário (estilo VacancyCardWithExpiration) ────
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _mid,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _salaryIsText
                  ? Icons.help_outline_rounded
                  : Icons.payments_rounded,
              color: _primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SALÁRIO',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(
                salary,
                style: TextStyle(
                    fontSize: _salaryIsText ? 16 : 20,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                    height: 1,
                    letterSpacing: -0.5),
              ),
            ]),
          ),
        ]),
      ),

      const SizedBox(height: 10),

      // ── Chips secundários ────────────────────────────────────
      Wrap(spacing: 6, runSpacing: 6, children: [
        _infoChip(
            '${vacancy.city}, ${vacancy.state}', Icons.location_on_rounded),
        if (vacancy.legalType.isNotEmpty)
          _infoChip(
              vacancy.legalType.toUpperCase(), Icons.badge_rounded),
        _infoChip(
            _ageLabel(vacancy.createdAt), Icons.calendar_today_rounded),
        if (_validImages.isNotEmpty)
          _infoChip(
              '${_validImages.length} ${_validImages.length == 1 ? 'foto' : 'fotos'}',
              Icons.photo_library_rounded),
      ]),

      // ── Descrição ────────────────────────────────────────────
      if (vacancy.description.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(vacancy.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: _muted)),
      ],

      const SizedBox(height: 14),

      // ── CTA ──────────────────────────────────────────────────
      _ctaButton(
        label: isOwn ? 'Gerenciar minha vaga' : 'Ver detalhes e candidatar-se',
        icon: isOwn ? Icons.visibility_rounded : Icons.arrow_forward_rounded,
      ),
    ]);
  }

  String _ageLabel(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final diff = DateTime.now().difference(dt).inDays;
      if (diff == 0) return 'Publicada hoje';
      if (diff == 1) return 'Publicada ontem';
      if (diff < 7) return 'Há $diff dias';
      return 'Há ${(diff / 7).floor()} sem.';
    } catch (_) {
      return 'Recente';
    }
  }

  // ── Image strip ────────────────────────────────────────────

  Widget _buildImageStrip(List<String> images) {
    const double h = 190;
    const double r = 12.0;

    Widget img(String url,
        {BorderRadius? br, double? w, double height = h, bool overlay = false}) {
      return SizedBox(
        width: w,
        height: height,
        child: ClipRRect(
          borderRadius: br ?? BorderRadius.circular(r),
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: const Color(0xFFF3F4F6),
                child: const Center(
                    child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF9CA3AF)))),
              ),
              errorWidget: (_, __, ___) => Container(
                color: const Color(0xFFF3F4F6),
                child: const Icon(Icons.image_outlined,
                    size: 28, color: Color(0xFF9CA3AF)),
              ),
              memCacheWidth: 600,
              memCacheHeight: 500,
            ),
            if (overlay)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.22)
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
          ]),
        ),
      );
    }

    if (images.length == 1) {
      return Stack(children: [
        img(images[0], w: double.infinity, overlay: true),
        Positioned(
          bottom: 8,
          right: 10,
          child: _imgCountBadge(1),
        ),
      ]);
    }

    if (images.length == 2) {
      return SizedBox(
        height: h,
        child: Row(children: [
          Expanded(
              child: img(images[0],
                  br: const BorderRadius.only(
                      topLeft: Radius.circular(r),
                      bottomLeft: Radius.circular(r)))),
          const SizedBox(width: 3),
          Expanded(
              child: img(images[1],
                  br: const BorderRadius.only(
                      topRight: Radius.circular(r),
                      bottomRight: Radius.circular(r)))),
        ]),
      );
    }

    // 3+ imagens
    final extra = images.length > 3 ? images.length - 3 : 0;
    final smallH = (h - 3) / 2;

    return Stack(children: [
      SizedBox(
        height: h,
        child: Row(children: [
          Expanded(
            flex: 3,
            child: img(images[0],
                overlay: true,
                br: const BorderRadius.only(
                    topLeft: Radius.circular(r),
                    bottomLeft: Radius.circular(r))),
          ),
          const SizedBox(width: 3),
          Expanded(
            flex: 2,
            child: Column(children: [
              img(images[1],
                  height: smallH,
                  br: const BorderRadius.only(
                      topRight: Radius.circular(r))),
              const SizedBox(height: 3),
              Stack(children: [
                img(images[2],
                    height: smallH,
                    br: const BorderRadius.only(
                        bottomRight: Radius.circular(r))),
                if (extra > 0)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(r)),
                      child: Container(
                        color: Colors.black.withOpacity(0.52),
                        child: Center(
                          child: Text('+$extra',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
      Positioned(
        bottom: 8,
        right: 10,
        child: _imgCountBadge(images.length),
      ),
    ]);
  }

  Widget _imgCountBadge(int count) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.55),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_rounded,
              size: 11, color: Colors.white),
          const SizedBox(width: 4),
          Text('$count ${count == 1 ? "foto" : "fotos"}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ]),
      );

  // ── Shared widgets ─────────────────────────────────────────

  Widget _ownBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _greenSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _greenMid.withOpacity(0.8)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, size: 10, color: _green),
          SizedBox(width: 4),
          Text('MINHA',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: _green,
                  letterSpacing: 0.6)),
        ]),
      );

  Widget _newBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('NOVO',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
                letterSpacing: 0.6)),
      );

  Widget _infoChip(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: _muted),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11.5,
                  color: _muted,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _ctaButton({required String label, required IconData icon}) =>
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          const SizedBox(width: 6),
          Icon(icon, size: 15, color: Colors.white),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ── PROFESSIONAL CARD CONTENT ─────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

class _ProfessionalCardContent extends StatelessWidget {
  final ProfessionalModel professional;
  final bool isOwn;
  final String Function(String) timeAgo;

  const _ProfessionalCardContent({
    required this.professional,
    required this.isOwn,
    required this.timeAgo,
  });

  static const _indigo      = Color(0xFF2563EB);
  static const _indigoSoft  = Color(0xFFEFF6FF);
  static const _indigoMid   = Color(0xFFDBEAFE);
  static const _green       = Color(0xFF059669);
  static const _greenSoft   = Color(0xFFECFDF5);
  static const _greenMid    = Color(0xFFA7F3D0);
  static const _ink         = Color(0xFF111827);
  static const _muted       = Color(0xFF6B7280);
  static const _border      = Color(0xFFE5E7EB);

  Color get _primary => isOwn ? _green  : _indigo;
  Color get _soft    => isOwn ? _greenSoft : _indigoSoft;
  Color get _mid     => isOwn ? _greenMid  : _indigoMid;

  @override
  Widget build(BuildContext context) {
    final ago = timeAgo(professional.updatedAt);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── Header com Avatar ──────────────────────────────────
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(clipBehavior: Clip.none, children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _soft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _primary.withOpacity(0.4),
                  width: isOwn ? 2.5 : 2),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: professional.avatar.isEmpty
                  ? Icon(Icons.person_rounded, color: _primary, size: 30)
                  : CachedNetworkImage(
                      imageUrl: professional.avatar,
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          Icon(Icons.person_rounded, color: _primary, size: 30),
                      errorWidget: (_, __, ___) =>
                          Icon(Icons.person_rounded, color: _primary, size: 30),
                      memCacheWidth: 120,
                      memCacheHeight: 120,
                    ),
            ),
          ),
          if (isOwn)
            Positioned(
              right: -3,
              bottom: -3,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                    color: _primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5)),
                child: const Icon(Icons.check, color: Colors.white, size: 10),
              ),
            ),
        ]),

        const SizedBox(width: 13),

        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(professional.name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: _ink,
                    letterSpacing: -0.2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                  color: _soft, borderRadius: BorderRadius.circular(7)),
              child: Text(professional.profession,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: _primary,
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (ago.isNotEmpty) ...[
              const SizedBox(height: 5),
              Row(children: [
                Icon(Icons.access_time_rounded, size: 11, color: _muted),
                const SizedBox(width: 3),
                Text(ago,
                    style: const TextStyle(
                        fontSize: 10.5,
                        color: _muted,
                        fontWeight: FontWeight.w500)),
              ]),
            ],
          ]),
        ),

        const SizedBox(width: 8),
        isOwn ? _ownBadge() : _newBadge(),
      ]),

      const SizedBox(height: 14),
      Divider(height: 1, color: _border.withOpacity(0.7)),
      const SizedBox(height: 14),

      // ── Bloco de disponibilidade / info ────────────────────
      Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _mid,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person_search_rounded, color: _primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('DISPONÍVEL PARA',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9CA3AF),
                      letterSpacing: 0.5)),
              const SizedBox(height: 2),
              Text(
                professional.legalType.isNotEmpty
                    ? professional.legalType
                    : 'Oportunidades',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: _primary,
                    height: 1,
                    letterSpacing: -0.3),
              ),
            ]),
          ),
        ]),
      ),

      const SizedBox(height: 10),

      // ── Localização + Empresa como chips ───────────────────
      Wrap(spacing: 6, runSpacing: 6, children: [
        _locationChip('${professional.city}, ${professional.state}'),
        if (professional.company.isNotEmpty)
          _locationChip(professional.company, icon: Icons.apartment_rounded),
      ]),

      // ── Skills ─────────────────────────────────────────────
      if (professional.skills.isNotEmpty &&
          !professional.skills.contains('Nenhuma habilidade definida')) ...[
        const SizedBox(height: 10),
        Wrap(
          spacing: 5,
          runSpacing: 5,
          children: professional.skills.take(5).map((skill) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _border),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.stars_rounded,
                    size: 10, color: _primary.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(skill,
                    style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF374151),
                        fontWeight: FontWeight.w600)),
              ]),
            );
          }).toList(),
        ),
      ],

      // ── Resumo ─────────────────────────────────────────────
      if (professional.summary.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text(professional.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13, height: 1.5, color: _muted)),
      ],

      const SizedBox(height: 14),

      // ── CTA ────────────────────────────────────────────────
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: _primary,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(
            isOwn ? 'Ver meu perfil' : 'Ver perfil completo',
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: Colors.white),
          ),
          const SizedBox(width: 6),
          Icon(
            isOwn ? Icons.visibility_rounded : Icons.arrow_forward_rounded,
            size: 15,
            color: Colors.white,
          ),
        ]),
      ),
    ]);
  }

  Widget _locationChip(String label,
          {IconData icon = Icons.location_on_rounded}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: _soft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12, color: _primary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    color: _primary,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
        ]),
      );

  Widget _ownBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _greenSoft,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _greenMid.withOpacity(0.8)),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.verified_rounded, size: 10, color: _green),
          SizedBox(width: 4),
          Text('MEU',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: _green,
                  letterSpacing: 0.6)),
        ]),
      );

  Widget _newBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _indigoSoft,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('NOVO',
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                color: _indigo,
                letterSpacing: 0.6)),
      );
}

// ══════════════════════════════════════════════════════════════════════════════
// ── FEED CARD WRAPPER ─────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

class _FeedCard extends StatelessWidget {
  final bool isOwn;
  final VoidCallback onTap;
  final Widget child;

  const _FeedCard(
      {required this.isOwn, required this.onTap, required this.child});

  static const _green  = Color(0xFF059669);
  static const _indigo = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) {
    final primary = isOwn ? _green : _indigo;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.09),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: primary.withOpacity(0.05),
            child: Column(children: [
              // Barra de cor no topo (gradiente como VacancyCardWithExpiration)
              Container(
                height: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [primary, primary.withOpacity(0.65)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: child,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── SHIMMER ───────────────────────────────────────────────────────────────────
// ══════════════════════════════════════════════════════════════════════════════

class _ShimmerCard extends StatefulWidget {
  final bool withImage;
  const _ShimmerCard({this.withImage = false});

  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 0.85)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 14,
                offset: const Offset(0, 3)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Barra topo
            Container(
              height: 5,
              color: Colors.grey.shade200,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  _b(48, 48, r: 13),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    _bf(100, 11),
                    const SizedBox(height: 5),
                    _bf(160, 15),
                    const SizedBox(height: 5),
                    _bf(80, 10),
                  ])),
                  const SizedBox(width: 8),
                  _b(46, 22, r: 8),
                ]),
                if (widget.withImage) ...[
                  const SizedBox(height: 14),
                  _bf(double.infinity, 190, r: 12),
                ],
                const SizedBox(height: 14),
                _bf(double.infinity, 1, r: 1),
                const SizedBox(height: 14),
                _bf(double.infinity, 68, r: 13),
                const SizedBox(height: 10),
                Row(children: [
                  _bf(90, 28, r: 8),
                  const SizedBox(width: 6),
                  _bf(80, 28, r: 8),
                  const SizedBox(width: 6),
                  _bf(70, 28, r: 8),
                ]),
                const SizedBox(height: 14),
                _bf(double.infinity, 46, r: 13),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _b(double w, double h, {double r = 6}) => Opacity(
      opacity: _anim.value,
      child: Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(r))));

  Widget _bf(double maxW, double h, {double r = 6}) => Opacity(
      opacity: _anim.value,
      child: Container(
          width: maxW == double.infinity ? double.infinity : null,
          constraints: maxW != double.infinity
              ? BoxConstraints(maxWidth: maxW)
              : null,
          height: h,
          decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(r))));
}

enum LocationFilter { all, sameCity, sameState }
