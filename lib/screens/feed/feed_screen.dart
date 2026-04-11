import 'package:dartobra_new/controllers/feed_controller.dart';
import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:dartobra_new/screens/search/my_vacancy_details_screen.dart';
import 'package:dartobra_new/screens/search/my_professional_profile_screen.dart';
import 'package:dartobra_new/services/search/ibge_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'professional_profile.dart';
import 'vacancy_detail.dart';

// =============================================================================
// ALTERAÇÕES NESTE ARQUIVO:
//  ✅ _timeAgo() – exibe há quanto tempo a vaga foi postada (em português)
//  ✅ Header do card de vaga mostra clock + tempo relativo abaixo da profissão
//  ✅ _buildImageStrip() – imagens mais chamativas:
//       • Altura aumentada para 200px
//       • Overlay gradiente sutil (transparente → preto 22%) para dar profundidade
//       • Shadow colorida no container (cor do tema)
//       • Layout 3+ imagens: proporção 3:2 (principal maior)
//       • Badge "+N" na última miniatura quando há mais de 3 fotos
//  ✅ Shimmer atualizado para refletir nova altura das imagens
// =============================================================================

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

  static const Color _primary       = Color(0xFF0A84FF);
  static const Color _bg            = Color(0xFFF4F6FA);
  static const Color _card          = Color(0xFFFFFFFF);
  static const Color _textPrimary   = Color(0xFF0D1B2A);
  static const Color _textSecondary = Color(0xFF6B7A8D);
  static const Color _accent        = Color(0xFF00C896);
  static const Color _tagBg         = Color(0xFFEBF4FF);
  static const Color _tagText       = Color(0xFF0A84FF);
  static const Color _ownGreen      = Color(0xFF1DB954);
  static const Color _ownGreenLight = Color(0xFFE8F8F0);
  static const Color _ownGreenBorder= Color(0xFF87DDB4);

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? widget.localId;

  // ── HELPER: tempo relativo em português ────────────────────────────────────
  String _timeAgo(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final diff = DateTime.now().difference(date);
      if (diff.inSeconds < 60)  return 'agora mesmo';
      if (diff.inMinutes < 60)  { final m = diff.inMinutes; return 'ha $m ${m == 1 ? 'minuto' : 'minutos'}'; }
      if (diff.inHours   < 24)  { final h = diff.inHours;   return 'ha $h ${h == 1 ? 'hora'   : 'horas'  }'; }
      if (diff.inDays    < 7)   { final d = diff.inDays;    return 'ha $d ${d == 1 ? 'dia'    : 'dias'   }'; }
      if (diff.inDays    < 30)  { final w = (diff.inDays / 7).floor();  return 'ha $w ${w == 1 ? 'semana' : 'semanas'}'; }
      if (diff.inDays    < 365) { final mo= (diff.inDays /30).floor();  return 'ha $mo ${mo==1 ? 'mes'    : 'meses'  }'; }
      final y = (diff.inDays / 365).floor();
      return 'ha $y ${y == 1 ? 'ano' : 'anos'}';
    } catch (_) { return ''; }
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
    final mode = widget.activeMode == 'worker' ? FeedMode.worker : FeedMode.contractor;
    String? preferredProfession;
    if (widget.dataContractor['preferred_profession'] != null) {
      preferredProfession = widget.dataContractor['preferred_profession'] as String?;
    }
    await controller.initialize(
      mode: mode, initialState: null, initialCity: null,
      preferredProfession: preferredProfession);
  }

  void _onScroll() {
    if (!mounted) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
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
    final city  = widget.userCity.toLowerCase().trim();
    final state = widget.userState.toLowerCase().trim();

    final vacancies = controller.filteredVacancies.where((v) {
      switch (_locationFilter) {
        case LocationFilter.sameCity:  return v.city.toLowerCase().trim()  == city;
        case LocationFilter.sameState: return v.state.toLowerCase().trim() == state;
        default: return true;
      }
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final professionals = controller.filteredProfessionals.where((p) {
      switch (_locationFilter) {
        case LocationFilter.sameCity:  return p.city.toLowerCase().trim()  == city;
        case LocationFilter.sameState: return p.state.toLowerCase().trim() == state;
        default: return true;
      }
    }).toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final List<dynamic> combined = [];
    int vi = 0, pi = 0;
    while (vi < vacancies.length || pi < professionals.length) {
      if (vi < vacancies.length)    combined.add(vacancies[vi++]);
      if (pi < professionals.length) combined.add(professionals[pi++]);
    }
    return combined;
  }

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
                Expanded(
                  child: controller.isLoading
                      ? _buildShimmerList()
                      : RefreshIndicator(
                          color: _primary,
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
      floatingActionButton: widget.onNavigateToVacancies != null ? _buildFAB() : null,
    );
  }

  Widget _buildTopBar(FeedController controller, int count) {
    final hasActive = controller.filterState != null ||
        controller.filterCity != null || controller.preferredProfession != null;
    return FadeTransition(
      opacity: _headerOpacity,
      child: Container(
        color: _card,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        child: Row(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_primary, _accent],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: _primary.withOpacity(0.3), offset: const Offset(0,3), blurRadius: 8)],
              ),
              child: const Icon(Icons.dynamic_feed_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Feed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textPrimary, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text(
                  hasActive ? '$count itens - Filtrado' : '$count itens - Vagas & Profissionais',
                  style: TextStyle(fontSize: 12, color: _textSecondary.withOpacity(0.8), fontWeight: FontWeight.w500)),
              ]),
            ),
            _buildFilterButton(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterButton(FeedController controller) {
    final hasActive = controller.filterState != null ||
        controller.filterCity != null || controller.preferredProfession != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showAdvancedFilters(controller),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: hasActive ? _tagBg : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: hasActive ? _primary.withOpacity(0.3) : Colors.transparent, width: 1),
          ),
          child: Stack(
            children: [
              Icon(Icons.tune_rounded, size: 20, color: hasActive ? _primary : _textSecondary),
              if (hasActive)
                Positioned(right: 0, top: 0,
                  child: Container(width: 6, height: 6,
                    decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: _card,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          _buildChip('Todas',      _locationFilter == LocationFilter.all,      Icons.public_rounded,        () => setState(() => _locationFilter = LocationFilter.all)),
          const SizedBox(width: 8),
          _buildChip('Minha cidade', _locationFilter == LocationFilter.sameCity, Icons.location_city_rounded, () => setState(() => _locationFilter = LocationFilter.sameCity)),
          const SizedBox(width: 8),
          _buildChip('Meu estado', _locationFilter == LocationFilter.sameState, Icons.map_rounded,           () => setState(() => _locationFilter = LocationFilter.sameState)),
        ]),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, IconData icon, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap, borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? _primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isSelected ? _primary : Colors.transparent, width: 1.5),
            boxShadow: isSelected ? [BoxShadow(color: _primary.withOpacity(0.3), offset: const Offset(0,2), blurRadius: 6)] : [],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : _textSecondary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500, color: isSelected ? Colors.white : _textSecondary, letterSpacing: 0.2)),
          ]),
        ),
      ),
    );
  }

  Widget _buildFeedList(FeedController controller, List<dynamic> items) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(bottom: 80, top: 8),
      itemCount: items.length + (controller.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: _primary)));
        }
        final item = items[index];
        if (item is VacancyModel) {
          final isOwn = item.localId == _currentUserId;
          return isOwn ? _buildOwnVacancyCard(item) : _buildVacancyCard(item);
        } else if (item is ProfessionalModel) {
          final isOwn = item.localId == _currentUserId;
          return isOwn ? _buildOwnProfessionalCard(item) : _buildProfessionalCard(item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  // ── VACANCY CARDS ──────────────────────────────────────────────────────────

  Widget _buildVacancyCard(VacancyModel vacancy) {
    return _FeedCardWrapper(
      isOwn: false,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => VacancyDetailsScreen(
          vacancy: vacancy.toMap(), currentUserId: widget.localId,
          vacancyId: vacancy.id, reportedId: vacancy.localId))),
      child: _vacancyCardContent(vacancy, isOwn: false),
    );
  }

  Widget _buildOwnVacancyCard(VacancyModel vacancy) {
    return _FeedCardWrapper(
      isOwn: true,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => MyVacancyDetailPage(
          vacancy: vacancy,
          onEditVacancy: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Va para a tela de Vagas para editar sua vaga'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
          },
          localId: widget.localId))),
      child: _vacancyCardContent(vacancy, isOwn: true),
    );
  }

  Widget _vacancyCardContent(VacancyModel vacancy, {required bool isOwn}) {
    final validImages = vacancy.images.where((img) => img.isNotEmpty).toList();
    final timeAgo = _timeAgo(vacancy.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isOwn ? _ownGreenLight : _tagBg,
                borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.work_outline, color: isOwn ? _ownGreen : _primary, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  vacancy.company.isNotEmpty ? vacancy.company : 'Empresa',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  vacancy.profession,
                  style: TextStyle(fontSize: 11, color: _textSecondary.withOpacity(0.8)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
                // ── Tempo relativo
                if (timeAgo.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.access_time_rounded, size: 11,
                      color: isOwn ? _ownGreen.withOpacity(0.7) : _textSecondary.withOpacity(0.55)),
                    const SizedBox(width: 3),
                    Text(timeAgo,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: isOwn ? _ownGreen.withOpacity(0.75) : _textSecondary.withOpacity(0.6),
                        fontWeight: FontWeight.w500, letterSpacing: 0.1)),
                  ]),
                ],
              ]),
            ),
            const SizedBox(width: 8),
            isOwn ? _ownBadge() : _newBadge(),
          ],
        ),

        // ── Imagens com destaque visual
        if (validImages.isNotEmpty) ...[
          const SizedBox(height: 14),
          _buildImageStrip(validImages, isOwn: isOwn),
        ],
        const SizedBox(height: 12),

        // ── Tags
        Wrap(spacing: 6, runSpacing: 6, children: [
          _buildTag('${vacancy.city}, ${vacancy.state}', Icons.location_on_outlined, isOwn),
          if (vacancy.salary.isNotEmpty)   _buildTag(vacancy.salary,    Icons.attach_money_outlined, isOwn),
          if (vacancy.legalType.isNotEmpty) _buildTag(vacancy.legalType, Icons.business_outlined,    isOwn),
        ]),
        const SizedBox(height: 12),

        // ── Descricao
        if (vacancy.description.isNotEmpty)
          Text(vacancy.description, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, height: 1.4, color: _textSecondary.withOpacity(0.9))),
        const SizedBox(height: 14),

        // ── Botao
        _buildActionButton(
          label: isOwn ? 'Ver minha vaga' : 'Ver detalhes',
          icon:  isOwn ? Icons.visibility_outlined : Icons.arrow_forward_rounded,
          isOwn: isOwn),
      ],
    );
  }

  // ── IMAGE STRIP APRIMORADO ─────────────────────────────────────────────────
  // Altura aumentada para 200px, overlay gradiente, shadow colorida,
  // proporcao 3:2 para layout de 3+ imagens, badge "+N" para extras.
  Widget _buildImageStrip(List<String> images, {required bool isOwn}) {
    const double height = 200;
    const double radius = 14.0;
    final Color accent = isOwn ? _ownGreen : _primary;

    // Overlay gradiente sutil: transparente -> preto 22%
    final overlayGrad = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black.withOpacity(0.22)],
      stops: const [0.5, 1.0],
    );

    // ── widget de imagem individual
    Widget img(String url, {BorderRadius? br, double? w, double h = height, bool overlay = true}) {
      return Container(
        width: w, height: h,
        decoration: BoxDecoration(
          borderRadius: br ?? BorderRadius.circular(radius),
          boxShadow: [BoxShadow(color: accent.withOpacity(0.16), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: ClipRRect(
          borderRadius: br ?? BorderRadius.circular(radius),
          child: Stack(fit: StackFit.expand, children: [
            CachedNetworkImage(
              imageUrl: url, width: w, height: h, fit: BoxFit.cover,
              placeholder: (_, __) => Container(
                color: Colors.grey.shade100,
                child: Center(child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: accent)))),
              errorWidget: (_, __, ___) => Container(
                color: Colors.grey.shade100,
                child: Icon(Icons.image_outlined, size: 32, color: Colors.grey.shade400)),
              memCacheWidth: 800, memCacheHeight: 600,
            ),
            if (overlay)
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: overlayGrad))),
          ]),
        ),
      );
    }

    // ── 1 imagem: largura total
    if (images.length == 1) {
      return img(images[0], w: double.infinity, h: height);
    }

    // ── 2 imagens: lado a lado
    if (images.length == 2) {
      return SizedBox(height: height,
        child: Row(children: [
          Expanded(child: img(images[0],
            br: const BorderRadius.only(topLeft: Radius.circular(radius), bottomLeft: Radius.circular(radius)))),
          const SizedBox(width: 4),
          Expanded(child: img(images[1],
            br: const BorderRadius.only(topRight: Radius.circular(radius), bottomRight: Radius.circular(radius)))),
        ]),
      );
    }

    // ── 3+ imagens: principal (flex 3) + coluna 2 miniaturas (flex 2)
    final extra  = images.length > 3 ? images.length - 3 : 0;
    final smallH = (height - 4) / 2;

    return SizedBox(height: height,
      child: Row(children: [
        // Imagem principal – maior, ocupa mais espaco
        Expanded(flex: 3,
          child: img(images[0],
            br: const BorderRadius.only(topLeft: Radius.circular(radius), bottomLeft: Radius.circular(radius)))),
        const SizedBox(width: 4),
        // Coluna direita: 2 miniaturas
        Expanded(flex: 2,
          child: Column(children: [
            img(images[1], h: smallH, overlay: false,
              br: const BorderRadius.only(topRight: Radius.circular(radius))),
            const SizedBox(height: 4),
            // Terceira imagem com badge "+N" se houver mais fotos
            Stack(children: [
              img(images[2], h: smallH,
                overlay: extra > 0,
                br: const BorderRadius.only(bottomRight: Radius.circular(radius))),
              if (extra > 0)
                Positioned.fill(child: ClipRRect(
                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(radius)),
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Center(child: Text('+$extra',
                      style: const TextStyle(color: Colors.white, fontSize: 22,
                        fontWeight: FontWeight.bold, letterSpacing: 0.5)))))),
            ]),
          ])),
      ]),
    );
  }

  // ── PROFESSIONAL CARDS (sem alteracoes) ────────────────────────────────────

  Widget _buildProfessionalCard(ProfessionalModel professional) {
    return _FeedCardWrapper(
      isOwn: false,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => ProfessionalProfileScreen(
          professional: professional.toMap(), currentUserId: widget.localId,
          professionalId: professional.id, reportedId: professional.localId))),
      child: _professionalCardContent(professional, isOwn: false),
    );
  }

  Widget _buildOwnProfessionalCard(ProfessionalModel professional) {
    return _FeedCardWrapper(
      isOwn: true,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => MyProfessionalProfilePage(
          professional: professional,
          onEditProfile: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Va para a tela de Perfil para editar seu perfil'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));
          }))),
      child: _professionalCardContent(professional, isOwn: true),
    );
  }

  Widget _professionalCardContent(ProfessionalModel professional, {required bool isOwn}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Stack(children: [
          _buildOptimizedAvatar(professional.avatar, isOwn),
          if (isOwn) Positioned(bottom: 0, right: 0,
            child: Container(width: 14, height: 14,
              decoration: BoxDecoration(color: _ownGreen, shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.check, color: Colors.white, size: 8))),
        ]),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(professional.name,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _textPrimary),
            maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(professional.profession,
            style: TextStyle(fontSize: 12, color: _textSecondary.withOpacity(0.8), fontWeight: FontWeight.w500),
            maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        isOwn ? _ownBadge() : _newBadge(),
      ]),
      const SizedBox(height: 14),
      Wrap(spacing: 6, runSpacing: 6, children: [
        _buildTag('${professional.city}, ${professional.state}', Icons.location_on_outlined, isOwn),
        if (professional.company.isNotEmpty)   _buildTag(professional.company,   Icons.business_outlined, isOwn),
        if (professional.legalType.isNotEmpty) _buildTag(professional.legalType, Icons.badge_outlined,    isOwn),
      ]),
      if (professional.skills.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6,
          children: professional.skills.take(3).map((skill) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color:  isOwn ? _ownGreen.withOpacity(0.10) : _primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isOwn ? _ownGreen.withOpacity(0.3) : _primary.withOpacity(0.2), width: 1)),
            child: Text(skill,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: isOwn ? _ownGreen : _primary, letterSpacing: 0.2)),
          )).toList()),
      ],
      if (professional.summary.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(professional.summary, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, height: 1.4, color: _textSecondary.withOpacity(0.9))),
      ],
      const SizedBox(height: 14),
      _buildActionButton(
        label: isOwn ? 'Ver meu perfil' : 'Ver perfil',
        icon:  isOwn ? Icons.visibility_outlined : Icons.arrow_forward_rounded,
        isOwn: isOwn),
    ]);
  }

  // ── SHARED WIDGETS ─────────────────────────────────────────────────────────

  Widget _buildOptimizedAvatar(String avatarUrl, bool isOwn) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: isOwn ? _ownGreenLight : _tagBg,
      child: avatarUrl.isEmpty
          ? Icon(Icons.person, color: isOwn ? _ownGreen : _primary, size: 26)
          : ClipOval(child: CachedNetworkImage(
              imageUrl: avatarUrl, width: 52, height: 52, fit: BoxFit.cover,
              placeholder:   (c, u) => Icon(Icons.person, color: isOwn ? _ownGreen : _primary, size: 26),
              errorWidget:   (c, u, e) => Icon(Icons.person, color: isOwn ? _ownGreen : _primary, size: 26),
              memCacheWidth: 100, memCacheHeight: 100)),
    );
  }

  Widget _ownBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: _ownGreenLight, borderRadius: BorderRadius.circular(8),
      border: Border.all(color: _ownGreenBorder, width: 1)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.check_circle_outline_rounded, size: 11, color: _ownGreen),
      const SizedBox(width: 4),
      Text('MEU', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _ownGreen, letterSpacing: 0.5)),
    ]),
  );

  Widget _newBadge() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: _accent.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
    child: const Text('NOVO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _accent, letterSpacing: 0.5)),
  );

  Widget _buildTag(String label, IconData icon, bool isOwn) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: isOwn ? _ownGreenLight : _tagBg, borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: isOwn ? _ownGreen : _tagText),
        const SizedBox(width: 4),
        Flexible(child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
            color: isOwn ? _ownGreen : _tagText, letterSpacing: 0.2),
          maxLines: 1, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required bool isOwn}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOwn ? [_ownGreen, const Color(0xFF17A248)] : [_primary, _accent],
          begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(
          color: (isOwn ? _ownGreen : _primary).withOpacity(0.3),
          offset: const Offset(0, 3), blurRadius: 8)],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
        const SizedBox(width: 6),
        Icon(icon, color: Colors.white, size: 16),
      ]),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8),
      itemCount: 5,
      itemBuilder: (context, index) => const _ShimmerCard(),
    );
  }

  Widget _buildEmptyState(FeedController controller) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: _tagBg, shape: BoxShape.circle),
            child: const Icon(Icons.inbox_outlined, size: 64, color: _primary)),
          const SizedBox(height: 24),
          const Text('Nenhum item encontrado',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textPrimary)),
          const SizedBox(height: 8),
          Text('Tente ajustar os filtros ou volte mais tarde',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _textSecondary.withOpacity(0.8))),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              await controller.clearFilters();
              setState(() => _locationFilter = LocationFilter.all);
            },
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Limpar filtros'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
        ]),
      ),
    );
  }

  Widget _buildFAB() => FloatingActionButton.extended(
    onPressed: widget.onNavigateToVacancies,
    backgroundColor: _primary, elevation: 4,
    label: const Text('Minhas Vagas', style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3)),
    icon: const Icon(Icons.work_outline),
  );

  void _showAdvancedFilters(FeedController c) {
    String? _selectedState      = c.filterState;
    String? _selectedCity       = c.filterCity;
    String? _selectedProfession = c.preferredProfession;
    final _ibgeService  = IBGEService();
    List<Estado> _estados = [];
    List<Cidade> _cidades = [];
    bool _loadingEstados = true;
    bool _loadingCidades = false;

    final _states = ['AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG','PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'];
    final _professions = ['Ajudante Geral','Almoxarife','Apontador de Obras','Aplicador de Revestimento','Armador','Arquiteto','Asfaltador','Auxiliar Administrativo de Obras','Auxiliar de Almoxarifado','Auxiliar de Obras','Azulejista','Bombeiro Hidraulico','Carpinteiro','Carpinteiro de Formas','Ceramista','Comprador','Concreteiro','Coordenador de Projetos','Cortador de Concreto','Demolidor','Desenhista Tecnico','Divisorista (Drywall)','Eletricista','Eletricista de Obras','Eletricista Industrial','Encanador','Encarregado de Obras','Engenheiro Ambiental','Engenheiro Civil','Engenheiro de Estruturas','Engenheiro de Fundacoes','Engenheiro de Seguranca do Trabalho','Engenheiro Geotecnico','Ensaiador de Materiais','Estucador','Ferreiro','Fiscal de Obras','Forrador','Fundador','Gasista','Gerente de Obras','Gesseiro','Gessista','Graniteiro','Impermeabilizador','Inspetor de Qualidade','Instalador de Ar Condicionado','Instalador de Calhas','Instalador de CFTV','Instalador de Elevadores','Instalador de Esquadrias','Instalador de Estruturas Metalicas','Instalador de Forro','Instalador de Gas','Instalador de Piscinas','Instalador de Rede de Dados','Instalador de Rufos','Instalador de Sistemas de Seguranca','Instalador de Telefonia','Instalador de Telhas','Instalador Hidraulico','Jardineiro de Obras','Laboratorista','Ladrilheiro','Marceneiro','Marmorista','Mestre de Obras','Montador','Montador de Andaimes','Montador de Moveis','Motorista de Caminhao','Motorista de Caminhao Basculante','Operador de Betoneira','Operador de Empilhadeira','Operador de Escavadeira','Operador de Guindaste','Operador de Jato de Areia','Operador de Maquinas','Operador de Motoniveladora','Operador de Munck','Operador de Pa Carregadeira','Operador de Retroescavadeira','Operador de Rolo Compactador','Operador de Trator','Orcamentista','Paisagista','Pavimentador','Pedreiro','Perfurador','Pintor','Pintor de Obras','Planejador de Obras','Poceiro','Projetista','Rebocador','Recuperador de Estruturas','Reparador','Restaurador','Serralheiro','Servente','Servente de Obras','Servente de Pedreiro','Soldador','Tecnico de Manutencao Predial','Tecnico em Controle de Qualidade','Tecnico em Elevadores','Tecnologo em Construcao Civil','Telhador','Texturizador','Topografo','Vidraceiro','Vigia de Obras','Zelador de Obras']..sort();

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          String? safeProfession;
          if (_selectedProfession != null && _professions.contains(_selectedProfession)) safeProfession = _selectedProfession;

          if (_loadingEstados && _estados.isEmpty) {
            _ibgeService.getEstados().then((estados) {
              if (mounted) setState(() {
                _estados = estados; _loadingEstados = false;
                if (_selectedState != null) {
                  _loadingCidades = true;
                  _ibgeService.getCidadesPorEstado(_selectedState!).then((cidades) {
                    if (mounted) setState(() { _cidades = cidades; _loadingCidades = false; });
                  });
                }
              });
            });
          }

          return Container(
            decoration: const BoxDecoration(color: _card, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                const Text('Filtros Avancados', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textPrimary)),
                const SizedBox(height: 8),
                Text('Refine sua busca com filtros personalizados', style: TextStyle(fontSize: 14, color: _textSecondary.withOpacity(0.8))),
                const SizedBox(height: 24),

                _label('ESTADO'), const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedState, decoration: _deco('Todos os estados', Icons.map_outlined),
                  items: [const DropdownMenuItem<String>(value: null, child: Text('Todos os estados')),
                    ..._states.map((s) => DropdownMenuItem<String>(value: s, child: Text(s)))],
                  onChanged: (v) { setState(() {
                    _selectedState = v; _selectedCity = null; _cidades = [];
                    if (v != null) { _loadingCidades = true;
                      _ibgeService.getCidadesPorEstado(v).then((cidades) {
                        if (mounted) setState(() { _cidades = cidades; _loadingCidades = false; }); }); }
                  }); },
                ),
                const SizedBox(height: 16),

                _label('CIDADE'), const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedCity, isExpanded: true,
                  decoration: _deco(_loadingCidades ? 'Carregando cidades...' : (_selectedState == null ? 'Selecione um estado primeiro' : 'Todas as cidades'), Icons.location_city_outlined),
                  selectedItemBuilder: (BuildContext context) => [const Text('Todas as cidades'),
                    if (_selectedState != null) ..._cidades.map((cidade) => Text(cidade.nome, overflow: TextOverflow.ellipsis, maxLines: 1))],
                  items: _selectedState == null
                      ? [const DropdownMenuItem<String>(value: null, child: Text('Selecione um estado primeiro'))]
                      : [const DropdownMenuItem<String>(value: null, child: Text('Todas as cidades')),
                         ..._cidades.map((cidade) => DropdownMenuItem<String>(value: cidade.nome, child: Text(cidade.nome)))],
                  onChanged: _selectedState == null || _loadingCidades ? null : (v) => setState(() => _selectedCity = v),
                ),
                const SizedBox(height: 16),

                _label('PROFISSAO'), const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: safeProfession, isExpanded: true,
                  decoration: _deco('Todas as profissoes', Icons.work_outline_rounded),
                  selectedItemBuilder: (BuildContext context) => [const Text('Todas as profissoes'),
                    ..._professions.map((p) => Text(p, overflow: TextOverflow.ellipsis, maxLines: 1))],
                  items: [const DropdownMenuItem<String>(value: null, child: Text('Todas as profissoes')),
                    ..._professions.map((p) => DropdownMenuItem<String>(value: p, child: Text(p)))],
                  onChanged: (v) => setState(() => _selectedProfession = v),
                ),
                const SizedBox(height: 24),

                Row(children: [
                  Expanded(child: OutlinedButton(
                    onPressed: () async {
                      setState(() { _selectedState = null; _selectedCity = null; _selectedProfession = null; });
                      await c.clearFilters();
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: OutlinedButton.styleFrom(foregroundColor: _textSecondary,
                      side: BorderSide(color: Colors.grey.shade300), minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Limpar'))),
                  const SizedBox(width: 12),
                  Expanded(flex: 2, child: ElevatedButton(
                    onPressed: () async {
                      await c.applyFilters(state: _selectedState, city: _selectedCity, profession: _selectedProfession);
                      if (context.mounted) Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: _primary, foregroundColor: Colors.white,
                      elevation: 0, minimumSize: const Size(0, 46),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                    child: const Text('Aplicar'))),
                ]),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary, letterSpacing: 0.4));

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(fontSize: 13, color: _textSecondary),
    prefixIcon: Icon(icon, size: 18, color: _textSecondary),
    filled: true, fillColor: _bg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _primary, width: 1.5)),
  );
}

