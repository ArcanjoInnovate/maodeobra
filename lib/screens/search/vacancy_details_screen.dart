// lib/pages/vacancy_detail_page.dart
// ✅ Design premium — glassmorphism, gradientes, animações — lógica original preservada

// ignore_for_file: unused_field

import 'dart:async';
import 'dart:ui';

import 'package:dartobra_new/models/search/vacancy_model.dart';
import 'package:dartobra_new/screens/complaints/complaint_vacancy_screen.dart';
import 'package:dartobra_new/services/vacancy/profile_validation_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Importação necessária para o BadgeHelper
// import 'package:dartobra_new/utils/badge_helper.dart'; 

class VacancyDetailPage extends StatefulWidget {
  final VacancyModel vacancy;
  final String vacancyId;
  final String reportedId;

  const VacancyDetailPage({
    Key? key,
    required this.vacancy,
    required this.reportedId,
    required this.vacancyId,
  }) : super(key: key);

  @override
  State<VacancyDetailPage> createState() => _VacancyDetailPageState();
}

class _VacancyDetailPageState extends State<VacancyDetailPage>
    with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _contentCtrl;
  late Animation<double> _heroScale;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;

  // Paleta azul — telas de terceiros
  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueLight = Color(0xFF3B82F6);
  static const Color _blueSurface = Color(0xFFDBEAFE);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);
  
  bool _isRequesting = false;           // ✅ Loading
  bool _hasAlreadyRequested = false;    // ✅ Já solicitou?
  StreamSubscription<int>? _requestBadgeSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _checkIfAlreadyRequested(); // Verifica se já se candidatou ao iniciar
  }

  void _initializeAnimations() {
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));

    _heroScale = Tween<double>(begin: 1.08, end: 1.0)
        .animate(CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
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

  Future<void> _checkIfAlreadyRequested() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final vacancyId = widget.vacancyId;
    final db = FirebaseDatabase.instance.ref();
    final requestsRef = db.child('vacancy/$vacancyId/requests');
    final snapshot = await requestsRef.get();

    List<dynamic> requestsList = [];
    if (snapshot.exists && snapshot.value is List) {
      requestsList = List.from(snapshot.value as List);
    }

    if (mounted) {
      setState(() {
        _hasAlreadyRequested = requestsList.contains(currentUserId);
      });
    }
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    _requestBadgeSubscription?.cancel();
    super.dispose();
  }

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
                _buildHero(),
                SliverToBoxAdapter(
                  child: SlideTransition(
                    position: _contentSlide,
                    child: FadeTransition(
                      opacity: _contentOpacity,
                      child: _buildContent(),
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

  // ── AppBar flutuante com voltar + menu denúncia
  Widget _buildFloatingAppBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 8,
          right: 8,
          bottom: 8,
        ),
        color: Colors.transparent,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            Material(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded,
                    color: Colors.white, size: 20),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 3,
                onSelected: (value) {
                  if (value == 'report') _showReportDialog();
                },
                itemBuilder: (_) => [
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(Icons.flag_outlined,
                              color: Colors.red.shade600, size: 17),
                        ),
                        const SizedBox(width: 12),
                        const Text('Denunciar',
                            style: TextStyle(
                                fontSize: 14, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Hero
  Widget _buildHero() {
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
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1E3A8A),
                    Color(0xFF2563EB),
                    Color(0xFF60A5FA),
                  ],
                  stops: [0.0, 0.55, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -60,
                    right: -40,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.06),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -50,
                    child: Container(
                      width: 180,
                      height: 180,
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
                            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: Container(
                              width: 90,
                              height: 90,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(Icons.work_outline_rounded,
                                  color: Colors.white, size: 44),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(30),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                widget.vacancy.title,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // ── Conteúdo
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('DETALHES DA VAGA'),
          const SizedBox(height: 12),
          _buildInfoList(),
          const SizedBox(height: 24),
          if (_hasContactInfo()) ...[
            _sectionLabel('CONTATO'),
            const SizedBox(height: 12),
            _buildContactSection(),
            const SizedBox(height: 24),
          ],
          _sectionLabel('DESCRIÇÃO'),
          const SizedBox(height: 12),
          _buildDescriptionCard(),
          if (widget.vacancy.images.isNotEmpty) ...[
            const SizedBox(height: 24),
            _sectionLabel('GALERIA DE FOTOS'),
            const SizedBox(height: 12),
            _buildImageGallery(),
          ],
          const SizedBox(height: 100), // Espaço para o bottom bar
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: _muted,
        letterSpacing: 1.2,
      ),
    );
  }

  // ── Lista de informações (COLUNA)
  Widget _buildInfoList() {
    final items = [
      {
        'icon': Icons.business_rounded,
        'label': 'Empresa',
        'value': _hasValidCompany() ? widget.vacancy.company : 'Não informado',
        'color': _blue,
      },
      {
        'icon': Icons.location_on_rounded,
        'label': 'Localização',
        'value': '${widget.vacancy.city}, ${widget.vacancy.state}',
        'color': const Color(0xFFEF4444),
      },
      {
        'icon': Icons.payments_rounded,
        'label': 'Remuneração',
        'value': widget.vacancy.salary.isNotEmpty ? widget.vacancy.salary : 'Não informado',
        'color': const Color(0xFF10B981),
      },
      if (widget.vacancy.type.isNotEmpty)
        {
          'icon': Icons.category_rounded,
          'label': 'Categoria',
          'value': widget.vacancy.type,
          'color': const Color(0xFFF59E0B),
        },
    ];

    return Column(
      children: items
          .map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _infoCard(item),
              ))
          .toList(),
    );
  }

  Widget _infoCard(Map<String, dynamic> item) {
    final Color iconColor = item['color'] as Color;
    return Container(
      width: double.infinity,
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
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item['icon'] as IconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['label'] as String,
                    style: const TextStyle(
                        fontSize: 11,
                        color: _muted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3)),
                const SizedBox(height: 3),
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

  // ── CONTATO clicável com copy
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
            onTap: () =>
                _copyToClipboard(widget.vacancy.emailContact, 'Email copiado!'),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  // ── Descrição
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        hasDesc ? widget.vacancy.description : 'Sem descrição disponível.',
        style: TextStyle(
          fontSize: 14,
          color: hasDesc ? _ink : _muted,
          height: 1.7,
        ),
      ),
    );
  }

  // ── Galeria horizontal
  Widget _buildImageGallery() {
    return SizedBox(
      height: 190,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: widget.vacancy.images.length,
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openFullscreen(widget.vacancy.images, index),
            child: Container(
              width: 260,
              margin: EdgeInsets.only(
                  right: index < widget.vacancy.images.length - 1 ? 12 : 0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.10),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Hero(
                      tag: 'vacancy_image_$index',
                      child: Image.network(
                        widget.vacancy.images[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: Colors.grey.shade100,
                          child: Icon(Icons.image_not_supported_outlined,
                              size: 40, color: Colors.grey.shade400),
                        ),
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(color: Colors.grey.shade100);
                        },
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.2), width: 1),
                        ),
                        child: const Icon(Icons.open_in_full_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                    if (widget.vacancy.images.length > 1)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${index + 1}/${widget.vacancy.images.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Bottom bar com botão de candidatura
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
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: _hasAlreadyRequested
              ? _buildAlreadyRequestedBar()
              : ElevatedButton.icon(
                  onPressed: _isRequesting ? null : _requestChat,
                  icon: _isRequesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(
                    _isRequesting ? 'Enviando...' : 'Solicitar chat',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _blue.withOpacity(0.6),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
        ),
      ),
    );
  }

  // 🔥 NOVA: Barra "Já solicitado"
  Widget _buildAlreadyRequestedBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: const Color(0xFF0EA5E9).withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_rounded,
                color: Color(0xFF0EA5E9), size: 20),
          ),
          const Expanded(
            child: Text(
              'Candidatura enviada!',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0369A1),
              ),
            ),
          ),
          Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: const Color(0xFF0EA5E9)),
        ],
      ),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.flag_outlined,
                  color: Colors.red.shade600, size: 18),
            ),
            const SizedBox(width: 12),
            const Text('Denunciar Vaga',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Você tem certeza que deseja denunciar esta vaga?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar',
                style: TextStyle(color: _muted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _openReportScreen();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Denunciar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openReportScreen() {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) {
      _showError('Você precisa estar logado para denunciar');
      return;
    }
    final reportId = DateTime.now().millisecondsSinceEpoch.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintVacancy(
          vacancyId: widget.vacancyId,
          reportId: reportId,
          reportedId: widget.reportedId,
        ),
      ),
    );
  }

  bool _hasValidCompany() {
    return widget.vacancy.company.isNotEmpty &&
        widget.vacancy.company.toLowerCase() != 'não informado' &&
        widget.vacancy.company.toLowerCase() != 'n/a' &&
        widget.vacancy.company != '-';
  }

  void _openFullscreen(List<String> images, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            FullscreenImageViewer(images: images, initialIndex: index),
      ),
    );
  }
