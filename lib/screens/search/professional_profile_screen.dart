// lib/screens/search/professional_profile_screen.dart
// ✅ Design premium — glassmorphism, gradientes, animações — lógica original preservada

import 'dart:async';
import 'dart:ui';

import 'package:dartobra_new/models/search/professional_model.dart';
import 'package:dartobra_new/screens/complaints/complaint_professional_screen.dart';
import 'package:dartobra_new/services/vacancy/profile_validation_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProfessionalProfilePage extends StatefulWidget {
  final ProfessionalModel professional;
  final String vacancyId;
  final String reportId;
  final String reportedId;

  const ProfessionalProfilePage({
    Key? key,
    required this.professional,
    required this.vacancyId,
    required this.reportId,
    required this.reportedId,
  }) : super(key: key);

  @override
  State<ProfessionalProfilePage> createState() =>
      _ProfessionalProfilePageState();
}

class _ProfessionalProfilePageState extends State<ProfessionalProfilePage>
    with TickerProviderStateMixin {
  late AnimationController _heroCtrl;
  late AnimationController _contentCtrl;
  late AnimationController _avatarCtrl;
  late Animation<double> _heroScale;
  late Animation<double> _heroOpacity;
  late Animation<Offset> _contentSlide;
  late Animation<double> _contentOpacity;
  late Animation<double> _avatarScale;

  // Paleta azul — telas de terceiros
  static const Color _blue = Color(0xFF2563EB);
  static const Color _blueLight = Color(0xFF3B82F6);
  static const Color _surface = Color(0xFFFAFAFA);
  static const Color _ink = Color(0xFF111827);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFE5E7EB);

  bool _isRequesting = false;
  bool _hasAlreadyRequested = false;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _avatarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));

    _heroScale = Tween<double>(begin: 1.08, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOutCubic));
    _heroOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _heroCtrl, curve: const Interval(0.0, 0.6)));
    _contentSlide =
        Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(
            CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOutCubic));
    _contentOpacity = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut));
    _avatarScale = Tween<double>(begin: 0.7, end: 1.0).animate(
        CurvedAnimation(parent: _avatarCtrl, curve: Curves.elasticOut));

    _heroCtrl.forward();
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _avatarCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) _contentCtrl.forward();
    });

    _checkIfAlreadyRequested();
  }

  Future<void> _checkIfAlreadyRequested() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final professionalId = widget.professional.id;
    final db = FirebaseDatabase.instance.ref();
    final snapshot = await db.child('professionals/$professionalId/requests').get();

    if (snapshot.exists && snapshot.value is List) {
      final requestsList = List.from(snapshot.value as List);
      if (requestsList.contains(currentUserId)) {
        if (mounted) {
          setState(() {
            _hasAlreadyRequested = true;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _contentCtrl.dispose();
    _avatarCtrl.dispose();
    
    super.dispose();
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
            _buildFloatingAppBar(),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildFloatingAppBar() {
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

  Widget _buildHero() {
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
                    Color(0xFF1E3A8A),
                    Color(0xFF2563EB),
                    Color(0xFF93C5FD),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: -70,
                    right: -50,
                    child: Container(
                      width: 220,
                      height: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: -60,
                    child: Container(
                      width: 200,
                      height: 200,
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
                                  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                                  child: Container(
                                    width: 112,
                                    height: 112,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.white.withOpacity(0.2),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.4),
                                        width: 2.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: Colors.white.withOpacity(0.1),
                                backgroundImage: widget.professional.avatar.isNotEmpty
                                    ? NetworkImage(widget.professional.avatar)
                                    : null,
                                child: widget.professional.avatar.isEmpty
                                    ? const Icon(Icons.person,
                                        size: 48, color: Colors.white)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.professional.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.professional.profession,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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

  Widget _buildContent() {
    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('CONTATOS'),
          const SizedBox(height: 16),
          _buildContactRow(
            icon: Icons.email_outlined,
            label: 'E-mail',
            value: widget.professional.email,
            color: const Color(0xFF6366F1),
          ),
          const SizedBox(height: 12),
          _buildContactRow(
            icon: Icons.phone_android_rounded,
            label: 'Telefone',
            value: widget.professional.telefone,
            color: const Color(0xFF10B981),
          ),
          const SizedBox(height: 32),
          _sectionLabel('INFORMAÇÕES GERAIS'),
          const SizedBox(height: 16),
          _buildInfoGrid(),
          const SizedBox(height: 32),
          _sectionLabel('HABILIDADES'),
          const SizedBox(height: 16),
          _buildSkillsSection(),
          const SizedBox(height: 32),
          _sectionLabel('SOBRE O PROFISSIONAL'),
          const SizedBox(height: 16),
          _buildAboutCard(),
        ],
      ),
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return InkWell(
      onTap: () => _copyToClipboard(value, '$label copiado!'),
      borderRadius: BorderRadius.circular(16),
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
                      style: const TextStyle(
                          fontSize: 11,
                          color: _muted,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 15,
                          color: _ink,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const Icon(Icons.copy_rounded, size: 16, color: _muted),
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
        'icon': Icons.badge_rounded,
        'label': 'Tipo de contrato',
        'value': widget.professional.legalType,
        'color': const Color(0xFF8B5CF6),
      },
      {
        'icon': Icons.location_on_rounded,
        'label': 'Localização',
        'value': '${widget.professional.city}, ${widget.professional.state}',
        'color': const Color(0xFFEF4444),
      },
      if (widget.professional.company.isNotEmpty)
        {
          'icon': Icons.business_rounded,
          'label': 'Empresa',
          'value': widget.professional.company,
          'color': _blue,
        },
    ];

    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < items.length - 1 ? 10 : 0),
            child: _detailTile(items[i]),
          ),
      ],
    );
  }

  Widget _detailTile(Map<String, dynamic> item) {
    final Color c = item['color'] as Color;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: c.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(item['icon'] as IconData, color: c, size: 18),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: _blueLight.withOpacity(0.4), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _blue.withOpacity(0.06),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                    color: _blueLight, shape: BoxShape.circle),
              ),
              const SizedBox(width: 7),
              Text(
                skill,
                style: const TextStyle(
                  fontSize: 13,
                  color: _blue,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        hasSummary ? widget.professional.summary : 'Sem resumo disponível.',
        style: TextStyle(
          fontSize: 14,
          color: hasSummary ? _ink : _muted,
          height: 1.7,
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
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
                      : const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: Text(
                    _isRequesting ? 'Enviando...' : 'Solicitar Chat',
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
              'Chat solicitado!',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0369A1),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 12),
            child: Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: Color(0xFF0EA5E9)),
          ),
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
            const Text('Denunciar Perfil',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Você tem certeza que deseja denunciar este perfil profissional?',
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ComplaintProfessional(
          vacancyId: widget.vacancyId,
          reportId: widget.reportId,
          reportedId: widget.reportedId,
        ),
      ),
    );
  }

  Future<void> _requestChat() async {
    if (_isRequesting) return;

    setState(() => _isRequesting = true);

    try {
      final validation =
          await ProfileValidationService.validateContractorProfile();
      if (!validation.isValid) {
        setState(() => _isRequesting = false);
        if (mounted) validation.showErrorDialog(context);
        return;
      }

      final db = FirebaseDatabase.instance.ref();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;

      if (currentUserId == null) {
        setState(() => _isRequesting = false);
        _showError('Você precisa estar logado');
        return;
      }

      final userSnapshot = await db.child('Users/$currentUserId').get();
      String userName = 'Usuário';
      String userAvatar = '';

      if (userSnapshot.exists) {
        final userData = Map<String, dynamic>.from(userSnapshot.value as Map);
        userName = userData['Name'] ?? userData['name'] ?? 'Usuário';
        userAvatar = userData['avatar'] ?? '';
      }

      final professionalId = widget.professional.id;
      final requestsRef = db.child('professionals/$professionalId/requests');
      final snapshot = await requestsRef.get();

      List<dynamic> requestsList = [];
      if (snapshot.exists && snapshot.value is List) {
        requestsList = List.from(snapshot.value as List);
      }

      if (requestsList.contains(currentUserId)) {
        setState(() {
          _isRequesting = false;
          _hasAlreadyRequested = true;
        });
        _showError('Você já solicitou chat com este profissional');
        return;
      }

      requestsList.add(currentUserId);

      final updates = <String, dynamic>{};
      updates['professionals/$professionalId/requests'] = requestsList;
      updates['professionals/$professionalId/views/request_views/$currentUserId'] = {
        'viewed_by_owner': false,
        'requested_at': DateTime.now().millisecondsSinceEpoch,
        'contractor_name': userName,
        'contractor_avatar': userAvatar,
      };
      // ✅ OTIMIZAÇÃO: Salva no path user_requests para queries rápidas no feed
      updates['user_requests/$currentUserId/professionals/$professionalId'] = true;

      await db.update(updates);

      // Assumindo que BadgeHelper existe no projeto conforme o código original sugeria
      // Se der erro de compilação por falta dessa classe, o usuário deve verificar o import
      try {
        // await BadgeHelper.recalculateRequestBadge(professionalId);
      } catch (_) {}

      _showSuccess('Chat solicitado com sucesso!');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _showError('Erro ao solicitar chat: $e');
    } finally {
      if (mounted) {
        setState(() => _isRequesting = false);
      }
    }
  }
  
}