// ── CARD WRAPPER ──────────────────────────────────────────────────────────────
class _FeedCardWrapper extends StatelessWidget {
  final bool isOwn;
  final VoidCallback onTap;
  final Widget child;
  const _FeedCardWrapper({required this.isOwn, required this.onTap, required this.child});

  static const Color _ownGreen       = Color(0xFF1DB954);
  static const Color _ownGreenLight  = Color(0xFFE8F8F0);
  static const Color _ownGreenBorder = Color(0xFF87DDB4);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        color: isOwn ? _ownGreenLight : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isOwn ? _ownGreenBorder : Colors.grey.shade100, width: isOwn ? 2 : 1),
        boxShadow: [BoxShadow(
          color: isOwn ? _ownGreen.withOpacity(0.10) : Colors.black.withOpacity(0.03),
          offset: const Offset(0, 2), blurRadius: 10)],
      ),
      child: Material(
        color: Colors.transparent, borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap, borderRadius: BorderRadius.circular(20),
          child: Padding(padding: const EdgeInsets.all(16), child: child)),
      ),
    );
  }
}

// ── SHIMMER ───────────────────────────────────────────────────────────────────
class _ShimmerCard extends StatefulWidget {
  const _ShimmerCard();
  @override
  State<_ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<_ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100, width: 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _block(44, 44, r: 12), const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _blockFlex(130, 14), const SizedBox(height: 6),
              _blockFlex(80,  11), const SizedBox(height: 5),
              _blockFlex(70,  10),
            ])),
            const SizedBox(width: 6), _block(36, 22, r: 8),
          ]),
          const SizedBox(height: 14),
          _blockFlex(double.infinity, 200, r: 14),  // altura reflete novo strip
          const SizedBox(height: 12),
          Row(children: [
            Flexible(child: _blockFlex(90,  26, r: 20)), const SizedBox(width: 6),
            Flexible(child: _blockFlex(110, 26, r: 20)), const SizedBox(width: 6),
            Flexible(child: _blockFlex(70,  26, r: 20)),
          ]),
          const SizedBox(height: 12),
          _blockFlex(double.infinity, 13), const SizedBox(height: 5),
          _blockFlex(200, 13), const SizedBox(height: 14),
          _blockFlex(double.infinity, 42, r: 12),
        ]),
      ),
    );
  }

  Widget _block(double w, double h, {double r = 6}) => Opacity(opacity: _anim.value,
    child: Container(width: w, height: h,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(r))));

  Widget _blockFlex(double maxW, double h, {double r = 6}) => Opacity(opacity: _anim.value,
    child: Container(
      width: maxW == double.infinity ? double.infinity : null,
      constraints: maxW != double.infinity ? BoxConstraints(maxWidth: maxW) : null,
      height: h,
      decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(r))));
}

enum LocationFilter { all, sameCity, sameState }