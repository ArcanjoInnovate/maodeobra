// lib/screens/search/my_vacancy_details_screen.dart

import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:dartobra_new/services/vacancy/vacancy_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

class MyVacancyDetailPage extends StatefulWidget {
  final VacancyModel vacancy;
  final String localId;
  final VoidCallback onEditVacancy;
  final VoidCallback? onVacancyDeleted;

  const MyVacancyDetailPage({
    Key? key,
    required this.vacancy,
    required this.localId,
    required this.onEditVacancy,
    this.onVacancyDeleted,
  }) : super(key: key);

  @override
  State<MyVacancyDetailPage> createState() => _MyVacancyDetailPageState();
}

class _MyVacancyDetailPageState extends State<MyVacancyDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _heroScale;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;

  final VacancyService _vacancyService = VacancyService();

  late String _currentStatus;
  bool _isTogglingStatus = false;
  bool _isDeletingVacancy = false;

  int _currentImageIndex = 0;
  late PageController _imagePageController;

  static const Color _emerald = Color(0xFF059669);
  static const Color _emeraldSurface = Color(0xFFD1FAE5);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  static const Color _amber = Color(0xFFF59E0B);
  static const Color _amberSurface = Color(0xFFFEF3C7);
  static const Color _red = Color(0xFFDC2626);
  static const Color _redSurface = Color(0xFFFEE2E2);
  static const Color _blue = Color(0xFF2563EB);

  bool get _isOpen => _currentStatus.toLowerCase() == 'aberta';

  List<String> get _validImages =>
      widget.vacancy.images.where((img) => img.isNotEmpty).toList();

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.vacancy.status;
    _imagePageController = PageController();

    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _heroScale = Tween<double>(begin: 1.08, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.0, 0.6)));
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));

    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _contentCtrl.forward();
    });
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    _imagePageController.dispose();
    super.dispose();
  }

  // ── TOGGLE STATUS ───────────────────────────────────────────

  Future<void> _toggleStatus() async {
    if (_isOpen) {
      final confirmed = await _showConfirmDialog(
        icon: Icons.pause_circle_outline_rounded,
        iconColor: _amber,
        bgColor: _amberSurface,
        title: 'Pausar vaga?',
        body:
            'A vaga ficará invisível nas buscas. Candidaturas existentes são preservadas.',
        confirmLabel: 'Pausar',
        confirmColor: _amber,
      );
      if (!confirmed) return;
    }

    setState(() => _isTogglingStatus = true);

    final newStatus = await _vacancyService.toggleVacancyStatus(
        widget.vacancy.id, _currentStatus);

    if (mounted) {
      setState(() {
        _isTogglingStatus = false;
        if (newStatus != null) _currentStatus = newStatus;
      });

      final opened = newStatus?.toLowerCase() == 'aberta';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(newStatus != null
            ? (opened
                ? 'Vaga reaberta! Aparece nas buscas novamente.'
                : 'Vaga pausada. Invisível nas buscas.')
            : 'Erro ao alterar status. Tente novamente.'),
        backgroundColor:
            newStatus != null ? (opened ? _emerald : _amber) : _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
    }
  }

  // ── EXCLUIR VAGA ─────────────────────────────────────────────

  Future<void> _deleteVacancy() async {
    final confirmed = await _showConfirmDialog(
      icon: Icons.delete_outline_rounded,
      iconColor: _red,
      bgColor: _redSurface,
      title: 'Excluir vaga?',
      body:
          'Esta ação é permanente. A vaga será removida e as notificações de candidatura serão atualizadas.',
      confirmLabel: 'Excluir',
      confirmColor: _red,
    );
    if (!confirmed) return;

    setState(() => _isDeletingVacancy = true);

    final success =
        await _vacancyService.deleteVacancy(widget.vacancy.id, widget.localId);

    if (mounted) {
      setState(() => _isDeletingVacancy = false);

      if (success) {
        widget.onVacancyDeleted?.call();
        Navigator.pop(context, 'deleted');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Vaga excluída com sucesso.'),
          backgroundColor: _emerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Erro ao excluir. Tente novamente.'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Text(title,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w700)),
              ],
            ),
            content: Text(body,
                style: const TextStyle(fontSize: 14, height: 1.55)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancelar',
                    style: TextStyle(
                        color: _muted, fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: confirmColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(confirmLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── BUILD ────────────────────────────────────────────────────

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
            if (_isDeletingVacancy)
              Container(
                color: Colors.black.withOpacity(0.45),
                child: const Center(
                  child: Card(
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.all(Radius.circular(16))),
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: Color(0xFFDC2626), strokeWidth: 2.5),
                          SizedBox(height: 16),
                          Text('Excluindo vaga...',
                              style:
                                  TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildFloatingAppBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 16,
          bottom: 8,
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
      expandedHeight: 280,
      pinned: false,
      stretch: true,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: ScaleTransition(
          scale: _heroScale,
          child: FadeTransition(
            opacity: _heroOpacity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isOpen
                      ? const [
                          Color(0xFF065F46),
                          Color(0xFF059669),
                          Color(0xFF34D399)
                        ]
                      : const [
                          Color(0xFF78350F),
                          Color(0xFFB45309),
                          Color(0xFFFCD34D)
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -60, right: -40,
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30, left: -50,
                    child: Container(
                      width: 180, height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 50),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 90, height: 90,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                    color:
                                        Colors.white.withOpacity(0.3),
                                    width: 1.5),
                              ),
                              child: const Icon(
                                  Icons.work_outline_rounded,
                                  color: Colors.white,
                                  size: 44),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withOpacity(0.15),
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
                                    decoration: BoxDecoration(
                                      color: _isOpen
                                          ? const Color(0xFF6EE7B7)
                                          : const Color(0xFFFCD34D),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isOpen
                                        ? 'Minha Vaga · Aberta'
                                        : 'Minha Vaga · Pausada',
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
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 32),
                          child: Text(
                            widget.vacancy.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              height: 1.3,
                              letterSpacing: -0.5,
                            ),
                          ),
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
                            _surface.withOpacity(0.9)
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
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 120),
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
              child: Text(
                widget.vacancy.profession,
                style: TextStyle(
                    fontSize: 13,
                    color: _emerald,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4),
              ),
            ),
          ),

          // Galeria de imagens
          if (_validImages.isNotEmpty) ...[
            _buildImageGallery(),
            const SizedBox(height: 28),
          ],

          _sectionLabel('DETALHES'),
          const SizedBox(height: 12),
          _buildDetailsGrid(),
          const SizedBox(height: 28),

          // ── CONTATO (padronizado igual professional_profile_page) ──
          if (_hasContactInfo()) ...[
            _sectionLabel('CONTATO'),
            const SizedBox(height: 12),
            _buildContactSection(),
            const SizedBox(height: 28),
          ],

          _sectionLabel('DESCRIÇÃO DA VAGA'),
          const SizedBox(height: 12),
          _buildDescriptionCard(),
          const SizedBox(height: 28),

          _buildInfoBox(),
          const SizedBox(height: 16),

          // Botão excluir
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _isDeletingVacancy ? null : _deleteVacancy,
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('Excluir Vaga',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _red,
                side: const BorderSide(color: _red, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── GALERIA (carrossel PageView com dots) ────────────────────

  Widget _buildImageGallery() {
    final images = _validImages;
    final count = images.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('GALERIA'),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 220,
            child: count == 1
                ? _galleryImage(images[0], fit: BoxFit.cover)
                : Stack(
                    children: [
                      PageView.builder(
                        controller: _imagePageController,
                        itemCount: count,
                        onPageChanged: (i) =>
                            setState(() => _currentImageIndex = i),
                        itemBuilder: (_, i) =>
                            _galleryImage(images[i], fit: BoxFit.cover),
                      ),
                      Positioned.fill(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (_currentImageIndex > 0)
                              _navArrow(
                                icon: Icons.chevron_left_rounded,
                                onTap: () =>
                                    _imagePageController.previousPage(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                              )
                            else
                              const SizedBox(width: 48),
                            if (_currentImageIndex < count - 1)
                              _navArrow(
                                icon: Icons.chevron_right_rounded,
                                onTap: () =>
                                    _imagePageController.nextPage(
                                  duration:
                                      const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                ),
                              )
                            else
                              const SizedBox(width: 48),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        if (count > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == _currentImageIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: active ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active ? _emerald : _border,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  Widget _galleryImage(String url, {required BoxFit fit}) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      width: double.infinity,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade100,
        child: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF059669),
            strokeWidth: 2,
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade100,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported_outlined,
                size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text('Imagem indisponível',
                style: TextStyle(
                    fontSize: 12, color: Colors.grey.shade400)),
          ],
        ),
      ),
    );
  }

  Widget _navArrow(
      {required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(8),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _muted,
            letterSpacing: 1.2),
      );

  Widget _buildDetailsGrid() {
    final items = <Map<String, dynamic>>[
      if (_hasValidCompany())
        {
          'icon': Icons.business_rounded,
          'label': 'Empresa',
          'value': widget.vacancy.company,
          'color': _emerald
        },
      {
        'icon': Icons.location_on_rounded,
        'label': 'Localização',
        'value': '${widget.vacancy.city}, ${widget.vacancy.state}',
        'color': const Color(0xFFEF4444)
      },
      if (widget.vacancy.salary.isNotEmpty)
        {
          'icon': Icons.payments_rounded,
          'label': 'Salário',
          'value':
              '${widget.vacancy.salary} · ${widget.vacancy.salaryType}',
          'color': const Color(0xFF8B5CF6)
        },
      {
        'icon': Icons.radio_button_checked_rounded,
        'label': 'Status',
        'value': _currentStatus,
        'color': _isOpen ? _emerald : _amber
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
                    style: TextStyle(
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

  // ── CONTATO (padronizado igual professional_profile_page) ──

  bool _hasContactInfo() =>
      widget.vacancy.emailContact.isNotEmpty ||
      widget.vacancy.phoneContact.isNotEmpty;

  Widget _buildContactSection() {
    return Column(
      children: [
        if (widget.vacancy.emailContact.isNotEmpty)
          _contactRow(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            value: widget.vacancy.emailContact,
            color: _blue,
            onTap: () => _copyToClipboard(
                widget.vacancy.emailContact, 'Email copiado!'),
          ),
        if (widget.vacancy.emailContact.isNotEmpty &&
            widget.vacancy.phoneContact.isNotEmpty)
          const SizedBox(height: 10),
        if (widget.vacancy.phoneContact.isNotEmpty)
          _contactRow(
            icon: Icons.phone_outlined,
            label: 'Telefone',
            value: widget.vacancy.phoneContact,
            color: const Color(0xFF059669),
            onTap: () => _copyToClipboard(
                widget.vacancy.phoneContact, 'Telefone copiado!'),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _buildDescriptionCard() {
    final hasDesc = widget.vacancy.description.isNotEmpty;
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
        hasDesc
            ? widget.vacancy.description
            : 'Sem descrição disponível.',
        style: TextStyle(
          fontSize: 14,
          color: hasDesc ? _ink : _muted,
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
        gradient: LinearGradient(colors: [
          const Color(0xFF1D4ED8).withOpacity(0.06),
          const Color(0xFF3B82F6).withOpacity(0.04),
        ]),
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
              'Esta é a vaga que trabalhadores visualizam quando buscam por oportunidades.',
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
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: widget.onEditVacancy,
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Editar Vaga',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
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

  bool _hasValidCompany() =>
      widget.vacancy.company.isNotEmpty &&
      widget.vacancy.company.toLowerCase() != 'não informado' &&
      widget.vacancy.company.toLowerCase() != 'n/a' &&
      widget.vacancy.company != '-';
}