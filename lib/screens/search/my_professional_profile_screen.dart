// lib/screens/app_home/search_vacancy/my_professional_profile.dart
// ✅ Ativar/Pausar perfil profissional integrado

import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/services/vacancy/professional_status_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';

class MyProfessionalProfilePage extends StatefulWidget {
  final ProfessionalModel professional;
  final VoidCallback onEditProfile;

  const MyProfessionalProfilePage({
    Key? key,
    required this.professional,
    required this.onEditProfile,
  }) : super(key: key);

  @override
  State<MyProfessionalProfilePage> createState() =>
      _MyProfessionalProfilePageState();
}

class _MyProfessionalProfilePageState
    extends State<MyProfessionalProfilePage> with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _avatarCtrl;
  late Animation<double> _heroOpacity;
  late Animation<double> _heroScale;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;
  late Animation<double> _avatarScale;

  late bool _isActive;
  bool _isTogglingStatus = false;

  // Paleta
  static const Color _emerald = Color(0xFF059669);
  static const Color _emeraldLight = Color(0xFF10B981);
  static const Color _emeraldSurface = Color(0xFFD1FAE5);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberSurface = Color(0xFFFEF3C7);
  static const Color _blue = Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();

    _isActive =
        widget.professional.status.toLowerCase() == 'active';

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _avatarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _heroScale = Tween<double>(begin: 1.08, end: 1.0).animate(
        CurvedAnimation(
            parent: _heroCtrl, curve: Curves.easeOutCubic));
    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _heroCtrl,
            curve: const Interval(0.0, 0.6)));
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _contentCtrl, curve: Curves.easeOutCubic));
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _contentCtrl, curve: Curves.easeOut));
    _avatarScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(
            parent: _avatarCtrl, curve: Curves.elasticOut));

    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 180),
        () { if (mounted) _avatarCtrl.forward(); });
    Future.delayed(const Duration(milliseconds: 250),
        () { if (mounted) _contentCtrl.forward(); });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  // ── TOGGLE STATUS ─────────────────────────────────────────────

  Future<void> _toggleStatus() async {
    if (_isActive) {
      final confirmed = await _showConfirmPauseDialog();
      if (!confirmed) return;
    }

    setState(() => _isTogglingStatus = true);

    final success =
        await ProfessionalStatusService.toggleProfessionalStatus(
      localId: widget.professional.localId,
      professionalId: widget.professional.id,
      currentlyActive: _isActive,
    );

    if (mounted) {
      setState(() {
        _isTogglingStatus = false;
        if (success) _isActive = !_isActive;
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? (_isActive
                      ? Icons.visibility_rounded
                      : Icons.pause_circle_rounded)
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Text(
              success
                  ? (_isActive
                      ? 'Perfil ativado! Você aparece nas buscas.'
                      : 'Perfil pausado. Você não aparece nas buscas.')
                  : 'Erro ao alterar status. Tente novamente.',
            ),
          ],
        ),
        backgroundColor: success
            ? (_isActive ? _emerald : _amber)
            : Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  Future<bool> _showConfirmPauseDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: _amberSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                      Icons.pause_circle_outline_rounded,
                      color: _amber,
                      size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Pausar perfil?',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            content: const Text(
              'Ao pausar, seu perfil ficará invisível para contratantes nas buscas. Você pode reativar a qualquer momento.',
              style: TextStyle(fontSize: 14, height: 1.55),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar',
                    style: TextStyle(
                        color: _muted,
                        fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Pausar',
                    style:
                        TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── BUILD ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _surface,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildHero(context),
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentOpacity,
                      child: _buildContent(context),
                    ),
                  ),
                ),
              ],
            ),
            _buildFloatingAppBar(context),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildFloatingAppBar(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8, right: 16, bottom: 8,
        ),
        color: Colors.transparent,
        child: Row(
          children: [
            Material(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    return SliverAppBar(
      automaticallyImplyLeading: false,
      expandedHeight: 300,
      pinned: false,
      stretch: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: ScaleTransition(
          scale: _heroScale,
          child: FadeTransition(
            opacity: _heroOpacity,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF065F46),
                    Color(0xFF059669),
                    Color(0xFF6EE7B7),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -70, right: -50,
                    child: Container(
                      width: 220, height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20, left: -60,
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        ScaleTransition(
                          scale: _avatarScale,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              ClipOval(
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(
                                      sigmaX: 6, sigmaY: 6),
                                  child: Container(
                                    width: 112, height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white
                                          .withOpacity(0.2),
                                      border: Border.all(
                                          color: Colors.white
                                              .withOpacity(0.4),
                                          width: 2.5),
                                    ),
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 48,
                                backgroundColor:
                                    Colors.white.withOpacity(0.15),
                                backgroundImage: widget
                                        .professional.avatar.isNotEmpty
                                    ? NetworkImage(
                                        widget.professional.avatar)
                                    : null,
                                child: widget
                                        .professional.avatar.isEmpty
                                    ? const Icon(Icons.person_rounded,
                                        color: Colors.white, size: 48)
                                    : null,
                              ),
                              Positioned(
                                bottom: 4, right: 4,
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  width: 22, height: 22,
                                  decoration: BoxDecoration(
                                    color: _isActive
                                        ? const Color(0xFF34D399)
                                        : _amber,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2.5),
                                  ),
                                  child: Icon(
                                    _isActive
                                        ? Icons.check_rounded
                                        : Icons.pause_rounded,
                                    color: Colors.white,
                                    size: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.professional.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.4,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: Colors.white
                                        .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(30),
                                    border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.25),
                                        width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 7, height: 7,
                                        decoration: const BoxDecoration(
                                            color: Color(0xFF6EE7B7),
                                            shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        widget.professional.profession,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: _isActive
                                    ? Colors.white.withOpacity(0.20)
                                    : _amber.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                    color: _isActive
                                        ? Colors.white.withOpacity(0.3)
                                        : _amber.withOpacity(0.5),
                                    width: 1),
                              ),
                              child: Text(
                                _isActive ? 'Ativo' : 'Pausado',
                                style: TextStyle(
                                  color: _isActive
                                      ? Colors.white
                                      : _amberSurface,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            _surface.withOpacity(0.9),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),

          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 9),
              decoration: BoxDecoration(
                color: _emeraldSurface,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified_rounded,
                      color: _emerald, size: 15),
                  const SizedBox(width: 7),
                  Text(
                    'Meu Perfil Profissional',
                    style: TextStyle(
                      fontSize: 13,
                      color: _emerald,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          _sectionLabel('INFORMAÇÕES'),
          const SizedBox(height: 12),
          _buildInfoGrid(),
          const SizedBox(height: 28),

          // ── CONTATO (padronizado igual professional_profile_page) ──
          if (_hasContactInfo()) ...[
            _sectionLabel('CONTATO'),
            const SizedBox(height: 12),
            _buildContactSection(),
            const SizedBox(height: 28),
          ],

          if (widget.professional.skills.isNotEmpty) ...[
            _sectionLabel('HABILIDADES'),
            const SizedBox(height: 12),
            _buildSkillsSection(),
            const SizedBox(height: 28),
          ],

          _sectionLabel('SOBRE'),
          const SizedBox(height: 12),
          _buildAboutCard(),
          const SizedBox(height: 28),

          _buildInfoBox(),
        ],
      ),
    );
  }

  // ── CONTATO (padronizado igual professional_profile_page) ──

  bool _hasContactInfo() =>
      widget.professional.email.isNotEmpty ||
      widget.professional.telefone.isNotEmpty;

  Widget _buildContactSection() {
    return Column(
      children: [
        if (widget.professional.email.isNotEmpty)
          _contactRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: widget.professional.email,
            color: _blue,
            onTap: () => _copyToClipboard(
                widget.professional.email, 'Email copiado!'),
          ),
        if (widget.professional.email.isNotEmpty &&
            widget.professional.telefone.isNotEmpty)
          const SizedBox(height: 10),
        if (widget.professional.telefone.isNotEmpty)
          _contactRow(
            icon: Icons.phone_outlined,
            label: 'Telefone',
            value: widget.professional.telefone,
            color: const Color(0xFF059669),
            onTap: () => _copyToClipboard(
                widget.professional.telefone, 'Telefone copiado!'),
          ),
      ],
    );
  }

  Widget _contactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.09),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.copy_rounded, size: 16, color: _muted),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 2),
      backgroundColor: const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: _muted,
          letterSpacing: 1.2,
        ),
      );

  Widget _buildInfoGrid() {
    final items = <Map<String, dynamic>>[
      {
        'icon': Icons.location_on_rounded,
        'label': 'Localização',
        'value':
            '${widget.professional.city}, ${widget.professional.state}',
        'color': const Color(0xFFEF4444),
      },
      {
        'icon': Icons.badge_rounded,
        'label': 'Tipo de contrato',
        'value': widget.professional.legalType,
        'color': const Color(0xFF8B5CF6),
      },
      if (widget.professional.company.isNotEmpty)
        {
          'icon': Icons.business_rounded,
          'label': 'Empresa',
          'value': widget.professional.company,
          'color': _emerald,
        },
    ];

    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Padding(
            padding:
                EdgeInsets.only(bottom: i < items.length - 1 ? 10 : 0),
            child: _detailTile(items[i]),
          ),
      ],
    );
  }

  Widget _detailTile(Map<String, dynamic> item) {
    final Color c = item['color'] as Color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(item['icon'] as IconData, color: c, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['label'] as String,
                    style: const TextStyle(
                        fontSize: 10,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 4),
                Text(item['value'] as String,
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF111827),
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSection() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.professional.skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: _emeraldLight.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: _emerald.withOpacity(0.06),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                    color: _emeraldLight, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(skill,
                  style: const TextStyle(
                      fontSize: 13,
                      color: _emerald,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAboutCard() {
    final hasSummary = widget.professional.summary.isNotEmpty;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Text(
        hasSummary
            ? widget.professional.summary
            : 'Sem resumo disponível.',
        style: TextStyle(
          fontSize: 14,
          color: hasSummary ? _ink : _muted,
          height: 1.7,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1D4ED8).withOpacity(0.06),
            const Color(0xFF3B82F6).withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF3B82F6).withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.info_outline_rounded,
                color: Color(0xFF3B82F6), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Este é o perfil que empresas visualizam quando te encontram na busca.',
              style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF1E40AF),
                  height: 1.5,
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: widget.onEditProfile,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text(
                    'Editar Meu Perfil',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF97316),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}