Future<void> _requestChat() async {
  if (_isRequesting || _hasAlreadyRequested) return;
  setState(() => _isRequesting = true);

  try {
    final validation = await ProfileValidationService.validateWorkerProfile();
    if (!validation.isValid) {
      setState(() => _isRequesting = false);
      validation.showErrorDialog(context);
      return;
    }

    final db = FirebaseDatabase.instance.ref();
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    
    // ✅ DADOS TRABALHADOR
    final userSnapshot = await db.child('Users/$currentUserId').get();
    String workerName = 'Trabalhador';
    String workerAvatar = '';
    if (userSnapshot.exists) {
      final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
      workerName = userData['Name'] ?? userData['name'] ?? 'Trabalhador';
      workerAvatar = userData['avatar'] ?? '';
    }

    // 🔥 LÊ REQUESTS (ROBUSTO)
    final requestsSnapshot = await db.child('vacancy/${widget.vacancyId}/requests').get();
    List<String> requestsList = [];
    
    if (requestsSnapshot.exists && requestsSnapshot.value != null) {
      final data = requestsSnapshot.value;
      if (data is List) {
        requestsList = data.cast<String>();
      } else if (data is Map) {
        requestsList = data.values.map((v) => v.toString()).toList();
      }
    }

    // Evita duplicatas
    if (requestsList.contains(currentUserId)) {
      setState(() {
        _isRequesting = false;
        _hasAlreadyRequested = true;
      });
      _showError('Você já se candidatou');
      return;
    }

    // ✅ ADICIONA
    requestsList.add(currentUserId);

    // ✅ OTIMIZAÇÃO: Batch update atômico (todas as escritas em uma única operação)
    final updates = <String, dynamic>{
      'vacancy/${widget.vacancyId}/requests': requestsList,
      'user_requests/$currentUserId/vacancies/${widget.vacancyId}': true,
      'vacancy/${widget.vacancyId}/views/request_views/$currentUserId': {
        'viewed_by_owner': false,
        'applied_at': DateTime.now().millisecondsSinceEpoch,
        'worker_name': workerName,
        'worker_avatar': workerAvatar,
      },
    };

    await db.update(updates);

    _showSuccess('Candidatura enviada!');
    
  } catch (e) {
    print('❌ $e');
    _showError('Erro: $e');
  } finally {
    setState(() => _isRequesting = false);
  }
}
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: const Color(0xFF059669),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ══════════════════════════════════════════════════════
// FULLSCREEN IMAGE VIEWER
// ══════════════════════════════════════════════════════
class FullscreenImageViewer extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullscreenImageViewer({
    Key? key,
    required this.images,
    required this.initialIndex,
  }) : super(key: key);

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.images.length}',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Hero(
                tag: 'vacancy_image_$index',
                child: Image.network(
                  widget.images[index],
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.broken_image_outlined,
                          size: 72, color: Colors.grey.shade600),
                      const SizedBox(height: 12),
                      Text('Erro ao carregar imagem',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 14)),
                    ],
                  ),
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        value: progress.expectedTotalBytes != null
                            ? progress.cumulativeBytesLoaded /
                                progress.expectedTotalBytes!
                            : null,
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
